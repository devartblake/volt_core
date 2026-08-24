import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/storage/web_file_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('voltcore_web_files_test');
    Hive.init(tempDir.path);
    await WebFileStore.instance.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('lists only requested PDF prefix with size and modification metadata',
      () async {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    await WebFileStore.instance.put(
      'pdfs/inspections/template-response.pdf',
      Uint8List.fromList([1, 2, 3, 4]),
    );
    await WebFileStore.instance.put(
      'signatures/inspections/signature.png',
      Uint8List.fromList([9, 8]),
    );

    final files = WebFileStore.instance.listSync(prefix: 'pdfs/');

    expect(files, hasLength(1));
    expect(files.single.path, 'pdfs/inspections/template-response.pdf');
    expect(files.single.sizeBytes, 4);
    expect(files.single.modified.isAfter(before), isTrue);
  });

  test('remove deletes bytes and listing metadata together', () async {
    const path = 'pdfs/maintenance/template-response.pdf';
    await WebFileStore.instance.put(path, Uint8List.fromList([1, 2, 3]));
    expect(WebFileStore.instance.listSync(prefix: 'pdfs/'), hasLength(1));

    await WebFileStore.instance.remove(path);

    expect(WebFileStore.instance.getSync(path), isNull);
    expect(WebFileStore.instance.listSync(prefix: 'pdfs/'), isEmpty);
  });
}
