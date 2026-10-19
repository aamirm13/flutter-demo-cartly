import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'product_image.dart';

class CartItemTile extends StatefulWidget {
  const CartItemTile({super.key, required this.item});
  final CartItem item;
  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  late final TextEditingController quantity = TextEditingController(
    text: '${widget.item.quantity}',
  );
  final focus = FocusNode();
  String? error;
  @override
  void initState() {
    super.initState();
    focus.addListener(onFocus);
  }

  void onFocus() {
    if (!focus.hasFocus) submit();
  }

  void submit() {
    final value = int.tryParse(quantity.text.trim(), radix: 10);
    final valid =
        value != null &&
        context.read<CartProvider>().setQuantity(widget.item.product.id, value);
    if (mounted) {
      setState(() {
        error = valid ? null : 'Enter 1–9,999';
        quantity.text = '${valid ? value : widget.item.quantity}';
      });
    }
  }

  @override
  void didUpdateWidget(CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.item.quantity != widget.item.quantity;
    if (!focus.hasFocus || changed) {
      quantity.text = '${widget.item.quantity}';
    }
    if (changed) {
      error = null;
    }
  }

  @override
  void dispose() {
    focus.removeListener(onFocus);
    focus.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> remove() async {
    focus.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this find?'),
        content: Text('Remove ${widget.item.product.title} from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep item'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<CartProvider>().remove(widget.item.product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cart = context.read<CartProvider>();
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.mint),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductImage(
                      url: item.product.thumbnail,
                      label: item.product.title,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${usd(item.product.priceCents)} each',
                        style: const TextStyle(color: AppTheme.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Decrease quantity of ${item.product.title}',
                  onPressed: item.quantity <= 1
                      ? null
                      : () {
                          focus.unfocus();
                          FocusManager.instance.applyFocusChangesIfNeeded();
                          cart.decrease(item.product.id);
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: quantity,
                    focusNode: focus,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      focus.unfocus();
                    },
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      errorText: error,
                      errorMaxLines: 2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Increase quantity of ${item.product.title}',
                  onPressed: item.quantity >= 9999
                      ? null
                      : () {
                          focus.unfocus();
                          FocusManager.instance.applyFocusChangesIfNeeded();
                          cart.increase(item.product.id);
                        },
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: 'Remove ${item.product.title}',
                  onPressed: remove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Item subtotal  ${usd(item.subtotalCents)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
