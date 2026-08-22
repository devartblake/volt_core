import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/sync/sync_context.dart';

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    this.legalName = '',
    this.contactName = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.billingAddress = '',
    this.notes = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String legalName;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String billingAddress;
  final String notes;
  final bool isActive;

  factory CustomerRecord.fromJson(Map<String, dynamic> row) => CustomerRecord(
        id: row['id'].toString(),
        name: (row['name'] ?? '').toString(),
        legalName: (row['legal_name'] ?? '').toString(),
        contactName: (row['primary_contact_name'] ?? '').toString(),
        contactEmail: (row['primary_contact_email'] ?? '').toString(),
        contactPhone: (row['primary_contact_phone'] ?? '').toString(),
        billingAddress: (row['billing_address'] ?? '').toString(),
        notes: (row['notes'] ?? '').toString(),
        isActive: row['is_active'] as bool? ?? true,
      );
}

class SiteRecord {
  const SiteRecord({
    required this.id,
    required this.siteCode,
    required this.address,
    this.customerId,
    this.siteGrade = '',
    this.notes = '',
    this.isActive = true,
  });

  final String id;
  final String siteCode;
  final String address;
  final String? customerId;
  final String siteGrade;
  final String notes;
  final bool isActive;

  factory SiteRecord.fromJson(Map<String, dynamic> row) => SiteRecord(
        id: row['id'].toString(),
        siteCode: (row['site_code'] ?? '').toString(),
        address: (row['address'] ?? '').toString(),
        customerId: row['customer_id']?.toString(),
        siteGrade: (row['site_grade'] ?? '').toString(),
        notes: (row['notes'] ?? '').toString(),
        isActive: row['is_active'] as bool? ?? true,
      );
}

class CustomerSiteDirectory {
  const CustomerSiteDirectory({this.customers = const [], this.sites = const []});

  final List<CustomerRecord> customers;
  final List<SiteRecord> sites;

  String customerNameFor(String? customerId) {
    for (final customer in customers) {
      if (customer.id == customerId) return customer.name;
    }
    return 'Unassigned customer';
  }
}

class CustomerSiteRepository {
  CustomerSiteRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String get _tenantId => SyncContext.tenantId ??
      (throw StateError('Select an active tenant before managing customers and sites.'));

  Future<CustomerSiteDirectory> load() async {
    final tenantId = _tenantId;
    final results = await Future.wait([
      _supabase.from('customers').select().eq('tenant_id', tenantId).order('name'),
      _supabase.from('sites').select().eq('tenant_id', tenantId).order('site_code'),
    ]);
    return CustomerSiteDirectory(
      customers: (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(CustomerRecord.fromJson)
          .toList(growable: false),
      sites: (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(SiteRecord.fromJson)
          .toList(growable: false),
    );
  }

  Future<void> saveCustomer(CustomerRecord customer) async {
    final row = {
      'tenant_id': _tenantId,
      'name': customer.name.trim(),
      'legal_name': customer.legalName.trim(),
      'primary_contact_name': customer.contactName.trim(),
      'primary_contact_email': customer.contactEmail.trim(),
      'primary_contact_phone': customer.contactPhone.trim(),
      'billing_address': customer.billingAddress.trim(),
      'notes': customer.notes.trim(),
      'is_active': customer.isActive,
    };
    if (customer.id.isEmpty) {
      await _supabase.from('customers').insert(row);
    } else {
      await _supabase.from('customers').update(row).eq('id', customer.id);
    }
  }

  Future<void> saveSite(SiteRecord site) async {
    final row = {
      'tenant_id': _tenantId,
      'site_code': site.siteCode.trim(),
      'address': site.address.trim(),
      'customer_id': site.customerId,
      'site_grade': site.siteGrade.trim(),
      'notes': site.notes.trim(),
      'is_active': site.isActive,
    };
    if (site.id.isEmpty) {
      await _supabase.from('sites').insert(row);
    } else {
      await _supabase.from('sites').update(row).eq('id', site.id);
    }
  }
}

final customerSiteRepositoryProvider = Provider<CustomerSiteRepository>((ref) {
  return CustomerSiteRepository();
});

final customerSiteDirectoryProvider = FutureProvider<CustomerSiteDirectory>((ref) {
  return ref.watch(customerSiteRepositoryProvider).load();
});
