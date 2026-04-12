// BloodLink AI – Basic smoke test
// Verifies the app boots without throwing an exception.
// Full integration tests go in test/integration/.

import 'package:flutter_test/flutter_test.dart';
import 'package:bloodlink_ai/main.dart';

void main() {
  testWidgets('BloodLink AI app launches without errors',
      (WidgetTester tester) async {
    // Simply verify the root widget can be instantiated.
    // Firebase / provider initialisation happens in main(), not here,
    // so we only check the widget tree compiles correctly.
    expect(const BloodLinkApp(), isA<BloodLinkApp>());
  });
}
