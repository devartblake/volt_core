import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/user_role.dart';

/// What the admin typed, already validated and normalised.
class InviteRequest {
  const InviteRequest({
    required this.email,
    required this.displayName,
    required this.role,
    this.phone,
    this.divisionIds = const [],
  });

  final String email;
  final String displayName;
  final UserRole role;
  final String? phone;

  /// Optional `public.divisions` ids (at most 10); the function checks each is
  /// this company's and active.
  final List<String> divisionIds;

  Map<String, dynamic> toBody() => {
        'email': email,
        'displayName': displayName,
        'role': role.wire,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (divisionIds.isNotEmpty) 'divisionIds': divisionIds,
        // Older deployed copies of the function only know the single form;
        // sending the first keeps one division working until it is redeployed.
        if (divisionIds.isNotEmpty) 'divisionId': divisionIds.first,
      };
}

class InviteResult {
  const InviteResult({
    required this.userId,
    required this.invited,
    required this.role,
  });

  final String userId;

  /// False when the person already had an account and was simply added.
  final bool invited;
  final UserRole role;
}

enum InviteFailureKind { validation, notAllowed, tooMany, offline, server }

/// A failure with a message that is safe to show as-is.
class InviteFailure implements Exception {
  const InviteFailure(this.kind, this.message);
  final InviteFailureKind kind;
  final String message;

  @override
  String toString() => 'InviteFailure($kind)';
}

const String kInviteOfflineMessage = 'Connect to the internet to invite someone.';

/// Maps an HTTP status (null = the request never got an answer) to a failure.
///
/// Only a 400 may pass the server's own sentence through, because those come
/// from the validator and are written for people. Everything else is fixed
/// text, so a raw exception can never reach the screen.
InviteFailure mapInviteFailure({int? status, String? serverMessage}) {
  switch (status) {
    case null:
      return const InviteFailure(
          InviteFailureKind.offline, kInviteOfflineMessage);
    case 400:
      final m = serverMessage?.trim() ?? '';
      return InviteFailure(
        InviteFailureKind.validation,
        m.isEmpty || m.length > 200
            ? 'Check the details and try again.'
            : m,
      );
    case 401:
    case 403:
      return const InviteFailure(InviteFailureKind.notAllowed,
          'You are not allowed to invite people. Ask an admin.');
    case 429:
      return const InviteFailure(InviteFailureKind.tooMany,
          'Too many invitations just now. Try again in a while.');
    default:
      return const InviteFailure(InviteFailureKind.server,
          'The invitation could not be sent. Try again later.');
  }
}

/// Seam for the `invite-user` Edge Function. Tests supply a fake.
abstract class InviteService {
  /// Throws [InviteFailure] on any problem.
  Future<InviteResult> invite(InviteRequest request);
}

class SupabaseInviteService implements InviteService {
  SupabaseInviteService({SupabaseClient? client}) : _client = client;

  static const String functionName = 'invite-user';
  final SupabaseClient? _client;

  @override
  Future<InviteResult> invite(InviteRequest request) async {
    try {
      final client = _client ?? Supabase.instance.client;
      final response =
          await client.functions.invoke(functionName, body: request.toBody());
      final data = response.data;
      if (response.status >= 200 &&
          response.status < 300 &&
          data is Map &&
          data['ok'] == true) {
        return InviteResult(
          userId: data['userId']?.toString() ?? '',
          invited: data['invited'] == true,
          role: UserRoleX.fromString(data['role']?.toString()) ?? request.role,
        );
      }
      throw mapInviteFailure(
        status: response.status,
        serverMessage: data is Map ? data['error']?.toString() : null,
      );
    } on InviteFailure {
      rethrow;
    } on FunctionException catch (e) {
      final d = e.details;
      throw mapInviteFailure(
        // FunctionsFetchException reports status 0: no response reached us.
        status: e.status == 0 ? null : e.status,
        serverMessage: d is Map ? d['error']?.toString() : null,
      );
    } catch (e) {
      // Socket/DNS/timeouts and anything unexpected. Never surface e itself.
      debugPrint('invite-user call failed: ${e.runtimeType}');
      throw mapInviteFailure(status: null);
    }
  }
}

final inviteServiceProvider =
    Provider<InviteService>((ref) => SupabaseInviteService());
