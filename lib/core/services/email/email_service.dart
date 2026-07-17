import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../modules/inspections/infra/models/inspection.dart';
import '../storage/path_resolver.dart';

/// Sends report emails **server-side** via a Supabase Edge Function.
///
/// This replaces the previous client-side SMTP implementation: SMTP host and
/// credentials no longer ship inside the app bundle — they live as secrets on
/// the `send-report-email` Edge Function (see `supabase/functions/`). The
/// client only forwards the recipient, message, and the PDF bytes.
class EmailService {
  /// Name of the deployed Supabase Edge Function that performs the SMTP send.
  static const String functionName = 'send-report-email';

  /// Default destination, read from env (non-secret) with a known fallback.
  static String get _defaultTo =>
      dotenv.env['SMTP_TO'] ?? 'office@aselectricnyc.com';

  /// Backwards-compatible alias used by the web (mailto) branch.
  static String get kTo => _defaultTo;

  SupabaseClient get _client => Supabase.instance.client;

  /// Email the generated PDF for [ins] to the office (or [recipient]).
  Future<void> sendInspectionPdf(
    Inspection ins,
    String pdfPath, {
    String? recipient,
  }) async {
    final subject =
        'Generator Compliance Checklist • ${ins.siteCode} • '
        '${ins.serviceDate.toIso8601String().split("T").first}';
    final body = 'Attached is the completed checklist for ${ins.address}.';

    await sendReportEmail(
      recipient: recipient ?? _defaultTo,
      subject: subject,
      body: body,
      pdfPath: pdfPath,
      fileName: 'inspection_${ins.siteCode}.pdf',
    );
  }

  /// Generic report email. On mobile/desktop the PDF at [pdfPath] is read and
  /// forwarded (base64) to the Edge Function, which attaches it and sends over
  /// SMTP. On web (no local file access) this falls back to opening a mailto
  /// draft without an attachment.
  Future<void> sendReportEmail({
    required String recipient,
    required String subject,
    required String body,
    String? pdfPath,
    String? fileName,
  }) async {
    if (kIsWeb) {
      await _launchMailto(recipient, subject, body);
      return;
    }

    String? pdfBase64;
    var attachmentName = fileName ?? 'report.pdf';
    if (pdfPath != null && pdfPath.isNotEmpty) {
      final file = File(await PathResolver.resolve(pdfPath));
      if (await file.exists()) {
        pdfBase64 = base64Encode(await file.readAsBytes());
        if (fileName == null) {
          attachmentName = file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'report.pdf';
        }
      }
    }

    try {
      final response = await _client.functions.invoke(
        functionName,
        body: {
          'to': recipient,
          'subject': subject,
          'text': body,
          if (pdfBase64 != null) 'pdfBase64': pdfBase64,
          if (pdfBase64 != null) 'filename': attachmentName,
        },
      );

      final status = response.status;
      if (status < 200 || status >= 300) {
        throw EmailException(
          'Email function returned $status: ${response.data}',
        );
      }
      debugPrint('[EmailService] Report emailed to $recipient via $functionName');
    } on EmailException {
      rethrow;
    } catch (e) {
      // Surface a clear, actionable error to the caller.
      throw EmailException('Failed to send email via $functionName: $e');
    }
  }

  Future<void> _launchMailto(
    String to,
    String subject,
    String body,
  ) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    await launchUrl(uri);
  }
}

/// Raised when a report email cannot be sent.
class EmailException implements Exception {
  const EmailException(this.message);
  final String message;

  @override
  String toString() => 'EmailException: $message';
}
