import 'dart:async';

import 'package:cartly/services/product_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'a stalled HTTP request times out after 15 seconds and can retry',
    (tester) async {
      final stalled = Completer<http.Response>();
      var calls = 0;
      final service = ProductService(
        client: MockClient(
          (_) => ++calls == 1
              ? stalled.future
              : Future.value(http.Response('{"products":[],"total":0}', 200)),
        ),
      );
      final request = service.fetchProducts();
      final assertion = expectLater(
        request,
        throwsA(
          isA<ProductServiceException>().having(
            (e) => e.message,
            'message',
            contains('connection'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 14));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 2));
      await assertion;
      final retry = service.fetchProducts();
      await tester.pump();
      expect((await retry).products, isEmpty);
      // A late completion from the timed-out request does not alter retry data.
      stalled.complete(
        http.Response('{"products":[{"id":99}],"total":1}', 200),
      );
      await tester.pump();
      service.dispose();
    },
  );
  for (final body in ['null', '[]', '"wrong shape"']) {
    test('malformed detail response $body becomes a readable error', () async {
      final service = ProductService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.fetchProduct(1),
        throwsA(
          isA<ProductServiceException>().having(
            (e) => e.message,
            'message',
            'We could not read this product. Please try again.',
          ),
        ),
      );
      service.dispose();
    });
  }
  test('detail HTTP failure preserves the friendly service error', () async {
    final service = ProductService(
      client: MockClient(
        (_) async => http.Response('internal server text', 500),
      ),
    );
    await expectLater(
      service.fetchProduct(1),
      throwsA(
        isA<ProductServiceException>().having(
          (e) => e.message,
          'message',
          isNot(contains('internal server text')),
        ),
      ),
    );
    service.dispose();
  });
  test('invalid category envelope is retryable', () async {
    var calls = 0;
    final service = ProductService(
      client: MockClient(
        (_) async => http.Response(
          ++calls == 1
              ? '{}'
              : '[null,42,"skin-care",{"slug":"home","name":"Home"}]',
          200,
        ),
      ),
    );
    await expectLater(
      service.fetchCategories(),
      throwsA(isA<ProductServiceException>()),
    );
    final categories = await service.fetchCategories();
    expect(categories.map((c) => c.slug), ['skin-care', 'home']);
    expect(categories.map((c) => c.name), ['Skin Care', 'Home']);
    service.dispose();
  });
}
