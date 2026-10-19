import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/cart_shortcut.dart';
import '../widgets/product_image.dart';
import '../widgets/status_panel.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.service,
    required this.onCart,
  });
  final int productId;
  final ProductService service;
  final VoidCallback onCart;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? product;
  String? error;
  int imageIndex = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final p = await widget.service.fetchProduct(widget.productId);
      if (mounted) setState(() => product = p);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ProductServiceException
              ? e.message
              : 'Unable to load this product. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'cartly.',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        actions: [
          CartShortcut(
            onPressed: () {
              widget.onCart();
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: p == null
            ? error == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: StatusPanel(
                        icon: Icons.cloud_off_outlined,
                        title: 'This find is taking a moment',
                        message: error!,
                        action: 'Retry',
                        onAction: load,
                      ),
                    )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: p.gallery.isEmpty
                              ? const ProductImage()
                              : PageView.builder(
                                  itemCount: p.gallery.length,
                                  onPageChanged: (i) =>
                                      setState(() => imageIndex = i),
                                  itemBuilder: (_, i) => ProductImage(
                                    url: p.gallery[i],
                                    label:
                                        '${p.title}, image ${i + 1} of ${p.gallery.length}',
                                  ),
                                ),
                        ),
                      ),
                      if (p.gallery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${imageIndex + 1} / ${p.gallery.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.slate),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        categoryLabel(p.category).toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.emerald,
                          letterSpacing: 1.4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '★ ${p.rating?.toStringAsFixed(2) ?? 'Not rated'}${p.rating == null ? '' : ' / 5'}',
                        semanticsLabel: p.rating == null
                            ? 'Not rated'
                            : 'Rating ${p.rating} out of 5',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            usd(p.priceCents),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.emerald,
                            ),
                          ),
                          if (p.hasDiscount)
                            Chip(
                              label: Text(
                                '${p.discountPercentage.toStringAsFixed(2)}% discount',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        p.description.isEmpty
                            ? 'No description provided.'
                            : p.description,
                      ),
                      const SizedBox(height: 24),
                      if (p.brand != null) _fact('Brand', p.brand!),
                      _fact(
                        'Category',
                        p.category.isEmpty
                            ? 'Not provided'
                            : categoryLabel(p.category),
                      ),
                      _fact('Availability', p.availability),
                      if (p.stock != null)
                        _fact('Sample stock', '${p.stock} units'),
                      const SizedBox(height: 8),
                      const Text(
                        'Availability is sample API data, not live inventory.',
                        style: TextStyle(color: AppTheme.slate, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      if (p.shippingInformation != null)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: const Text('Shipping information'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(p.shippingInformation!),
                              ),
                            ),
                          ],
                        ),
                      if (p.returnPolicy != null)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(Icons.assignment_return_outlined),
                          title: const Text('Returns'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(p.returnPolicy!),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: p == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton.icon(
                  onPressed: p.unavailable
                      ? null
                      : () {
                          final added = context.read<CartProvider>().add(p);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added
                                    ? '${p.title} added to your cart'
                                    : 'Quantity limit reached (9,999).',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(p.unavailable ? 'Out of stock' : 'Add to Cart'),
                ),
              ),
            ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.slate)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
