import 'package:flutter_test/flutter_test.dart';

import 'package:stock_wise/main.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const StockWiseApp());

    expect(find.text('StockWise'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
