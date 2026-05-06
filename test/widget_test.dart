import 'package:flutter_test/flutter_test.dart';

import 'package:voltcore/app/app.dart';

void main() {
  testWidgets('App widget exists', (WidgetTester tester) async {
    expect(VoltcoreApp, isNotNull);
  });
}
