import 'package:hive/hive.dart';

/// Simple Hive-backed service to store PDF export preferences
/// on a **per-device** basis (no backend, no shared_prefs).
class PdfPrefsService {
  PdfPrefsService._();

  static final PdfPrefsService instance = PdfPrefsService._();

  static const String _boxName = 'app_settings'; // or your existing settings box
  static const String _keyEmailAllowed = 'pdf_email_allowed';
  static const String _keyCustomDirectoryPath = 'pdf_custom_dir';
  static const String _keyDefaultRecipient = 'pdf_default_recipient';

  Box<dynamic>? _box;

  /// Ensure the settings box is open. Does NOT call Hive.initFlutter().
  Future<Box<dynamic>> _ensureBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<dynamic>(_boxName);
    } else {
      _box = await Hive.openBox<dynamic>(_boxName);
    }

    return _box!;
  }

  /// Returns whether the tech has allowed the app to open the
  /// OS share / email sheet automatically after saving PDFs.
  Future<bool> getEmailAllowed() async {
    final box = await _ensureBox();
    return (box.get(_keyEmailAllowed, defaultValue: false) as bool);
  }

  Future<void> setEmailAllowed(bool value) async {
    final box = await _ensureBox();
    await box.put(_keyEmailAllowed, value);
  }

  /// Optional: custom directory path chosen by the user (desktop, etc.).
  /// On mobile you might ignore this and just use application directories.
  Future<String?> getCustomDirectoryPath() async {
    final box = await _ensureBox();
    final v = box.get(_keyCustomDirectoryPath);
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  Future<void> setCustomDirectoryPath(String? path) async {
    final box = await _ensureBox();
    if (path == null || path.isEmpty) {
      await box.delete(_keyCustomDirectoryPath);
    } else {
      await box.put(_keyCustomDirectoryPath, path);
    }
  }

  /// Optional: default recipient email (e.g. office@yourcompany.com)
  Future<String?> getDefaultRecipient() async {
    final box = await _ensureBox();
    final v = box.get(_keyDefaultRecipient);
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  Future<void> setDefaultRecipient(String? email) async {
    final box = await _ensureBox();
    if (email == null || email.isEmpty) {
      await box.delete(_keyDefaultRecipient);
    } else {
      await box.put(_keyDefaultRecipient, email);
    }
  }
}
