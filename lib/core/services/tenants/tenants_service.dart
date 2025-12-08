import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../hive/hive_service.dart';

final tenantsServiceProvider = FutureProvider<TenantsService>((ref) async {
  // Assumes HiveService.init() was already called in your initCoreServices
  // before runApp. If not, you can call HiveService.init() here as well.
  return TenantsService.create();
});

/// Tiny Hive-backed service for storing tenant preferences.
///
/// Responsibilities:
///  - Remember the last selected tenant (string)
///  - Optionally remember a list of known tenants
///
/// Box layout:
///  box: 'tenants_prefs'
///    - 'current_tenant' : String
///    - 'tenants'        : List<String>
class TenantsService {
  static const String _boxName = 'tenants_prefs';
  static const String _keyCurrentTenant = 'current_tenant';
  static const String _keyTenants = 'tenants';

  final Box _box;

  TenantsService._(this._box);

  /// Factory that makes sure the box is opened via HiveService.
  static Future<TenantsService> create() async {
    final box = await HiveService.openBox<dynamic>(_boxName);
    return TenantsService._(box);
  }

  /// Last selected tenant, if any.
  String? getCurrentTenant() {
    final value = _box.get(_keyCurrentTenant);
    return value is String ? value : null;
  }

  /// Persist the current tenant.
  Future<void> setCurrentTenant(String tenant) async {
    await _box.put(_keyCurrentTenant, tenant);
  }

  /// Optional: list of known tenants stored in this box.
  List<String> getTenants() {
    final value = _box.get(_keyTenants);
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Persist a list of known tenants (if you want to store them).
  Future<void> setTenants(List<String> tenants) async {
    await _box.put(_keyTenants, tenants);
  }
}