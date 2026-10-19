import 'product.dart';

class ProductPage {
  const ProductPage(this.products, this.total);
  final List<Product> products;
  final int total;
  factory ProductPage.fromJson(Map<String, dynamic> j) {
    if (j['products'] is! List) throw const FormatException('Missing products');
    final products = (j['products'] as List)
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList();
    return ProductPage(
      products,
      number(j['total'], products.length.toDouble()).toInt(),
    );
  }
}
