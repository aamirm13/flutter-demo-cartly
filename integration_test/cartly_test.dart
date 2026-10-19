// On-device tests deliberately use the live sample API. Run separately from
// the deterministic unit/widget suite; see README for the flutter drive command.

import 'package:cartly/app.dart';
import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/screens/product_detail_screen.dart';
import 'package:cartly/services/product_service.dart';
import 'package:cartly/utils/currency_formatter.dart';
import 'package:cartly/utils/product_filters.dart';
import 'package:cartly/widgets/cart_item_tile.dart';
import 'package:cartly/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

class ObservedClient extends http.BaseClient {
  final http.Client real = http.Client();
  final List<Uri> requests = [];
  bool offline = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request.url);
    if (offline) {
      throw http.ClientException('Controlled test connection failure');
    }
    return real.send(request);
  }

  @override
  void close() => real.close();
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out: $reason');
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 40),
  );
  await tester.tap(finder);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 40),
  );
}

Future<void> enterValue(WidgetTester tester, Finder field, String value) async {
  // A native keyboard connection must be reopened after tab changes/unfocus.
  await tapVisible(tester, field);
  await tester.enterText(field, value);
  expect(tester.widget<TextField>(field).controller!.text, value);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android shopping, discovery, recovery and checkout', (
    tester,
  ) async {
    final client = ObservedClient()..offline = true;
    final service = ProductService(client: client);
    final checkpoints = <String>[];
    void checked(String text) {
      checkpoints.add(text);
      debugPrint('DEVICE CHECK: $text');
    }

    Future<void> screenshot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await tester.pumpWidget(CartlyApp(service: service));
    await waitFor(
      tester,
      () => find.text('Retry').evaluate().isNotEmpty,
      'initial connection error',
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await tapVisible(tester, find.text('Retry categories'));
    expect(find.text('Could not load categories.'), findsOneWidget);
    await screenshot('api-error');
    client.offline = false;
    await tapVisible(tester, find.text('Retry'));
    await waitFor(
      tester,
      () => find.byType(ProductCard).evaluate().isNotEmpty,
      'live catalogue',
    );
    await tapVisible(tester, find.text('Retry categories'));
    expect(find.text('Categories'), findsOneWidget);
    checked(
      'Initial connection error and category Retry recover with real API data',
    );

    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final first = tester
        .widget<ProductCard>(find.byType(ProductCard).first)
        .product;
    expect(first.id, greaterThan(0));
    expect(first.thumbnail, isNotEmpty);
    await screenshot('shop');

    // Fail the next page through the transport, then retry against the real API.
    client.offline = true;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await waitFor(
      tester,
      () => find.text('Retry more products').evaluate().isNotEmpty,
      'pagination error',
    );
    expect(
      client.requests.any((uri) => uri.queryParameters['skip'] == '20'),
      true,
    );
    client.offline = false;
    await tapVisible(tester, find.text('Retry more products'));
    await waitFor(
      tester,
      () =>
          client.requests
                  .where((uri) => uri.queryParameters['skip'] == '20')
                  .length >=
              2 &&
          find.text('Retry more products').evaluate().isEmpty,
      'pagination retry',
    );
    expect(tester.takeException(), isNull);
    checked(
      'Server pagination requests skip=20, preserves earlier items and recovers from failure',
    );

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await enterValue(tester, find.byType(TextField), first.title);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(
      tester,
      () =>
          find.text('Your selection').evaluate().isNotEmpty &&
          find.byType(ProductCard).evaluate().isNotEmpty,
      'global search',
    );
    final all = await service.fetchAll();
    final categories = await service.fetchCategories();
    expect(all.length, greaterThan(20));
    final expectedSearch = all
        .where(
          (p) =>
              p.title.toLowerCase().contains(first.title.toLowerCase()) ||
              p.description.toLowerCase().contains(first.title.toLowerCase()),
        )
        .length;
    expect(find.text('$expectedSearch finds'), findsOneWidget);
    final downloads = client.requests
        .where((uri) => uri.queryParameters['limit'] == '0')
        .length;
    expect(downloads, 1);

    await tapVisible(tester, find.text('Categories'));
    final selectedCategory = categories.firstWhere(
      (c) => c.slug == first.category,
    );
    final otherCategory = categories.firstWhere(
      (c) => c.slug != first.category,
    );
    await tapVisible(tester, find.text(selectedCategory.name));
    await tapVisible(tester, find.text(otherCategory.name));
    await tapVisible(tester, find.text('Apply categories'));
    expect(find.text('Categories (2)'), findsOneWidget);

    final band = PriceBand.values
        .skip(1)
        .firstWhere((band) => band.matches(first.priceCents));
    await tapVisible(tester, find.text(band.label));
    await tapVisible(tester, find.text(ProductSort.featured.label));
    await tapVisible(tester, find.text(ProductSort.priceDescending.label));
    final expectedCombined = all
        .where(
          (p) =>
              (p.category == selectedCategory.slug ||
                  p.category == otherCategory.slug) &&
              band.matches(p.priceCents) &&
              (p.title.toLowerCase().contains(first.title.toLowerCase()) ||
                  p.description.toLowerCase().contains(
                    first.title.toLowerCase(),
                  )),
        )
        .length;
    expect(find.text('$expectedCombined finds'), findsOneWidget);
    final savedOffset = scroll.offset;
    await tapVisible(tester, find.text('Cart').last);
    expect(find.textContaining('Your cart is empty'), findsOneWidget);
    await tapVisible(tester, find.text('Shop').last);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      first.title,
    );
    expect(find.text('Categories (2)'), findsOneWidget);
    expect(scroll.offset, savedOffset);
    checked(
      'Live global search, multiple categories, price and sort combine; tab switching preserves state',
    );

    await tapVisible(tester, find.text('Reset Filters').first);
    final galleryProduct = all.firstWhere(
      (p) => !p.unavailable && p.gallery.length > 1,
    );
    await enterValue(tester, find.byType(TextField), galleryProduct.title);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // Global controls add height; reveal cards below the phone viewport.
    scroll.jumpTo(250);
    await tester.pumpAndSettle();
    await waitFor(
      tester,
      () =>
          find.byType(ProductCard).evaluate().isNotEmpty &&
          tester
                  .widget<ProductCard>(find.byType(ProductCard).first)
                  .product
                  .id ==
              galleryProduct.id,
      'gallery product search',
    );
    expect(
      client.requests
          .where((uri) => uri.queryParameters['limit'] == '0')
          .length,
      downloads,
    );
    await tapVisible(tester, find.byType(ProductCard).first);
    await waitFor(
      tester,
      () => find.text('Add to Cart').evaluate().isNotEmpty,
      'detail API request',
    );
    expect(
      client.requests.any(
        (uri) => uri.path == '/products/${galleryProduct.id}',
      ),
      true,
    );
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2 / ${galleryProduct.gallery.length}'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 / ${galleryProduct.gallery.length}'), findsOneWidget);
    if (galleryProduct.shippingInformation != null) {
      await tester.scrollUntilVisible(
        find.text('Shipping information'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Shipping information'));
      expect(find.text(galleryProduct.shippingInformation!), findsOneWidget);
    }
    if (galleryProduct.returnPolicy != null) {
      await tester.scrollUntilVisible(
        find.text('Returns'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Returns'));
      expect(find.text(galleryProduct.returnPolicy!), findsOneWidget);
    }
    await screenshot('product-details');
    await tapVisible(tester, find.text('Add to Cart'));
    await tapVisible(tester, find.text('Add to Cart'));
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.byTooltip('Open cart, 2 items'), findsOneWidget);
    checked(
      'Real detail request, multi-image swipe, shipping/returns, Add to Cart and immediate quantity badge',
    );

    await tapVisible(tester, find.byTooltip('Open cart, 2 items'));
    expect(find.byType(CartItemTile), findsOneWidget);
    final cart = tester.element(find.byType(CartItemTile)).read<CartProvider>();
    expect(cart.itemCount, 2);
    final field = find.byType(TextField);
    await enterValue(tester, field, '3');
    await tapVisible(
      tester,
      find.byTooltip('Increase quantity of ${galleryProduct.title}'),
    );
    expect(cart.itemCount, 4);
    expect(tester.widget<TextField>(field).controller!.text, '4');
    await enterValue(tester, field, '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(cart.itemCount, 4);
    expect(find.text('Enter 1–9,999'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Remove ${galleryProduct.title}'));
    await tapVisible(tester, find.text('Keep item'));
    expect(cart.itemCount, 4);
    await enterValue(tester, field, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await screenshot('cart');
    checked(
      'Merged cart row, pending keyboard edit, quantity controls, invalid input and cancelled removal',
    );

    await enterValue(tester, field, '3');
    // Intentionally leave the keyboard edit unsubmitted before checkout.
    await tester.scrollUntilVisible(
      find.text('Demo Checkout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Demo Checkout'));
    await tester.pumpAndSettle();
    final subtotal = galleryProduct.priceCents * 3;
    final expectedTotal = subtotal + (subtotal + 5) ~/ 10 + 499;
    expect(
      find.text('3 items · ${usd(expectedTotal)} illustrative total'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'No real order was placed and no payment was processed.',
      ),
      findsOneWidget,
    );
    expect(cart.itemCount, 0);
    await screenshot('demo-success');
    await tapVisible(tester, find.text('Continue Shopping'));
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(find.text('Your selection'), findsOneWidget);
    expect(client.requests.every((uri) => !uri.path.contains('orders')), true);
    checked(
      'Demo checkout uses the edited quantity, correct cents, clears cart and returns to preserved Shop',
    );

    // Android back must dismiss the details route and retain the catalogue.
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(ProductCard).first);
    await waitFor(
      tester,
      () => find.text('Add to Cart').evaluate().isNotEmpty,
      'second detail',
    );
    await binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
    checked(
      'Android back returns to the previous catalogue context without framework errors',
    );
    binding.reportData ??= {};
    binding.reportData!['checkpoints'] = checkpoints;
    binding.reportData!['live_request_count'] = client.requests.length;
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
