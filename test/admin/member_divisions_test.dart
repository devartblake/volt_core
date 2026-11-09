import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/division.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/domain/invite_validator.dart';
import 'package:voltcore/modules/admin/domain/audit_log.dart';
import 'package:voltcore/modules/admin/infra/services/invite_service.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

const _a = Division(id: 'a', name: 'Generators', sortOrder: 0);
const _b = Division(id: 'b', name: 'Fire alarm', sortOrder: 1);
const _c = Division(id: 'c', name: 'Controls', sortOrder: 2);

void main() {
  test('divisionNamesOf follows the admin order and skips unknown ids', () {
    expect(divisionNamesOf(['c', 'a', 'zzz'], [_c, _a, _b]),
        ['Generators', 'Controls']);
    expect(divisionNamesOf(const [], [_a]), isEmpty);
  });

  test('orderedDivisionIds de-duplicates, drops blanks and orders', () {
    expect(orderedDivisionIds(['b', 'a', 'b', ''], [_a, _b, _c]), ['a', 'b']);
    // Unknown (for example deleted) ids are kept after the known ones.
    expect(orderedDivisionIds(['x', 'a'], [_a]), ['a', 'x']);
  });

  test('a member can hold several divisions and copyWith replaces them', () {
    const m = TenantMemberEntity(
      tenantId: 't',
      userId: 'u',
      displayName: 'N',
      email: 'n@example.com',
      role: UserRole.tech,
      isActive: true,
      divisionIds: ['a', 'b'],
    );
    expect(m.divisionIds, ['a', 'b']);
    expect(m.copyWith(divisionIds: const []).divisionIds, isEmpty);
    expect(m.copyWith(role: UserRole.admin).divisionIds, ['a', 'b']);
  });

  test('InviteRequest sends divisionIds, plus the first as the older divisionId',
      () {
    const r = InviteRequest(
      email: 'a@b.co',
      displayName: 'A',
      role: UserRole.tech,
      divisionIds: ['a', 'b'],
    );
    final body = r.toBody();
    expect(body['divisionIds'], ['a', 'b']);
    expect(body['divisionId'], 'a');
    const none = InviteRequest(
        email: 'a@b.co', displayName: 'A', role: UserRole.tech);
    expect(none.toBody().containsKey('divisionIds'), isFalse);
    expect(none.toBody().containsKey('divisionId'), isFalse);
  });

  test('InviteValidator.divisions allows at most 10', () {
    expect(InviteValidator.divisions(['a', 'b']), isNull);
    expect(
        InviteValidator.divisions([for (var i = 0; i < 10; i++) 'd$i']), isNull);
    expect(
        InviteValidator.divisions([for (var i = 0; i < 11; i++) 'd$i']),
        'Choose at most 10 divisions.');
    // Duplicates count once.
    expect(InviteValidator.divisions([for (var i = 0; i < 20; i++) 'same']),
        isNull);
  });

  test('the audit page knows the two new tables', () {
    expect(auditTableLabel('member_permission_overrides'), 'Permission');
    expect(auditTableLabel('member_divisions'), 'Division');
    expect(auditGroupOf('member_permission_overrides'), AuditGroup.people);
    expect(auditGroupOf('member_divisions'), AuditGroup.people);
  });
}
