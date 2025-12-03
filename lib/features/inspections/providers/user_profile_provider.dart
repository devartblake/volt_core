import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/ui/app_drawer.dart';

/// Provider for the current user's profile information
/// This would typically be populated from your authentication service
final userProfileProvider = Provider<AppUserProfile?>((ref) {
  // TODO: Replace with actual user data from your auth service
  // For now, returning a sample profile for demonstration
  return const AppUserProfile(
    displayName: 'John Technician',
    email: 'john.tech@voltcore.com',
    avatarUrl: null, // or provide a URL like 'https://example.com/avatar.jpg'
    currentTenant: 'Acme Corp',
    tenants: [
      'Acme Corp',
      'TechHub Industries',
      'PowerGrid Solutions',
    ],
  );
});

/// Provider that handles tenant switching
/// In a real app, this would update the backend and refresh relevant data
class TenantNotifier extends StateNotifier<String> {
  TenantNotifier() : super('Acme Corp');

  void switchTenant(String newTenant) {
    state = newTenant;
    // TODO: Implement actual tenant switching logic:
    // - Update backend/API
    // - Refresh inspections and other tenant-specific data
    // - Update user preferences
    debugPrint('Switched to tenant: $newTenant');
  }
}

final currentTenantProvider = StateNotifierProvider<TenantNotifier, String>(
      (ref) => TenantNotifier(),
);