double? _finiteNumber(Object? value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  return n != null && n.isFinite ? n : null;
}

double number(Object? value, [double fallback = 0]) =>
    _finiteNumber(value) ?? fallback;

String? optionalText(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;
String categoryLabel(String slug) => slug
    .split('-')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    this.description = '',
    this.category = '',
    this.discountPercentage = 0,
    this.rating,
    this.stock,
    this.brand,
    this.thumbnail,
    this.images = const [],
    this.availabilityStatus,
    this.shippingInformation,
    this.returnPolicy,
  });
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: number(j['id']).toInt(),
    title: optionalText(j['title']) ?? 'Untitled product',
    price: number(j['price']).clamp(0, double.maxFinite),
    description: optionalText(j['description']) ?? '',
    category: optionalText(j['category']) ?? '',
    discountPercentage: number(j['discountPercentage']),
    rating: _finiteNumber(j['rating'])?.clamp(0, 5),
    stock: _finiteNumber(j['stock'])?.toInt(),
    brand: optionalText(j['brand']),
    thumbnail: optionalText(j['thumbnail']),
    images: j['images'] is List
        ? (j['images'] as List)
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList()
        : const [],
    availabilityStatus: optionalText(j['availabilityStatus']),
    shippingInformation: optionalText(j['shippingInformation']),
    returnPolicy: optionalText(j['returnPolicy']),
  );
  final int id;
  final String title, description, category;
  final double price, discountPercentage;
  final double? rating;
  final int? stock;
  final String? brand,
      thumbnail,
      availabilityStatus,
      shippingInformation,
      returnPolicy;
  final List<String> images;
  int get priceCents => (price * 100).round();
  bool get unavailable =>
      (stock != null && stock! <= 0) ||
      availabilityStatus?.toLowerCase() == 'out of stock';
  // API low-stock status or a fallback threshold of five units.
  String get availability => unavailable
      ? 'Out of stock'
      : availabilityStatus?.toLowerCase() == 'low stock' ||
            (stock != null && stock! <= 5)
      ? 'Low stock'
      : stock != null || availabilityStatus?.toLowerCase() == 'in stock'
      ? 'In stock'
      : 'Availability not provided';
  bool get hasDiscount => discountPercentage > 0 && discountPercentage < 100;
  List<String> get gallery => images.isNotEmpty ? images : [?thumbnail];
}

class ProductCategory {
  const ProductCategory(this.slug, this.name);
  final String slug, name;
  factory ProductCategory.fromJson(Object? v) {
    if (v is String) return ProductCategory(v, categoryLabel(v));
    if (v is Map) {
      final s = optionalText(v['slug']) ?? '';
      return ProductCategory(s, optionalText(v['name']) ?? categoryLabel(s));
    }
    return const ProductCategory('', '');
  }
}
