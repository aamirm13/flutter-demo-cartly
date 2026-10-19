import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 24),
    elevation: 0,
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.mint),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.18,
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: ProductImage(
                    url: product.thumbnail,
                    label: product.title,
                  ),
                ),
              ),
              if (product.hasDiscount)
                Positioned(
                  top: 16,
                  left: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '${product.discountPercentage.toStringAsFixed(2)}% discount',
                        style: const TextStyle(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryLabel(product.category).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.slate,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text(
                      usd(product.priceCents),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emerald,
                      ),
                    ),
                    Text(
                      '★ ${product.rating?.toStringAsFixed(2) ?? 'Not rated'}',
                      semanticsLabel: product.rating == null
                          ? 'Not rated'
                          : 'Rating ${product.rating} out of 5',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
