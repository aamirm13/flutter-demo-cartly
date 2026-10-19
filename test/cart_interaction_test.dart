import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/screens/cart_screen.dart';
import 'package:cartly/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'minus keeps its field in sync when the final quantity equals the previous value',
    (tester) async {
      final cart = CartProvider()
        ..add(sample)
        ..add(sample);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: CartScreen(onShop: () {})),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.byTooltip('Decrease quantity of Everyday bag'));
      await tester.pumpAndSettle();
      expect(cart.itemCount, 2);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2',
      );
    },
  );
  testWidgets('plus commits the typed quantity before increasing it', (
    tester,
  ) async {
    final cart = CartProvider()..add(sample);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CartScreen(onShop: () {})),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.byTooltip('Increase quantity of Everyday bag'));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 4);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '4',
    );
  });
  testWidgets(
    'quantity rejects invalid decimal input and restores the stored value',
    (tester) async {
      final cart = CartProvider()..add(sample);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: cart,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: CartScreen(onShop: () {})),
          ),
        ),
      );
      for (final invalid in ['', '0', '-2', '1.5', 'abc', '10000', '0x10']) {
        await tester.enterText(find.byType(TextField), invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(cart.itemCount, 1, reason: invalid);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '1',
        );
        expect(find.text('Enter 1–9,999'), findsOneWidget);
      }
    },
  );
  testWidgets('checkout includes a quantity edit before keyboard Done', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cart = CartProvider()..add(sample);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CartScreen(onShop: () {})),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Demo Checkout'));
    await tester.pumpAndSettle();
    expect(find.text(r'3 items · $70.96 illustrative total'), findsOneWidget);
    expect(cart.itemCount, 0);
    expect(tester.takeException(), isNull);
  });
}
