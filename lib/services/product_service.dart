import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/product_page.dart';

class ProductServiceException implements Exception {
  const ProductServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProductService {
  ProductService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Future<List<Product>>? _all;
  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    try {
      final r = await _client
          .get(Uri.https('dummyjson.com', path, query))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        throw const ProductServiceException(
          'The shop is temporarily unavailable. Please try again.',
        );
      }
      return jsonDecode(r.body);
    } on ProductServiceException {
      rethrow;
    } on FormatException {
      throw const ProductServiceException(
        'We could not read the shop data. Please try again.',
      );
    } catch (_) {
      throw const ProductServiceException(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }

  Future<ProductPage> fetchProducts({int limit = 20, int skip = 0}) async {
    try {
      return ProductPage.fromJson(
        await _get('/products', {'limit': '$limit', 'skip': '$skip'})
            as Map<String, dynamic>,
      );
    } on ProductServiceException {
      rethrow;
    } catch (_) {
      throw const ProductServiceException(
        'We could not read the product list. Please try again.',
      );
    }
  }

  Future<List<Product>> fetchAll() => _all ??= _loadAll();
  Future<List<Product>> _loadAll() async {
    try {
      return (await fetchProducts(limit: 0)).products;
    } catch (_) {
      _all = null;
      rethrow;
    }
  }

  Future<Product> fetchProduct(int id) async {
    try {
      return Product.fromJson(
        await _get('/products/$id') as Map<String, dynamic>,
      );
    } on ProductServiceException {
      rethrow;
    } catch (_) {
      throw const ProductServiceException(
        'We could not read this product. Please try again.',
      );
    }
  }

  Future<List<ProductCategory>> fetchCategories() async {
    final data = await _get('/products/categories');
    if (data is! List) {
      throw const ProductServiceException(
        'Categories are unavailable. Please try again.',
      );
    }
    return data
        .map(ProductCategory.fromJson)
        .where((c) => c.slug.isNotEmpty)
        .toList();
  }

  void dispose() => _client.close();
}
