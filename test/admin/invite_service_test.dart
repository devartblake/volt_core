import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltcore/modules/admin/infra/services/invite_service.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  group('mapInviteFailure', () {
    test('no status means offline', () {
      final f = mapInviteFailure(status: null);
      expect(f.kind, InviteFailureKind.offline);
      expect(f.message, 'Connect to the internet to invite someone.');
    });

    test('400 passes the validator sentence through, capped', () {
      expect(mapInviteFailure(status: 400, serverMessage: 'Enter a name.').message,
          'Enter a name.');
      expect(mapInviteFailure(status: 400).message,
          'Check the details and try again.');
      expect(
          mapInviteFailure(status: 400, serverMessage: 'x' * 500).message,
          'Check the details and try again.');
    });

    test('401 and 403 are not allowed; 429 too many; others server', () {
      expect(mapInviteFailure(status: 401).kind, InviteFailureKind.notAllowed);
      expect(mapInviteFailure(status: 403).kind, InviteFailureKind.notAllowed);
      expect(mapInviteFailure(status: 429).kind, InviteFailureKind.tooMany);
      for (final s in [404, 500, 502, 503]) {
        final f = mapInviteFailure(status: s, serverMessage: 'stack trace');
        expect(f.kind, InviteFailureKind.server);
        expect(f.message, isNot(contains('stack')));
      }
    });
  });

  test('request body uses the database role spelling and omits empty phone', () {
    const r = InviteRequest(
        email: 'a@b.com', displayName: 'A', role: UserRole.tech);
    expect(r.toBody(), {
      'email': 'a@b.com',
      'displayName': 'A',
      'role': 'technician',
    });
    const withPhone = InviteRequest(
        email: 'a@b.com', displayName: 'A', role: UserRole.admin, phone: '555');
    expect(withPhone.toBody()['phone'], '555');
    expect(withPhone.toBody()['role'], 'admin');
  });

  group('SupabaseInviteService over a mock HTTP client', () {
    SupabaseInviteService serviceFor(
        Future<http.Response> Function(http.Request) handler) {
      final client = SupabaseClient('https://example.supabase.co', 'anon-key',
          httpClient: MockClient(handler));
      return SupabaseInviteService(client: client);
    }

    const request = InviteRequest(
        email: 'a@b.com', displayName: 'A', role: UserRole.supervisor);

    test('success', () async {
      late http.Request seen;
      final svc = serviceFor((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'ok': true,
            'userId': 'u1',
            'invited': true,
            'role': 'supervisor'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final result = await svc.invite(request);
      expect(result.userId, 'u1');
      expect(result.invited, isTrue);
      expect(result.role, UserRole.supervisor);
      expect(seen.url.path, endsWith('/functions/v1/invite-user'));
      expect(jsonDecode(seen.body)['role'], 'supervisor');
    });

    for (final entry in {
      400: InviteFailureKind.validation,
      403: InviteFailureKind.notAllowed,
      429: InviteFailureKind.tooMany,
      500: InviteFailureKind.server,
    }.entries) {
      test('HTTP ${entry.key} maps to ${entry.value.name}', () async {
        final svc = serviceFor((_) async => http.Response(
              jsonEncode({'error': 'Enter a name.'}),
              entry.key,
              headers: {'content-type': 'application/json'},
            ));
        await expectLater(
          svc.invite(request),
          throwsA(isA<InviteFailure>()
              .having((f) => f.kind, 'kind', entry.value)),
        );
      });
    }

    test('network error becomes the offline message, never raw text', () async {
      final svc = serviceFor((_) async => throw http.ClientException('boom host'));
      await expectLater(
        svc.invite(request),
        throwsA(isA<InviteFailure>()
            .having((f) => f.kind, 'kind', InviteFailureKind.offline)
            .having((f) => f.message, 'message', isNot(contains('boom')))),
      );
    });
  });
}
