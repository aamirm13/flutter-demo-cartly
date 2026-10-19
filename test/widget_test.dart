import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cartly/app.dart';
import 'package:cartly/models/product_page.dart';
import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/screens/cart_screen.dart';
import 'package:cartly/screens/catalogue_screen.dart';
import 'package:cartly/screens/product_detail_screen.dart';
import 'package:cartly/theme/app_theme.dart';
import 'package:cartly/widgets/product_card.dart';

import 'fakes.dart';

Widget host(Widget child, {CartProvider? cart}) => ChangeNotifierProvider.value(
  value: cart ?? CartProvider(),
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);
void main() {
  testWidgets('catalogue shows circular loading indicator', (tester) async {
    final service = FakeProductService()..pending = Completer<ProductPage>();
    await tester.pumpWidget(
      host(CatalogueScreen(service: service, onCart: () {})),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CircularProgressIndicator),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pending!.complete(const ProductPage([], 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('catalogue error has working Retry', (tester) async {
    final service = FakeProductService()..fail = true;
    await tester.pumpWidget(
      host(CatalogueScreen(service: service, onCart: () {})),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Retry'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to connect.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductCard), findsOneWidget);
    expect(service.pageCalls, 2);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('product card shows source price, rating and title', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: ProductCard(product: sample, onTap: () => tapped = true),
        ),
      ),
    );
    expect(find.text('Everyday bag'), findsOneWidget);
    expect(find.text(r'$19.99'), findsOneWidget);
    expect(find.textContaining('4.50'), findsOneWidget);
    await tester.tap(find.byType(ProductCard));
    expect(tapped, true);
  });
  testWidgets('empty cart Continue Shopping works', (tester) async {
    var continued = false;
    await tester.pumpWidget(host(CartScreen(onShop: () => continued = true)));
    expect(find.textContaining('Your cart is empty'), findsOneWidget);
    await tester.tap(find.text('Continue Shopping'));
    expect(continued, true);
  });
  testWidgets('quantity buttons, editing, validation and confirmed removal', (
    tester,
  ) async {
    final cart = CartProvider()..add(sample);
    await tester.pumpWidget(host(CartScreen(onShop: () {}), cart: cart));
    await tester.tap(find.byTooltip('Increase quantity of Everyday bag'));
    await tester.pump();
    expect(cart.itemCount, 2);
    await tester.tap(find.byTooltip('Decrease quantity of Everyday bag'));
    await tester.pump();
    expect(cart.itemCount, 1);
    await tester.enterText(find.byType(TextField), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.itemCount, 3);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '3',
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.itemCount, 3);
    expect(find.text('Enter 1–9,999'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Everyday bag'));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 3);
    await tester.tap(find.text('Keep item'));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 3);
    await tester.tap(find.byTooltip('Remove Everyday bag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 0);
  });
  testWidgets('demo checkout clears cart and explains simulated result', (
    tester,
  ) async {
    final cart = CartProvider()..add(sample);
    var continued = false;
    await tester.pumpWidget(
      host(CartScreen(onShop: () => continued = true), cart: cart),
    );
    await tester.scrollUntilVisible(
      find.text('Demo Checkout'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Demo Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Demo checkout complete'), findsOneWidget);
    expect(find.textContaining('No real order was placed'), findsOneWidget);
    expect(cart.itemCount, 0);
    await tester.ensureVisible(find.text('Continue Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Shopping'));
    await tester.pumpAndSettle();
    expect(continued, true);
    expect(find.textContaining('Your cart is empty'), findsOneWidget);
  });
  testWidgets('details add stays on page and immediately updates badge', (
    tester,
  ) async {
    final service = FakeProductService();
    final cart = CartProvider();
    await tester.pumpWidget(
      host(
        ProductDetailScreen(productId: 1, service: service, onCart: () {}),
        cart: cart,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();
    expect(cart.itemCount, 1);
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.byTooltip('Open cart, 1 items'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('tabs preserve search text and selected price band', (
    tester,
  ) async {
    final service = FakeProductService();
    await tester.pumpWidget(CartlyApp(service: service));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bag');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Under $25'));
    await tester.pumpAndSettle();
    final catalogueScroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    catalogueScroll.jumpTo(200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'bag',
    );
    expect(find.text('Reset Filters'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text(r'Under $25'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      true,
    );
    expect(catalogueScroll.offset, 200);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('cart supports narrow screens with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cart = CartProvider()..add(sample);
    await tester.pumpWidget(
      host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
          child: CartScreen(onShop: () {}),
        ),
        cart: cart,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('catalogue supports narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeProductService();
    await tester.pumpWidget(
      host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
          child: CatalogueScreen(service: service, onCart: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
