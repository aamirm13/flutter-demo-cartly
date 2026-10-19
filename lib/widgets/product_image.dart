import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.url,
    this.label = 'Product image',
    this.fit = BoxFit.contain,
  });
  final String? url;
  final String label;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Semantics(
        label: 'Image unavailable',
        child: const Icon(
          Icons.image_outlined,
          size: 48,
          color: AppTheme.slate,
        ),
      ),
    );
    return ColoredBox(
      color: const Color(0xFFF0F4F1),
      child: url == null || url!.isEmpty
          ? placeholder
          : Image.network(
              url!,
              fit: fit,
              semanticLabel: label,
              cacheWidth: 900,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
    );
  }
}
