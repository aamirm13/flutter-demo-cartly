import 'package:cartly/models/product.dart';
import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/screens/catalogue_screen.dart';
import 'package:cartly/screens/product_detail_screen.dart';
import 'package:cartly/theme/app_theme.dart';
import 'package:cartly/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

Widget host(Widget child, {CartProvider? cart}) => ChangeNotifierProvider.value(
  value: cart ?? CartProvider(),
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

class CategoriesService extends FakeProductService {
  @override
  Future<List<ProductCategory>> fetchCategories() async => [
    const ProductCategory('bags', 'Bags'),
    const ProductCategory('home', 'Home'),
  ];
}

void main() {
  testWidgets(
    'search waits for debounce, uses one full dataset, and Reset Filters recovers',
    (tester) async {
      final service = FakeProductService();
      await tester.pumpWidget(
        host(CatalogueScreen(service: service, onCart: () {})),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'bag');
      await tester.pump(const Duration(milliseconds: 349));
      expect(service.allCalls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(service.allCalls, 1);
      expect(find.byType(ProductCard), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matching item');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(service.allCalls, 1);
      await tester.ensureVisible(find.text('Reset Filters').last);
      await tester.pumpAndSettle();
      expect(find.text('No finds just yet'), findsOneWidget);
      await tester.tap(find.text('Reset Filters').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(ProductCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'multiple category checkboxes apply OR and Cancel leaves selection intact',
    (tester) async {
      final service = CategoriesService()
        ..data = [
          sample,
          const Product(id: 2, title: 'Desk', category: 'home', price: 100),
          const Product(id: 3, title: 'Apple', category: 'food', price: 1),
        ];
      await tester.pumpWidget(
        host(CatalogueScreen(service: service, onCart: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bags'));
      await tester.tap(find.text('Home'));
      await tester.tap(find.text('Apply categories'));
      await tester.pumpAndSettle();
      expect(find.text('Categories (2)'), findsOneWidget);
      expect(find.text('2 finds'), findsOneWidget);
      await tester.tap(find.text('Categories (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      // Dismiss the sheet without applying its temporary selections.
      Navigator.of(tester.element(find.text('Apply categories'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Categories (2)'), findsOneWidget);
      expect(find.text('2 finds'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets('out-of-stock details disable adding without changing the cart', (
    tester,
  ) async {
    final service = FakeProductService()
      ..data = [
        const Product(id: 1, title: 'Unavailable bag', price: 10, stock: 0),
      ];
    final cart = CartProvider();
    await tester.pumpWidget(
      host(
        ProductDetailScreen(productId: 1, service: service, onCart: () {}),
        cart: cart,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(cart.itemCount, 0);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets('product details recover through Retry after a failed request', (
    tester,
  ) async {
    final service = FakeProductService()..fail = true;
    await tester.pumpWidget(
      host(ProductDetailScreen(productId: 1, service: service, onCart: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to connect.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Everyday bag'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Everyday bag'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
