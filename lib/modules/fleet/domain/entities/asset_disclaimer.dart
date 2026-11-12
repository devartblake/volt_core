import 'package:uuid/uuid.dart';

/// One numbered clause of the asset disclaimer.
///
/// Structured rather than one blob of prose so the modal and the PDF can print
/// the bold heading exactly as the paper does, without parsing sentences.
class DisclaimerClause {
  const DisclaimerClause({required this.heading, required this.body});

  factory DisclaimerClause.fromJson(Map<String, dynamic> json) =>
      DisclaimerClause(
        heading: (json['heading'] as String?)?.trim() ?? '',
        body: (json['body'] as String?)?.trim() ?? '',
      );

  final String heading;
  final String body;

  Map<String, dynamic> toJson() => {'heading': heading, 'body': body};

  @override
  bool operator ==(Object other) =>
      other is DisclaimerClause && other.heading == heading && other.body == body;

  @override
  int get hashCode => Object.hash(heading, body);
}

/// The liability terms a driver accepts when signing for a vehicle's tools.
///
/// **A published version is never rewritten.** Revising the wording publishes
/// version N+1; version N keeps saying what the people who signed it agreed to.
/// Anything else makes a stored signature meaningless, and it cannot be
/// reconstructed after the fact.
class AssetDisclaimer {
  const AssetDisclaimer({
    required this.id,
    required this.tenantId,
    required this.version,
    required this.title,
    required this.intro,
    required this.clauses,
    required this.closing,
    required this.publishedAt,
    this.publishedBy,
  });

  /// The wording printed on A&S Electric's paper receipt, transcribed from the
  /// form in use as of September 2026.
  ///
  /// This exists so a device that has never synced — a new tablet, a driver on
  /// their first morning — can still show the terms before asking for a
  /// signature. It is the same text as `supabase/manual/seed_asset_disclaimer
  /// .sql`, and `test/fleet/asset_disclaimer_test.dart` fails if the two ever
  /// drift, because two sources of a legal clause is one too many.
  factory AssetDisclaimer.builtIn({required String tenantId}) => AssetDisclaimer(
        id: const Uuid().v5(_kDisclaimerNamespace, 'builtin|$tenantId|v1'),
        tenantId: tenantId,
        version: kBuiltInDisclaimerVersion,
        title: kBuiltInDisclaimerTitle,
        intro: kBuiltInDisclaimerIntro,
        clauses: kBuiltInDisclaimerClauses,
        closing: kBuiltInDisclaimerClosing,
        publishedAt: DateTime.utc(2026, 9, 16),
      );

  final String id;
  final String tenantId;

  /// Monotonic per tenant. Receipts store this number.
  final int version;

  final String title;
  final String intro;
  final List<DisclaimerClause> clauses;
  final String closing;
  final DateTime publishedAt;
  final String? publishedBy;

  /// Plain text, for the PDF and for anywhere a widget tree is unavailable.
  String get plainText {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(intro)
      ..writeln();
    for (var i = 0; i < clauses.length; i++) {
      buffer.writeln('${i + 1}. ${clauses[i].heading}: ${clauses[i].body}');
    }
    buffer
      ..writeln()
      ..writeln(closing);
    return buffer.toString();
  }
}

/// Namespace for the built-in fallback's id. Arbitrary but fixed, following
/// `_kEquipmentNamespace`: a device that falls back offline and later syncs
/// must not mint a second row for the same wording.
const String _kDisclaimerNamespace = 'b0d1f4a2-6e33-4c8d-9a71-5c2e8b71d0f3';

/// The version number of the transcribed wording. Bumping this in code is not
/// how a revision is published — an admin inserts a new row. It is here so the
/// fallback can identify itself.
const int kBuiltInDisclaimerVersion = 1;

const String kBuiltInDisclaimerTitle = 'Asset Disclaimer';

const String kBuiltInDisclaimerIntro =
    'By signing this receipt, the undersigned acknowledges receipt of the '
    'listed assets and agrees to the following terms:';

const String kBuiltInDisclaimerClosing =
    'By signing below, the employee confirms understanding and acceptance of '
    'the above terms.';

const List<DisclaimerClause> kBuiltInDisclaimerClauses = [
  DisclaimerClause(
    heading: 'Responsibility',
    body: 'The employee assumes full responsibility for the care, use, and '
        'return of all assets listed herein. Assets must be used solely for '
        'work-related purposes and in accordance with company policies.',
  ),
  DisclaimerClause(
    heading: 'Condition',
    body: 'All assets are issued in serviceable condition unless otherwise '
        'noted. The employee is responsible for reporting any damage, '
        'malfunction, or missing items immediately to their supervisor or '
        'dispatch personnel.',
  ),
  DisclaimerClause(
    heading: 'Loss or Damage',
    body: 'The employee may be held accountable for any loss, theft, or damage '
        'resulting from negligence, misuse, or failure to follow proper '
        'handling procedures.',
  ),
  DisclaimerClause(
    heading: 'Return of Assets',
    body: 'All assets must be returned in the same condition as issued '
        '(excluding normal wear and tear) upon completion of the job, '
        'reassignment, or termination of employment.',
  ),
  DisclaimerClause(
    heading: 'Inspection',
    body: 'A&S Electric INC. reserves the right to inspect assets at any time '
        'and to request their immediate return if deemed necessary.',
  ),
];
