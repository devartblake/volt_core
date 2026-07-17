import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/photos/photo_attachment.dart';

void main() {
  group('PhotoAttachment', () {
    test('round-trips through JSON', () {
      final photo = PhotoAttachment(
        id: 'p1',
        ownerType: PhotoAttachment.ownerInspection,
        ownerId: 'i1',
        localPath: '/root/photos/inspection/i1/p1.jpg',
        remotePath: 'photos/inspection/i1/p1.jpg',
        caption: 'Corroded terminal',
        sizeBytes: 2048,
      );

      final restored = PhotoAttachment.fromJson(photo.toJson());

      expect(restored.id, 'p1');
      expect(restored.ownerType, PhotoAttachment.ownerInspection);
      expect(restored.ownerId, 'i1');
      expect(restored.localPath, '/root/photos/inspection/i1/p1.jpg');
      expect(restored.remotePath, 'photos/inspection/i1/p1.jpg');
      expect(restored.caption, 'Corroded terminal');
      expect(restored.sizeBytes, 2048);
    });

    test('copyWith updates caption only', () {
      final photo = PhotoAttachment(
        id: 'p2',
        ownerType: PhotoAttachment.ownerMaintenance,
        ownerId: 'm1',
        localPath: '/x.jpg',
        caption: 'old',
      );
      final updated = photo.copyWith(caption: 'new');
      expect(updated.caption, 'new');
      expect(updated.id, 'p2');
      expect(updated.ownerId, 'm1');
    });
  });
}
