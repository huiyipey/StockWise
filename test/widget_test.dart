import 'package:flutter_test/flutter_test.dart';

import 'package:stock_wise/models/app_models.dart';
import 'package:stock_wise/screens/login_screen.dart';
import 'package:stock_wise/services/store_session.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('StockWise'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  test('Store session keeps the selected store and role isolated', () {
    const store = StoreInfo(id: 'store-a', name: 'Main Shop', code: 'MAIN');
    StoreSession.instance.select(store, role: 'manager');

    expect(StoreSession.instance.storeId, 'store-a');
    expect(StoreSession.instance.canManage, isTrue);
    expect(StoreSession.instance.canManageMembers, isTrue);

    StoreSession.instance.clear();
    expect(StoreSession.instance.storeId, isNull);
    expect(StoreSession.instance.role, 'customer');
  });

  test('Inventory calculations honor reservations and promotions', () {
    final batch = InventoryBatch(
      id: 'batch-a',
      productId: 'product-a',
      productName: 'Milk',
      categoryId: 'dairy',
      unitLabel: 'carton',
      expiryAt: DateTime.now().add(const Duration(days: 3)),
      quantityOnHand: 10,
      quantityReserved: 3,
      basePriceCents: 750,
      promotionEnabled: true,
      promotionPriceCents: 500,
      notifyOnExpiry: true,
      status: 'active',
    );

    expect(batch.availableQuantity, 7);
    expect(batch.sellingPriceCents, 500);
  });
}
