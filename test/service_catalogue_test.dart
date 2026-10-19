import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cartly/models/product.dart';
import 'package:cartly/models/product_page.dart';
import 'package:cartly/providers/catalogue_controller.dart';
import 'package:cartly/services/product_service.dart';
import 'package:cartly/utils/product_filters.dart';

import 'fakes.dart';

void main() {
  test('page IDs are deduplicated within and between pages', () async {
    final service = FakeProductService()
      ..pages = {
        0: const ProductPage([sample, sample], 4),
        2: const ProductPage([
          sample,
          Product(id: 2, title: 'Second', price: 2),
        ], 4),
      };
    final controller = CatalogueController(service);
    await controller.refresh();
    await controller.loadMore();
    expect(controller.products.map((p) => p.id), [1, 2]);
    expect(controller.hasMore, false);
    controller.dispose();
    service.dispose();
  });
  test('repeated refresh shares an in-flight default page', () async {
    final service = FakeProductService()..pending = Completer<ProductPage>();
    final controller = CatalogueController(service);
    final first = controller.refresh(), second = controller.refresh();
    expect(service.pageCalls, 1);
    service.pending!.complete(const ProductPage([sample], 1));
    await Future.wait([first, second]);
    expect(controller.products.single.id, 1);
    controller.dispose();
    service.dispose();
  });
  test(
    'service uses pagination parameters, typed categories and detail',
    () async {
      final service = ProductService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('categories')) {
            return http.Response('[{"slug":"home","name":"Home"}]', 200);
          }
          if (request.url.path.endsWith('/1')) {
            return http.Response('{"id":1,"title":"Bag","price":2}', 200);
          }
          expect(request.url.queryParameters['limit'], '20');
          expect(request.url.queryParameters['skip'], '40');
          return http.Response(
            '{"products":[{"id":1,"price":2}],"total":41}',
            200,
          );
        }),
      );
      expect((await service.fetchProducts(skip: 40)).total, 41);
      expect((await service.fetchCategories()).single.slug, 'home');
      expect((await service.fetchProduct(1)).title, 'Bag');
      service.dispose();
    },
  );
  test(
    'service caches complete dataset including concurrent callers',
    () async {
      var calls = 0;
      final service = ProductService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['limit'], '0');
          return http.Response(jsonEncode({'products': [], 'total': 0}), 200);
        }),
      );
      await Future.wait([service.fetchAll(), service.fetchAll()]);
      await service.fetchAll();
      expect(calls, 1);
      service.dispose();
    },
  );
  test('failed complete dataset request can be retried', () async {
    var calls = 0;
    final service = ProductService(
      client: MockClient(
        (_) async => ++calls == 1
            ? http.Response('unavailable', 503)
            : http.Response('{"products":[],"total":0}', 200),
      ),
    );
    await expectLater(
      service.fetchAll(),
      throwsA(isA<ProductServiceException>()),
    );
    expect(await service.fetchAll(), isEmpty);
    service.dispose();
  });
  for (final response in [
    http.Response('not json', 200),
    http.Response('{}', 200),
    http.Response('error', 500),
  ]) {
    test(
      'service reports readable errors for ${response.statusCode} ${response.body}',
      () async {
        final service = ProductService(
          client: MockClient((_) async => response),
        );
        await expectLater(
          service.fetchProducts(),
          throwsA(isA<ProductServiceException>()),
        );
        service.dispose();
      },
    );
  }
  test('network exceptions are recoverable messages', () async {
    final service = ProductService(
      client: MockClient(
        (_) async => throw http.ClientException('internal connection info'),
      ),
    );
    await expectLater(
      service.fetchProducts(),
      throwsA(
        isA<ProductServiceException>().having(
          (e) => e.message,
          'message',
          contains('connection'),
        ),
      ),
    );
    service.dispose();
  });
  test(
    'pagination batches, avoids overlapping requests, stops at total',
    () async {
      final service = FakeProductService()
        ..data = List.generate(
          45,
          (i) => Product(id: i, title: 'Product $i', price: i.toDouble()),
        );
      final controller = CatalogueController(service);
      await controller.refresh();
      expect(controller.products.length, 20);
      await Future.wait([controller.loadMore(), controller.loadMore()]);
      expect(controller.products.length, 40);
      expect(service.pageCalls, 2);
      await controller.loadMore();
      await controller.loadMore();
      expect(controller.products.length, 45);
      expect(service.pageCalls, 3);
      expect(controller.hasMore, false);
      controller.dispose();
      service.dispose();
    },
  );
  test('pagination failure retains items and retries', () async {
    final service = FakeProductService()
      ..data = List.generate(25, (i) => Product(id: i, title: '$i', price: 1));
    final controller = CatalogueController(service);
    await controller.refresh();
    service.fail = true;
    await controller.loadMore();
    expect(controller.products.length, 20);
    expect(controller.pageError, isNotNull);
    service.fail = false;
    controller.retryMore();
    await Future<void>.delayed(Duration.zero);
    expect(controller.products.length, 25);
    expect(controller.pageError, isNull);
    controller.dispose();
    service.dispose();
  });
  test(
    'global sort includes later products and reveals twenty at a time',
    () async {
      final service = FakeProductService()
        ..data = List.generate(
          45,
          (i) => Product(id: i, title: '$i', price: i.toDouble()),
        );
      final controller = CatalogueController(service);
      await controller.refresh();
      controller.sort = ProductSort.priceDescending;
      await controller.refresh();
      expect(controller.products.first.id, 44);
      expect(controller.products.length, 20);
      await controller.loadMore();
      expect(controller.products.length, 40);
      controller.query = '4';
      await controller.refresh();
      expect(service.allCalls, 1);
      expect(controller.resultCount, 9);
      controller.dispose();
      service.dispose();
    },
  );
  test('stale default response cannot overwrite a newer search', () async {
    final service = FakeProductService()..pending = Completer<ProductPage>();
    final controller = CatalogueController(service);
    final initial = controller.refresh();
    controller.query = 'bag';
    await controller.refresh();
    expect(controller.products.single.id, 1);
    service.pending!.complete(
      const ProductPage([Product(id: 99, title: 'Stale', price: 1)], 1),
    );
    await initial;
    expect(controller.products.single.id, 1);
    expect(controller.loading, false);
    controller.dispose();
    service.dispose();
  });
}
