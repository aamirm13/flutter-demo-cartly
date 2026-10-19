import 'dart:async';

import 'package:cartly/models/product.dart';
import 'package:cartly/models/product_page.dart';
import 'package:cartly/providers/catalogue_controller.dart';
import 'package:cartly/services/product_service.dart';
import 'package:cartly/utils/product_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class ControlledService extends ProductService {
  Future<ProductPage> Function(int)? pageLoader;
  Future<List<Product>> Function()? allLoader;
  final offsets = <int>[];
  int allCalls = 0;
  @override
  Future<ProductPage> fetchProducts({int limit = 20, int skip = 0}) {
    offsets.add(skip);
    return pageLoader?.call(skip) ??
        Future.value(const ProductPage([sample], 1));
  }

  @override
  Future<List<Product>> fetchAll() {
    allCalls++;
    return allLoader?.call() ?? Future.value([sample]);
  }
}

void main() {
  late ControlledService service;
  late CatalogueController catalogue;
  setUp(() {
    service = ControlledService();
    catalogue = CatalogueController(service);
  });
  tearDown(() {
    catalogue.dispose();
    service.dispose();
  });

  test('initial network error can recover on the same controller', () async {
    service.pageLoader = (_) =>
        Future.error(const ProductServiceException('Connection lost'));
    await catalogue.refresh();
    expect(catalogue.error, 'Connection lost');
    expect(catalogue.loading, false);
    service.pageLoader = (_) async => const ProductPage([sample], 1);
    await catalogue.refresh();
    expect(catalogue.error, isNull);
    expect(catalogue.products.single.id, 1);
    expect(service.offsets, [0, 0]);
  });
  test(
    'global dataset errors are retryable without clearing selections',
    () async {
      catalogue.query = 'bag';
      catalogue.categories = {'bags'};
      catalogue.price = PriceBand.under25;
      service.allLoader = () =>
          Future.error(const ProductServiceException('Try again'));
      await catalogue.refresh();
      expect(catalogue.error, 'Try again');
      service.allLoader = () async => [sample];
      await catalogue.refresh();
      expect(catalogue.error, isNull);
      expect(catalogue.products.single.id, 1);
      expect(catalogue.query, 'bag');
      expect(catalogue.categories, {'bags'});
      expect(catalogue.price, PriceBand.under25);
    },
  );
  test('latest query wins when the complete dataset arrives late', () async {
    final pending = Completer<List<Product>>();
    service.allLoader = () => pending.future;
    catalogue.query = 'bag';
    final first = catalogue.refresh();
    catalogue.query = 'desk';
    final second = catalogue.refresh();
    pending.complete([sample, const Product(id: 2, title: 'Desk', price: 100)]);
    await Future.wait([first, second]);
    expect(catalogue.products.single.id, 2);
    expect(catalogue.loading, false);
  });
  test('stale search error cannot replace a successful reset', () async {
    final pending = Completer<List<Product>>();
    service.allLoader = () => pending.future;
    catalogue.query = 'bag';
    final stale = catalogue.refresh();
    catalogue.query = '';
    await catalogue.refresh();
    pending.completeError(const ProductServiceException('Old error'));
    await stale;
    expect(catalogue.error, isNull);
    expect(catalogue.products.single.id, 1);
    expect(catalogue.loading, false);
  });
  test(
    'stale pagination failure leaves the current filtered result usable',
    () async {
      final pending = Completer<ProductPage>();
      service.pageLoader = (skip) => skip == 0
          ? Future.value(const ProductPage([sample], 2))
          : pending.future;
      await catalogue.refresh();
      final stale = catalogue.loadMore();
      catalogue.query = 'bag';
      await catalogue.refresh();
      pending.completeError(
        const ProductServiceException('Old pagination error'),
      );
      await stale;
      expect(catalogue.pageError, isNull);
      expect(catalogue.error, isNull);
      expect(catalogue.loadingMore, false);
      expect(catalogue.products.single.id, 1);
    },
  );
  test('reset restores server pages and clears every query group', () async {
    await catalogue.refresh();
    catalogue.query = 'bag';
    catalogue.categories = {'bags'};
    catalogue.price = PriceBand.under25;
    catalogue.sort = ProductSort.name;
    await catalogue.refresh();
    catalogue.reset();
    expect(catalogue.query, isEmpty);
    expect(catalogue.categories, isEmpty);
    expect(catalogue.price, PriceBand.all);
    expect(catalogue.sort, ProductSort.featured);
    expect(catalogue.isGlobal, false);
    expect(catalogue.products.single.id, 1);
    expect(service.offsets, [
      0,
    ], reason: 'Keep the already loaded default pages');
  });
  test(
    'empty server page stops pagination even if total is overstated',
    () async {
      service.pageLoader = (skip) async => skip == 0
          ? const ProductPage([sample], 99)
          : const ProductPage([], 99);
      await catalogue.refresh();
      await catalogue.loadMore();
      await catalogue.loadMore();
      expect(service.offsets, [0, 1]);
      expect(catalogue.hasMore, false);
      expect(catalogue.products.single.id, 1);
    },
  );
  test(
    'global no-results state never falls back to unfiltered pages',
    () async {
      await catalogue.refresh();
      catalogue.query = 'no match';
      await catalogue.refresh();
      await catalogue.loadMore();
      expect(catalogue.products, isEmpty);
      expect(catalogue.resultCount, 0);
      expect(catalogue.hasMore, false);
      expect(service.offsets, [0]);
    },
  );
  test('disposing while loading ignores a late response safely', () async {
    final pending = Completer<ProductPage>();
    final local = CatalogueController(service);
    service.pageLoader = (_) => pending.future;
    var notifications = 0;
    local.addListener(() => notifications++);
    final request = local.refresh();
    local.dispose();
    pending.complete(const ProductPage([sample], 1));
    await request;
    expect(notifications, 1);
  });
}
