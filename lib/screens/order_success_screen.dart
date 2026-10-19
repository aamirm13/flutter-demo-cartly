import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.itemCount,
    required this.totalCents,
    required this.onShop,
  });
  final int itemCount, totalCents;
  final VoidCallback onShop;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('cartly.')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 52,
                  backgroundColor: AppTheme.mint,
                  child: Icon(
                    Icons.check_rounded,
                    color: AppTheme.emerald,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'A great find.\nA complete demo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Demo checkout complete',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emerald,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No real order was placed and no payment was processed. Your demo cart has been cleared.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  '$itemCount items · ${usd(totalCents)} illustrative total',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    onShop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
