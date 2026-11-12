import 'package:voltcore/modules/materials/infra/profile_approval_gateway.dart';

/// In-memory stand-in for the approve_profile_change / reject_profile_change
/// RPCs. Records the calls; can behave as offline or as "already decided".
class FakeApprovalGateway implements ProfileApprovalGateway {
  FakeApprovalGateway({this.offline = false, this.decidedStatus});

  /// When true every call throws [ProfileApprovalOfflineException].
  bool offline;

  /// When set, every call throws [ProfileAlreadyDecidedException] with it.
  String? decidedStatus;

  final List<({String requestId, List<Map<String, dynamic>> items, String note})>
      approvals = [];
  final List<({String requestId, String note})> rejections = [];

  void _check() {
    if (offline) throw const ProfileApprovalOfflineException();
    final d = decidedStatus;
    if (d != null) throw ProfileAlreadyDecidedException(d);
  }

  @override
  Future<void> approve({
    required String requestId,
    required List<Map<String, dynamic>> items,
    String reviewNote = '',
  }) async {
    _check();
    approvals.add((requestId: requestId, items: items, note: reviewNote));
  }

  @override
  Future<void> reject({required String requestId, String reviewNote = ''}) async {
    _check();
    rejections.add((requestId: requestId, note: reviewNote));
  }
}
