import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../app/app_drawer.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../../core/services/tenants/tenants_service.dart';

/// Current tenant for the session.
///
/// Depends on TenantsService to restore the tenant from Hive if available.
final currentTenantProvider =
StateNotifierProvider<TenantNotifier, String>((ref) {
  // Load TenantsService (async). While it's loading, we fallback
  // to a default tenant; once loaded, we can still use the service
  // for persistence of subsequent changes.
  final asyncService = ref.watch(tenantsServiceProvider);

  // Default demo tenants if nothing is stored yet.
  const defaultTenants = <String>[
    'Acme Corp',
    'TechHub Industries',
    'PowerGrid Solutions',
  ];

  TenantsService? service;
  String initialTenant = defaultTenants.first;

  asyncService.when(
    data: (s) {
      service = s;

      // Try to restore a persisted tenant, otherwise fallback.
      final storedTenant = s.getCurrentTenant();
      final storedTenants = s.getTenants();

      if (storedTenant != null && storedTenant.isNotEmpty) {
        initialTenant = storedTenant;
      } else if (storedTenants.isNotEmpty) {
        initialTenant = storedTenants.first;
      }
    },
    loading: () {
      // Keep defaults while loading; UI can still update later.
    },
    error: (_, __) {
      // On error, we fall back to defaults.
    },
  );

  return TenantNotifier(
    availableTenants: defaultTenants,
    initialTenant: initialTenant,
    tenantsService: service,
  );
});

/// Provider for the current user's profile information.
///
/// Pulls displayName/email from AuthState and
/// currentTenant from currentTenantProvider.
final userProfileProvider = Provider<AppUserProfile?>((ref) {
  final auth = ref.watch(authStateProvider);
  final currentTenant = ref.watch(currentTenantProvider);

  if (!auth.isAuthenticated) return null;

  // Same demo tenant list as above; later you can fetch from backend.
  const tenants = <String>[
    'Acme Corp',
    'TechHub Industries',
    'PowerGrid Solutions',
  ];

  return AppUserProfile(
    displayName: auth.displayName ?? 'User',
    email: auth.email ?? '',
    avatarUrl: null,
    currentTenant: currentTenant,
    tenants: tenants,
  );
});

/// Handles tenant switching and persistence.
class TenantNotifier extends StateNotifier<String> {
  TenantNotifier({
    required this.availableTenants,
    required String initialTenant,
    this.tenantsService,
  }) : super(initialTenant);

  final List<String> availableTenants;
  final TenantsService? tenantsService;

  void switchTenant(String newTenant) {
    if (!availableTenants.contains(newTenant)) {
      debugPrint(
        '[TenantNotifier] Attempted to switch to unknown tenant: $newTenant',
      );
      return;
    }

    if (state == newTenant) return;

    state = newTenant;

    // Persist to Hive (if TenantsService is ready)
    tenantsService?.setCurrentTenant(newTenant);

    // 🔜 TODO (when you’re ready):
    //  - Notify a backend of active tenant changes
    //  - Refresh tenant-scoped data (inspections, maintenance, schedule, etc.)
    //  - Persist tenants list from backend using tenantsService.setTenants(...)
    debugPrint('[TenantNotifier] Switched to tenant: $newTenant (persisted)');
  }
}
