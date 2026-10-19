import 'package:cartly/models/product.dart';
import 'package:cartly/models/product_page.dart';
import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/utils/currency_formatter.dart';
import 'package:cartly/utils/product_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('Defensive product metadata', () {
    test(
      'invalid stock and ratings stay unknown rather than claiming values',
      () {
        for (final invalid in [
          'NaN',
          'Infinity',
          '-Infinity',
          'invalid',
          true,
          <String>[],
        ]) {
          final product = Product.fromJson({
            'id': 1,
            'price': 10,
            'stock': invalid,
            'rating': invalid,
          });
          expect(product.stock, isNull, reason: 'stock: $invalid');
          expect(product.rating, isNull, reason: 'rating: $invalid');
          expect(product.unavailable, false);
          expect(product.availability, 'Availability not provided');
        }
      },
    );
    test('API availability wins over an otherwise healthy stock count', () {
      const low = Product(
        id: 1,
        title: 'Low',
        price: 1,
        stock: 20,
        availabilityStatus: 'Low Stock',
      );
      const out = Product(
        id: 2,
        title: 'Out',
        price: 1,
        stock: 20,
        availabilityStatus: 'OUT OF STOCK',
      );
      expect(low.availability, 'Low stock');
      expect(low.unavailable, false);
      expect(out.availability, 'Out of stock');
      expect(out.unavailable, true);
    });
    test('discount metadata never changes the source price', () {
      for (final discount in [-5.0, 0.0, 100.0, 101.0]) {
        final product = Product(
          id: 1,
          title: 'Bag',
          price: 19.99,
          discountPercentage: discount,
        );
        expect(product.hasDiscount, false);
        expect(product.priceCents, 1999);
      }
      const product = Product(
        id: 1,
        title: 'Bag',
        price: 19.99,
        discountPercentage: 15,
      );
      expect(product.hasDiscount, true);
      expect(product.priceCents, 1999);
    });
    test('gallery prefers images and falls back to the thumbnail', () {
      expect(
        const Product(
          id: 1,
          title: 'Bag',
          price: 1,
          images: ['first', 'second'],
          thumbnail: 'thumb',
        ).gallery,
        ['first', 'second'],
      );
      expect(
        const Product(
          id: 1,
          title: 'Bag',
          price: 1,
          thumbnail: 'thumb',
        ).gallery,
        ['thumb'],
      );
      expect(sample.gallery, isEmpty);
    });
    test(
      'page parsing ignores malformed entries and falls back to parsed count',
      () {
        final page = ProductPage.fromJson({
          'products': [
            null,
            7,
            'wrong',
            {'id': 1, 'price': 3.25},
          ],
          'total': null,
        });
        expect(page.products.single.priceCents, 325);
        expect(page.total, 1);
        expect(
          () => ProductPage.fromJson({'products': {}}),
          throwsFormatException,
        );
      },
    );
    test('category slugs and display names remain separate', () {
      final category = ProductCategory.fromJson({
        'slug': 'home-decoration',
        'name': 'Home & Living',
      });
      expect(category.slug, 'home-decoration');
      expect(category.name, 'Home & Living');
      expect(ProductCategory.fromJson('skin-care').name, 'Skin Care');
      expect(ProductCategory.fromJson(null).slug, isEmpty);
    });
  });

  group('Cart money and state boundaries', () {
    late CartProvider cart;
    setUp(() => cart = CartProvider());
    tearDown(() => cart.dispose());
    test(
      'calculates multiple lines and rounds tax once across the subtotal',
      () {
        cart.add(const Product(id: 1, title: 'First', price: .05));
        cart.add(const Product(id: 2, title: 'Second', price: .05));
        expect(cart.subtotalCents, 10);
        expect(cart.taxCents, 1);
        expect(cart.deliveryCents, 499);
        expect(cart.totalCents, 510);
        cart.remove(1);
        expect(cart.taxCents, 1, reason: 'Half a cent rounds up');
        expect(cart.totalCents, 505);
        cart.clear();
        expect(
          [
            cart.subtotalCents,
            cart.taxCents,
            cart.deliveryCents,
            cart.totalCents,
          ],
          [0, 0, 0, 0],
        );
      },
    );
    test('rounds tax down below half a cent', () {
      cart.add(const Product(id: 1, title: 'First', price: .04));
      expect(cart.taxCents, 0);
      expect(cart.totalCents, 503);
    });
    test(
      'quantity cap applies to direct edits, additions and plus controls',
      () {
        cart.add(sample);
        expect(cart.setQuantity(sample.id, 9999), true);
        expect(cart.add(sample), false);
        cart.increase(sample.id);
        expect(cart.itemCount, 9999);
        cart.decrease(sample.id);
        expect(cart.itemCount, 9998);
      },
    );
    test(
      'unknown IDs and invalid edits leave the cart and listeners unchanged',
      () {
        cart.add(sample);
        var notifications = 0;
        cart.addListener(() => notifications++);
        cart.increase(99);
        cart.decrease(99);
        cart.remove(99);
        expect(cart.setQuantity(1, 0), false);
        expect(cart.itemCount, 1);
        expect(notifications, 0);
      },
    );
    test('exposed cart snapshots cannot mutate provider state', () {
      cart.add(sample);
      final snapshot = cart.items;
      expect(() => snapshot.clear(), throwsUnsupportedError);
      cart.increase(1);
      expect(snapshot.single.quantity, 1);
      expect(cart.items.single.quantity, 2);
    });
    test('USD display keeps exactly two decimal places', () {
      expect(usd(0), r'$0.00');
      expect(usd(5), r'$0.05');
      expect(usd(1999), r'$19.99');
    });
  });

  group('Sorting and filter invariants', () {
    const products = [
      Product(id: 3, title: 'banana', category: 'food', price: 25),
      Product(id: 2, title: 'Apple', category: 'food', price: 25, rating: 4),
      Product(id: 1, title: 'apple', category: 'home', price: 100, rating: 4),
    ];
    test('sorts ties deterministically and keeps unrated products last', () {
      expect(
        filterProducts(products, sort: ProductSort.rating).map((p) => p.id),
        [1, 2, 3],
      );
      expect(
        filterProducts(products, sort: ProductSort.name).map((p) => p.id),
        [1, 2, 3],
      );
      expect(
        filterProducts(
          products,
          sort: ProductSort.priceAscending,
        ).map((p) => p.id),
        [2, 3, 1],
      );
      expect(products.map((p) => p.id), [
        3,
        2,
        1,
      ], reason: 'Never mutate the cached dataset');
    });
    test(
      'whitespace search keeps featured order and no matches stays empty',
      () {
        expect(filterProducts(products, query: '   ').map((p) => p.id), [
          3,
          2,
          1,
        ]);
        expect(filterProducts(products, categories: {'unknown'}), isEmpty);
        expect(
          filterProducts(
            products,
            query: 'apple',
            categories: {'food'},
            price: PriceBand.from100,
          ),
          isEmpty,
        );
      },
    );
  });
}
