import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/inspections/infra/models/inspection.dart';

class EmailService {
  // Configure your destination email address here:
  static const String kTo = 'office@aselectricnyc.com';

  // For production: store SMTP creds securely, not hard-coded.
  final String smtpHost = 'smtp.yourdomain.com';
  final int smtpPort = 587;
  final String smtpUser = 'no-reply@yourdomain.com';
  final String smtpPass = '***app-password***';

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
    final server = SmtpServer(smtpHost, port: smtpPort, username: smtpUser, password: smtpPass);
    final message = Message()
      ..from = Address(smtpUser, 'A&S Electric')
      ..recipients.add(kTo)
      ..subject = subject
      ..text = body
      ..attachments = [ FileAttachment(File(pdfPath)) ];

    await send(message, server);
  }
}
