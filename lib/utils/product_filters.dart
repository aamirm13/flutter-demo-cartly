import '../models/product.dart';

enum PriceBand {
  all('All prices'),
  under25('Under \$25'),
  from25('\$25–\$100'),
  from100('\$100–\$500'),
  from500('\$500 and above');

  const PriceBand(this.label);
  final String label;
  bool matches(int cents) => switch (this) {
    PriceBand.all => true,
    PriceBand.under25 => cents < 2500,
    PriceBand.from25 => cents >= 2500 && cents < 10000,
    PriceBand.from100 => cents >= 10000 && cents < 50000,
    PriceBand.from500 => cents >= 50000,
  };
}

enum ProductSort {
  featured('Featured'),
  priceAscending('Price: low to high'),
  priceDescending('Price: high to low'),
  rating('Rating: highest first'),
  name('Name: A to Z');

  const ProductSort(this.label);
  final String label;
}

List<Product> filterProducts(
  List<Product> products, {
  String query = '',
  Set<String> categories = const {},
  PriceBand price = PriceBand.all,
  ProductSort sort = ProductSort.featured,
}) {
  final search = query.trim().toLowerCase();
  final result = products
      .where(
        (p) =>
            (search.isEmpty ||
                p.title.toLowerCase().contains(search) ||
                p.description.toLowerCase().contains(search)) &&
            (categories.isEmpty || categories.contains(p.category)) &&
            price.matches(p.priceCents),
      )
      .toList();
  if (sort != ProductSort.featured) {
    result.sort((a, b) {
      final comparison = switch (sort) {
        ProductSort.priceAscending => a.priceCents.compareTo(b.priceCents),
        ProductSort.priceDescending => b.priceCents.compareTo(a.priceCents),
        ProductSort.rating => (b.rating ?? -1).compareTo(a.rating ?? -1),
        ProductSort.name => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _ => 0,
      };
      return comparison == 0 ? a.id.compareTo(b.id) : comparison;
    });
  }
  return result;
}
