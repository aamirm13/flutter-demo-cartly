import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';

class CartShortcut extends StatelessWidget {
  const CartShortcut({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Selector<CartProvider, int>(
    selector: (_, cart) => cart.itemCount,
    builder: (_, count, _) => IconButton(
      tooltip: 'Open cart, $count items',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    ),
  );
}
