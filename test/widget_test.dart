import 'package:flutter_test/flutter_test.dart';
import 'package:devicescope/main.dart';

void main() {
  testWidgets('DeviceScope dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DeviceScopeApp());

    expect(find.text('DeviceScope'), findsOneWidget);
    expect(find.text('Smartphone Diagnostics'), findsOneWidget);
    expect(find.text('DIAGNOSTIC TOOLS'), findsOneWidget);
  });
}
