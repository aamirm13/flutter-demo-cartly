import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/cart_item_tile.dart';
import '../widgets/status_panel.dart';
import 'order_success_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onShop});
  final VoidCallback onShop;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: cart.items.isEmpty
            ? SingleChildScrollView(
                child: StatusPanel(
                  icon: Icons.shopping_bag_outlined,
                  title: 'A little room for something good',
                  message:
                      'Your cart is empty. Discover a few everyday favourites.',
                  action: 'Continue Shopping',
                  onAction: onShop,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Your good finds.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('${cart.itemCount} items in your bag'),
                  const SizedBox(height: 24),
                  ...cart.items.map(
                    (item) => CartItemTile(
                      key: ValueKey(item.product.id),
                      item: item,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Order summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _row('Merchandise subtotal', cart.subtotalCents),
                  _row('Demo tax (illustrative 10%)', cart.taxCents),
                  _row('Demo delivery (illustrative)', cart.deliveryCents),
                  const Divider(height: 32),
                  _row('Estimated total', cart.totalCents, bold: true),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      // Commit pending field edits before snapshotting checkout totals.
                      FocusManager.instance.applyFocusChangesIfNeeded();
                      if (cart.items.isEmpty) return;
                      final count = cart.itemCount, total = cart.totalCents;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderSuccessScreen(
                            itemCount: count,
                            totalCents: total,
                            onShop: onShop,
                          ),
                        ),
                      );
                      cart.clear();
                    },
                    child: const Text('Demo Checkout'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Just a demonstration. No payment details, real orders or real charges.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _row(String label, int cents, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          usd(cents),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            fontSize: bold ? 22 : 15,
          ),
        ),
      ],
    ),
  );
}
