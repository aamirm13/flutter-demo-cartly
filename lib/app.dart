import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cart_provider.dart';
import 'services/product_service.dart';
import 'screens/catalogue_screen.dart';
import 'screens/cart_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/cart_shortcut.dart';

class CartlyApp extends StatefulWidget {
  const CartlyApp({super.key, this.service});
  final ProductService? service;
  @override
  State<CartlyApp> createState() => _CartlyAppState();
}

class _CartlyAppState extends State<CartlyApp> {
  late final ProductService service = widget.service ?? ProductService();
  @override
  void dispose() {
    if (widget.service == null) service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CartProvider(),
    child: MaterialApp(
      title: 'Cartly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: ShopShell(service: service),
    ),
  );
}

class ShopShell extends StatefulWidget {
  const ShopShell({super.key, required this.service});
  final ProductService service;
  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int index = 0;
  void select(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => index = value);
  }

  void shop() => select(0);
  void cart() => select(1);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'cartly.',
        style: TextStyle(
          fontSize: 30,
          letterSpacing: -1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        CartShortcut(onPressed: cart),
        const SizedBox(width: 12),
      ],
    ),
    body: SafeArea(
      top: false,
      child: IndexedStack(
        index: index,
        children: [
          CatalogueScreen(service: widget.service, onCart: cart),
          CartScreen(onShop: shop),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Shop',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'Cart',
        ),
      ],
    ),
  );
}
