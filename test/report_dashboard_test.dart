import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_wise/screens/report_dashboard.dart';

void main() {
  testWidgets(
    'Reports fit a phone, switch kind/range, and expose the data view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calls = <List<String>>[];
      Future<Map<String, dynamic>> load(
        String kind,
        String start,
        String end,
      ) async {
        calls.add([kind, start, end]);
        return {
          'kind': kind,
          'start': start,
          'end': end,
          'count': 1,
          'revenueCents': 1234,
          'deliveryCents': 500,
          'totalCents': 1734,
          'units': 4,
          'categories': {'Dairy': 4},
          'daily': [
            {'date': start, 'value': kind == 'sales' ? 1234 : 4},
          ],
          'headers': ['Date', 'Reference', 'Amount'],
          'rows': [
            [start, 'Test order', 12.34],
          ],
          'csv': 'test',
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportDashboard(
              loader: load,
              emailStatus: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RM 12.34'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();
      expect(calls.last[1], calls.last[2]);
      await tester.ensureVisible(find.text('Data'));
      await tester.tap(find.text('Data'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waste'));
      await tester.pumpAndSettle();
      expect(calls.last[0], 'waste');
      expect(find.text('Wasted units'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed reports offer a retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportDashboard(
            loader: (_, _, _) async {
              attempts++;
              throw StateError('offline');
            },
            emailStatus: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
