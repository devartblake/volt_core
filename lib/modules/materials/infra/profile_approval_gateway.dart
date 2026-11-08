import 'package:supabase_flutter/supabase_flutter.dart';

/// There is no connection (or the server did not answer in time). The request
/// stays pending; approving needs the cloud so profile and request change in
/// one transaction.
class ProfileApprovalOfflineException implements Exception {
  const ProfileApprovalOfflineException();

  @override
  String toString() => 'Connect to approve';
}

/// The server says the request is no longer pending. [status] is its current
/// status ('approved', 'rejected', 'withdrawn').
class ProfileAlreadyDecidedException implements Exception {
  const ProfileAlreadyDecidedException(this.status);
  final String status;

  bool get isApproved => status == 'approved';

  @override
  String toString() => 'This request is already $status.';
}

/// The two server functions behind profile approvals (see
/// supabase/migrations/20261111110000_approve_profile_change.sql). An
/// interface so tests use a fake instead of Supabase.
abstract class ProfileApprovalGateway {
  /// Replaces the generator's profile rows with [items] (asset_parts column
  /// maps) and marks the request approved, in one transaction.
  ///
  /// Throws [ProfileApprovalOfflineException] with no connection and
  /// [ProfileAlreadyDecidedException] when the request is not pending.
  Future<void> approve({
    required String requestId,
    required List<Map<String, dynamic>> items,
    String reviewNote = '',
  });

  /// Marks the request rejected on the server (same errors as [approve]).
  Future<void> reject({required String requestId, String reviewNote = ''});
}

/// Calls the Supabase RPCs `approve_profile_change` / `reject_profile_change`.
class SupabaseProfileApprovalGateway implements ProfileApprovalGateway {
  const SupabaseProfileApprovalGateway({
    this.timeout = const Duration(seconds: 15),
  });

  final Duration timeout;

  @override
  Future<void> approve({
    required String requestId,
    required List<Map<String, dynamic>> items,
    String reviewNote = '',
  }) =>
      _call('approve_profile_change', {
        'p_request_id': requestId,
        'p_items': items,
        'p_review_note': reviewNote,
      });

  @override
  Future<void> reject({required String requestId, String reviewNote = ''}) =>
      _call('reject_profile_change', {
        'p_request_id': requestId,
        'p_review_note': reviewNote,
      });

  Future<void> _call(String fn, Map<String, dynamic> params) async {
    try {
      await Supabase.instance.client.rpc(fn, params: params).timeout(timeout);
    } on PostgrestException catch (e) {
      final hint = e.hint ?? '';
      if (hint.startsWith('status:')) {
        throw ProfileAlreadyDecidedException(hint.substring('status:'.length));
      }
      rethrow;
    } catch (_) {
      // Socket errors, timeouts, an unreachable host: treat all as offline.
      throw const ProfileApprovalOfflineException();
    }
  }
}
