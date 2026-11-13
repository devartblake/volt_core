import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/connectivity/connectivity_service.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';

const String kDigestOfflineMessage = 'Connect to the internet to change this.';
const String kDigestUnavailableMessage =
    'The daily summary setting is not available yet. Ask an admin to finish '
    'the latest database update.';
const String kDigestSaveFailedMessage =
    'Could not save this setting. Please try again.';

/// Roles that receive the daily summary email (see the daily-digest function).
bool receivesDailyDigest(UserRole? role) =>
    role == UserRole.admin ||
    role == UserRole.supervisor ||
    role == UserRole.dispatcher;

class DigestOfflineException implements Exception {
  const DigestOfflineException();
}

class DigestColumnMissingException implements Exception {
  const DigestColumnMissingException();
}

/// Reads and writes the signed-in user's own
/// `user_profiles.daily_digest_opt_out`. Online only.
abstract class DigestPreferenceRepository {
  /// True when the person opted out; null when it cannot be read.
  Future<bool?> readOptOut();

  /// Throws [DigestOfflineException] or [DigestColumnMissingException].
  Future<void> writeOptOut(bool optOut);
}

class SupabaseDigestPreferenceRepository implements DigestPreferenceRepository {
  const SupabaseDigestPreferenceRepository();

  static bool _isMissingColumn(PostgrestException e) =>
      e.code == '42703' || e.code == 'PGRST204' || e.code == 'PGRST200';

  @override
  Future<bool?> readOptOut() async {
    try {
      final client = Supabase.instance.client;
      final id = client.auth.currentUser?.id;
      if (id == null) return null;
      final row = await client
          .from('user_profiles')
          .select('daily_digest_opt_out')
          .eq('user_id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (row == null) return null;
      return row['daily_digest_opt_out'] == true;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeOptOut(bool optOut) async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw const DigestOfflineException();
    }
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in.');
    try {
      final rows = await client
          .from('user_profiles')
          .update({'daily_digest_opt_out': optOut})
          .eq('user_id', id)
          .select('user_id');
      if (rows.isEmpty) throw StateError('No profile row was updated.');
    } on PostgrestException catch (e) {
      if (_isMissingColumn(e)) throw const DigestColumnMissingException();
      rethrow;
    }
  }
}

final digestPreferenceRepositoryProvider = Provider<DigestPreferenceRepository>(
    (ref) => const SupabaseDigestPreferenceRepository());

/// True when the signed-in user has opted out; null when unknown.
final digestOptOutProvider = FutureProvider.autoDispose<bool?>(
    (ref) => ref.watch(digestPreferenceRepositoryProvider).readOptOut());

/// "Email me the daily summary" switch (on = receive). Shown only to roles that
/// get the digest. Online-only: offline the switch does not flip.
class DailyDigestTile extends ConsumerStatefulWidget {
  const DailyDigestTile({super.key});

  @override
  ConsumerState<DailyDigestTile> createState() => _DailyDigestTileState();
}

class _DailyDigestTileState extends ConsumerState<DailyDigestTile> {
  bool _busy = false;

  Future<void> _change(bool receive) async {
    setState(() => _busy = true);
    try {
      await ref.read(digestPreferenceRepositoryProvider).writeOptOut(!receive);
      ref.invalidate(digestOptOutProvider);
    } on DigestOfflineException {
      if (mounted) AppSnackBar.error(context, kDigestOfflineMessage);
    } on DigestColumnMissingException {
      if (mounted) AppSnackBar.error(context, kDigestUnavailableMessage);
    } catch (_) {
      if (mounted) AppSnackBar.error(context, kDigestSaveFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authStateProvider).currentRole;
    if (!receivesDailyDigest(role)) return const SizedBox.shrink();
    final optOut = ref.watch(digestOptOutProvider);
    // Unknown (loading, offline, column missing) shows the default: receiving.
    final receive = optOut.asData?.value != true;
    return SwitchListTile(
      key: const Key('daily_digest_switch'),
      title: const Text('Email me the daily summary'),
      subtitle:
          const Text('A morning email with open follow-ups and what is due'),
      value: receive,
      onChanged: (_busy || optOut.isLoading) ? null : _change,
    );
  }
}
