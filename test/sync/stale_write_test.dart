import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/stale_write.dart';

void main() {
  final stored = DateTime.utc(2026, 11, 11, 12);

  test('an edit a day older than the stored change is stale', () {
    expect(
        isStaleWrite(
            incoming: stored.subtract(const Duration(days: 1)), stored: stored),
        isTrue);
  });

  test('a newer or equal edit is accepted', () {
    expect(isStaleWrite(incoming: stored, stored: stored), isFalse);
    expect(
        isStaleWrite(
            incoming: stored.add(const Duration(seconds: 1)), stored: stored),
        isFalse);
  });

  test('within the grace is accepted (latency, small clock error)', () {
    expect(
        isStaleWrite(
            incoming: stored.subtract(const Duration(seconds: 90)),
            stored: stored),
        isFalse);
    expect(
        isStaleWrite(
            incoming: stored.subtract(const Duration(minutes: 2, seconds: 1)),
            stored: stored),
        isTrue);
  });
}
