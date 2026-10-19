import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_page.dart';
import '../services/product_service.dart';
import '../utils/product_filters.dart';

// Screen-owned state: the cart is the only application-level ChangeNotifier.
class CatalogueController extends ChangeNotifier {
  CatalogueController(this.service);
  final ProductService service;
  final List<Product> _pages = [];
  final Map<int, Future<ProductPage>> _pageRequests = {};
  List<Product>? _all;
  List<Product> _matching = [];
  int _skip = 0, _total = 0, _visible = 20, _generation = 0;
  bool _disposed = false;
  bool loading = false, loadingMore = false;
  String? error, pageError;
  String query = '';
  Set<String> categories = {};
  PriceBand price = PriceBand.all;
  ProductSort sort = ProductSort.featured;
  bool get isGlobal =>
      query.trim().isNotEmpty ||
      categories.isNotEmpty ||
      price != PriceBand.all ||
      sort != ProductSort.featured;
  List<Product> get products =>
      isGlobal ? _matching.take(_visible).toList() : List.unmodifiable(_pages);
  int get resultCount => isGlobal ? _matching.length : _total;
  bool get hasMore => isGlobal ? _visible < _matching.length : _skip < _total;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<ProductPage> _fetchPage(int skip) => _pageRequests.putIfAbsent(
    skip,
    () => service.fetchProducts(skip: skip).whenComplete(() {
      _pageRequests.remove(skip);
    }),
  );

  Future<void> refresh() async {
    final version = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    pageError = null;
    _visible = 20;
    _emit();
    try {
      if (isGlobal) {
        _all ??= await service.fetchAll();
        if (_disposed || version != _generation) return;
        _matching = filterProducts(
          _all!,
          query: query,
          categories: categories,
          price: price,
          sort: sort,
        );
      } else if (_pages.isEmpty) {
        final page = await _fetchPage(0);
        if (_disposed || version != _generation) return;
        _pages.addAll({for (final p in page.products) p.id: p}.values);
        _skip = page.products.length;
        _total = page.products.isEmpty ? 0 : page.total;
      }
    } catch (e) {
      if (version == _generation) {
        error = e is ProductServiceException
            ? e.message
            : 'Unable to load products. Please try again.';
      }
    } finally {
      if (version == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || pageError != null) return;
    if (isGlobal) {
      _visible += 20;
      _emit();
      return;
    }
    final version = _generation;
    loadingMore = true;
    _emit();
    try {
      final page = await _fetchPage(_skip);
      if (_disposed || version != _generation) return;
      final ids = _pages.map((p) => p.id).toSet();
      _pages.addAll(page.products.where((p) => ids.add(p.id)));
      _skip += page.products.length;
      _total = page.products.isEmpty ? _skip : page.total;
    } catch (e) {
      if (version == _generation) {
        pageError = e is ProductServiceException
            ? e.message
            : 'Unable to load more products.';
      }
    } finally {
      if (version == _generation) {
        loadingMore = false;
        _emit();
      }
    }
  }

  void retryMore() {
    pageError = null;
    loadMore();
  }

  void reset() {
    query = '';
    categories = {};
    price = PriceBand.all;
    sort = ProductSort.featured;
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
