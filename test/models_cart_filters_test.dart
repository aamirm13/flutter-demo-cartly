import 'package:flutter_test/flutter_test.dart';
import 'package:cartly/models/product.dart';
import 'package:cartly/providers/cart_provider.dart';
import 'package:cartly/utils/product_filters.dart';

import 'fakes.dart';

void main() {
  group('Product parsing', () {
    test('valid JSON and numeric strings', () {
      final p = Product.fromJson({
        'id': '12',
        'title': 'Bag',
        'price': '29.95',
        'rating': '4.5',
        'stock': '5',
        'images': ['a', null, 42],
        'discountPercentage': '10',
        'brand': 'Brand',
        'shippingInformation': 'Ships tomorrow',
        'returnPolicy': '30 days',
        'category': 'home-decoration',
      });
      expect(p.id, 12);
      expect(p.priceCents, 2995);
      expect(p.rating, 4.5);
      expect(p.stock, 5);
      expect(p.images, ['a']);
      expect(p.availability, 'Low stock');
      expect(p.hasDiscount, true);
      expect(categoryLabel(p.category), 'Home Decoration');
    });
    test('missing and unexpectedly typed optional values are safe', () {
      final p = Product.fromJson({
        'id': 1,
        'price': 'NaN',
        'brand': {},
        'images': false,
        'stock': 'unknown',
        'thumbnail': 42,
      });
      expect(p.priceCents, 0);
      expect(p.brand, isNull);
      expect(p.gallery, isEmpty);
      expect(p.stock, isNull);
      expect(p.availability, 'Availability not provided');
      expect(Product.fromJson({'stock': 0}).unavailable, true);
      expect(
        Product.fromJson({'availabilityStatus': 'Out of Stock', 'stock': 10})
            .unavailable,
        true,
      );
      expect(
        ProductCategory.fromJson({'slug': 'mobile-accessories'}).name,
        'Mobile Accessories',
      );
    });
    test('finite numbers only', () {
      expect(number(double.infinity), 0);
      expect(number('bad', 4), 4);
      expect(number(5), 5);
    });
  });
  group('Cart', () {
    late CartProvider cart;
    setUp(() => cart = CartProvider());
    test('adds, merges identical IDs, and counts total quantity', () {
      cart.add(sample);
      cart.add(sample);
      expect(cart.items.length, 1);
      expect(cart.itemCount, 2);
      cart.increase(1);
      expect(cart.itemCount, 3);
      cart.decrease(1);
      expect(cart.itemCount, 2);
    });
    test('validates direct quantity and never decreases below one', () {
      cart.add(sample);
      cart.decrease(1);
      expect(cart.itemCount, 1);
      for (final invalid in [0, -1, 10000]) {
        expect(cart.setQuantity(1, invalid), false);
      }
      expect(cart.setQuantity(99, 3), false);
      expect(cart.setQuantity(1, 8), true);
      expect(cart.itemCount, 8);
      expect(
        cart.add(
          const Product(id: 2, title: 'Unavailable', price: 2, stock: 0),
        ),
        false,
      );
    });
    test('integer-cent line subtotal, tax, delivery and final total', () {
      expect(cart.totalCents, 0);
      expect(cart.deliveryCents, 0);
      cart.add(sample);
      cart.setQuantity(1, 3);
      expect(cart.items.single.subtotalCents, 5997);
      expect(cart.subtotalCents, 5997);
      expect(cart.taxCents, 600);
      expect(cart.deliveryCents, 499);
      expect(cart.totalCents, 7096);
    });
    test('remove and clear', () {
      cart.add(sample);
      cart.remove(1);
      expect(cart.items, isEmpty);
      cart.add(sample);
      cart.clear();
      expect(cart.totalCents, 0);
      expect(cart.itemCount, 0);
    });
  });
  group('Global filtering', () {
    const products = [
      sample,
      Product(id: 2, title: 'Apple', price: 25, category: 'food', rating: 3),
      Product(id: 3, title: 'Desk', price: 100, category: 'home', rating: 5),
      Product(
        id: 4,
        title: 'Zebra rug',
        price: 500,
        category: 'home',
        rating: 2,
      ),
    ];
    test('case insensitive search includes description', () {
      expect(filterProducts(products, query: 'BAG').single.id, 1);
      expect(filterProducts(products, query: ' companion ').single.id, 1);
    });
    test('OR categories and AND filter groups', () {
      expect(filterProducts(products, categories: {'home', 'food'}).length, 3);
      expect(
        filterProducts(
          products,
          categories: {'home', 'food'},
          query: 'desk',
          price: PriceBand.from100,
        ).single.id,
        3,
      );
      expect(
        filterProducts(products, categories: {'food'}, query: 'desk'),
        isEmpty,
      );
    });
    test('non-overlapping price boundaries', () {
      expect(PriceBand.under25.matches(2499), true);
      expect(PriceBand.under25.matches(2500), false);
      expect(PriceBand.from25.matches(2500), true);
      expect(PriceBand.from25.matches(10000), false);
      expect(PriceBand.from100.matches(10000), true);
      expect(PriceBand.from100.matches(50000), false);
      expect(PriceBand.from500.matches(50000), true);
    });
    test('all sorts cover the matching set', () {
      List<int> ids(ProductSort sort) =>
          filterProducts(products, sort: sort).map((p) => p.id).toList();
      expect(ids(ProductSort.priceAscending), [1, 2, 3, 4]);
      expect(ids(ProductSort.priceDescending), [4, 3, 2, 1]);
      expect(ids(ProductSort.rating), [3, 1, 2, 4]);
      expect(ids(ProductSort.name), [2, 3, 1, 4]);
    });
  });
}
