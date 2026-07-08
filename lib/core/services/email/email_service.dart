import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../modules/inspections/infra/models/inspection.dart';

class EmailService {
  // Destination address – read from env, fall back to known default.
  static String get _to =>
      dotenv.env['SMTP_TO'] ?? 'office@aselectricnyc.com';

  // Backwards-compatible alias used by the web (mailto) branch below.
  static String get kTo => _to;
  // SMTP credentials loaded from flutter_dotenv at runtime.
  String get _smtpHost => dotenv.env['SMTP_HOST'] ?? '';
  int get _smtpPort =>
      int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
  String get _smtpUser => dotenv.env['SMTP_USER'] ?? '';
  String get _smtpPass => dotenv.env['SMTP_PASS'] ?? '';

  Future<void> sendInspectionPdf(Inspection ins, String pdfPath) async {
    final subject = 'Generator Compliance Checklist • ${ins.siteCode} • ${ins.serviceDate.toIso8601String().split("T").first}';
    final body = 'Attached is the completed checklist for ${ins.address}.';

    if (kIsWeb) {
      // Web cannot SMTP directly; open a mailto (or call your API instead).
      final uri = Uri(
        scheme: 'mailto',
        path: kTo,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      await launchUrl(uri);
      return;
    }

    // Mobile/desktop: try SMTP
    final server = SmtpServer(
      _smtpHost,
      port: _smtpPort,
      username: _smtpUser,
      password: _smtpPass,
    );
    final message = Message()
      ..from = Address(_smtpUser, 'A&S Electric')
      ..recipients.add(_to)
      ..subject = subject
      ..text = body
      ..attachments = [FileAttachment(File(pdfPath))];

    await send(message, server);
  }
}
