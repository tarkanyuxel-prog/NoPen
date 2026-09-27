import 'package:flutter_test/flutter_test.dart';
import 'package:nopen/main.dart';

void main() {
  testWidgets('NoPen opens', (tester) async {
    await tester.pumpWidget(const NoPenApp());
    expect(find.text('NoPen'), findsOneWidget);
    expect(find.text('Bugünkü Toplantılar'), findsOneWidget);
  });
}
