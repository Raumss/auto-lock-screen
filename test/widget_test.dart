import 'package:flutter_test/flutter_test.dart';

import 'package:auto_lock_screen/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoLockApp());
    expect(find.text('自动锁屏'), findsOneWidget);
  });
}
