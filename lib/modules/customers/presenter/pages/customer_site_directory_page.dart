import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../customer_site_repository.dart';

class CustomerSiteDirectoryPage extends ConsumerWidget {
  const CustomerSiteDirectoryPage({super.key});

  bool _canManage(UserRole? role) =>
      role == UserRole.admin || role == UserRole.supervisor || role == UserRole.dispatcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(customerSiteDirectoryProvider);
    final canManage = _canManage(ref.watch(authStateProvider).currentRole);
    return AppPage(
      title: 'Customers & Sites',
      actions: [
        IconButton(
          tooltip: 'Refresh directory',
          onPressed: () => ref.invalidate(customerSiteDirectoryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: directory.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => _DirectoryError(
          error: error,
          onRetry: () => ref.invalidate(customerSiteDirectoryProvider),
        ),
        data: (data) => _DirectoryBody(data: data, canManage: canManage),
      ),
    );
  }
}

class _DirectoryBody extends ConsumerWidget {
  const _DirectoryBody({required this.data, required this.canManage});

  final CustomerSiteDirectory data;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesByCustomer = <String?, List<SiteRecord>>{};
    for (final site in data.sites) {
      (sitesByCustomer[site.customerId] ??= []).add(site);
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(customerSiteDirectoryProvider.future).then<void>((_) {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Customer & site directory', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Select a service site when registering an asset. Customers and sites are scoped to the active tenant.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (canManage)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _showCustomerEditor(context, ref),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add customer'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSiteEditor(context, ref, data),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add site'),
                ),
              ],
            ),
          if (canManage) const SizedBox(height: 24),
          if (data.customers.isEmpty && data.sites.isEmpty)
            const _EmptyDirectory()
          else ...[
            Text('Customers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final customer in data.customers)
              _CustomerCard(
                customer: customer,
                sites: sitesByCustomer[customer.id] ?? const [],
                canManage: canManage,
                onEdit: () => _showCustomerEditor(context, ref, customer: customer),
                onEditSite: (site) => _showSiteEditor(context, ref, data, site: site),
              ),
            if ((sitesByCustomer[null] ?? const []).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Unassigned sites', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final site in sitesByCustomer[null]!)
                _SiteTile(
                  site: site,
                  customerName: 'No customer assigned',
                  canManage: canManage,
                  onEdit: () => _showSiteEditor(context, ref, data, site: site),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showCustomerEditor(BuildContext context, WidgetRef ref, {CustomerRecord? customer}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CustomerEditor(customer: customer),
    );
    if (saved == true) ref.invalidate(customerSiteDirectoryProvider);
  }

  Future<void> _showSiteEditor(
    BuildContext context,
    WidgetRef ref,
    CustomerSiteDirectory directory, {
    SiteRecord? site,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SiteEditor(directory: directory, site: site),
    );
    if (saved == true) ref.invalidate(customerSiteDirectoryProvider);
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.sites, required this.canManage, required this.onEdit, required this.onEditSite});
  final CustomerRecord customer;
  final List<SiteRecord> sites;
  final bool canManage;
  final VoidCallback onEdit;
  final ValueChanged<SiteRecord> onEditSite;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          leading: Icon(customer.isActive ? Icons.business_outlined : Icons.business_outlined, color: customer.isActive ? null : Theme.of(context).disabledColor),
          title: Text(customer.name),
          subtitle: Text([customer.contactName, customer.contactPhone].where((value) => value.isNotEmpty).join(' • ')),
          trailing: canManage ? IconButton(tooltip: 'Edit customer', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)) : null,
          children: [
            if (sites.isEmpty)
              const ListTile(title: Text('No service sites assigned yet.')),
            for (final site in sites)
              _SiteTile(site: site, customerName: customer.name, canManage: canManage, onEdit: () => onEditSite(site)),
          ],
        ),
      );
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.site, required this.customerName, required this.canManage, required this.onEdit});
  final SiteRecord site;
  final String customerName;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.fromLTRB(28, 4, 12, 4),
        leading: const Icon(Icons.location_on_outlined),
        title: Text(site.siteCode.isEmpty ? site.address : site.siteCode),
        subtitle: Text('${site.address}\n$customerName'),
        isThreeLine: true,
        trailing: canManage ? IconButton(tooltip: 'Edit site', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)) : null,
      );
}

class _CustomerEditor extends ConsumerStatefulWidget {
  const _CustomerEditor({this.customer});
  final CustomerRecord? customer;
  @override
  ConsumerState<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends ConsumerState<_CustomerEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name ?? '');
  late final _contact = TextEditingController(text: widget.customer?.contactName ?? '');
  late final _phone = TextEditingController(text: widget.customer?.contactPhone ?? '');
  late final _email = TextEditingController(text: widget.customer?.contactEmail ?? '');
  late final _notes = TextEditingController(text: widget.customer?.notes ?? '');
  bool _saving = false;
  @override void dispose() { _name.dispose(); _contact.dispose(); _phone.dispose(); _email.dispose(); _notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.customer == null ? 'Add customer' : 'Edit customer'),
        content: SizedBox(width: 480, child: Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Customer name'), validator: (value) => value == null || value.trim().isEmpty ? 'Customer name is required.' : null),
          TextFormField(controller: _contact, decoration: const InputDecoration(labelText: 'Primary contact')),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
        ])))),
        actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save'))],
      );
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(customerSiteRepositoryProvider).saveCustomer(CustomerRecord(id: widget.customer?.id ?? '', name: _name.text, contactName: _contact.text, contactPhone: _phone.text, contactEmail: _email.text, notes: _notes.text, isActive: widget.customer?.isActive ?? true));
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save customer: $error'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
}

class _SiteEditor extends ConsumerStatefulWidget {
  const _SiteEditor({required this.directory, this.site});
  final CustomerSiteDirectory directory;
  final SiteRecord? site;
  @override ConsumerState<_SiteEditor> createState() => _SiteEditorState();
}

class _SiteEditorState extends ConsumerState<_SiteEditor> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.site?.siteCode ?? '');
  late final _address = TextEditingController(text: widget.site?.address ?? '');
  String? _customerId;
  bool _saving = false;
  @override void initState() { super.initState(); _customerId = widget.site?.customerId; }
  @override void dispose() { _code.dispose(); _address.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.site == null ? 'Add site' : 'Edit site'),
    content: SizedBox(width: 480, child: Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String?>(initialValue: _customerId, decoration: const InputDecoration(labelText: 'Customer'), items: [const DropdownMenuItem<String?>(value: null, child: Text('No customer assigned')), ...widget.directory.customers.where((customer) => customer.isActive).map((customer) => DropdownMenuItem(value: customer.id, child: Text(customer.name)))], onChanged: _saving ? null : (value) => setState(() => _customerId = value)),
      TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Site code'), validator: (value) => value == null || value.trim().isEmpty ? 'Site code is required.' : null),
      TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Service address'), validator: (value) => value == null || value.trim().isEmpty ? 'Address is required.' : null),
    ])))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save'))],
  );
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(customerSiteRepositoryProvider).saveSite(SiteRecord(id: widget.site?.id ?? '', siteCode: _code.text, address: _address.text, customerId: _customerId, isActive: widget.site?.isActive ?? true));
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save site: $error'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
}

class _EmptyDirectory extends StatelessWidget { const _EmptyDirectory(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.only(top: 64), child: Center(child: Text('No customers or sites yet. Add a customer, then add its service site.'))); }
class _DirectoryError extends StatelessWidget { const _DirectoryError({required this.error, required this.onRetry}); final Object error; final VoidCallback onRetry; @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Could not load the customer directory: $error', textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])); }
