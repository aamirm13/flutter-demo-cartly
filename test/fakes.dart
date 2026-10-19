import 'dart:async';

import 'package:cartly/models/product.dart';
import 'package:cartly/models/product_page.dart';
import 'package:cartly/services/product_service.dart';

const sample = Product(
  id: 1,
  title: 'Everyday bag',
  price: 19.99,
  category: 'bags',
  rating: 4.5,
  stock: 10,
  description: 'A useful companion',
);

class FakeProductService extends ProductService {
  bool fail = false;
  int pageCalls = 0;
  int allCalls = 0;
  Completer<ProductPage>? pending;
  Map<int, ProductPage>? pages;
  List<Product> data = [sample];
  @override
  Future<ProductPage> fetchProducts({int limit = 20, int skip = 0}) async {
    pageCalls++;
    if (fail) {
      throw const ProductServiceException(
        'Unable to connect. Check your connection and try again.',
      );
    }
    if (pending != null) return pending!.future;
    if (pages != null) return pages![skip]!;
    return ProductPage(
      data.skip(skip).take(limit == 0 ? data.length : limit).toList(),
      data.length,
    );
  }

  @override
  Future<List<Product>> fetchAll() async {
    allCalls++;
    return data;
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async => [
    const ProductCategory('bags', 'Bags'),
  ];
  @override
  Future<Product> fetchProduct(int id) async {
    if (fail) throw const ProductServiceException('Unable to connect.');
    return data.firstWhere((p) => p.id == id);
  }
}
