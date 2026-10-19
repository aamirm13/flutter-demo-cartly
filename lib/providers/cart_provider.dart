import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  List<CartItem> get items => List.unmodifiable(_items.values);
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  int get subtotalCents =>
      _items.values.fold(0, (sum, item) => sum + item.subtotalCents);
  int get taxCents => (subtotalCents + 5) ~/ 10;
  int get deliveryCents => _items.isEmpty ? 0 : 499;
  int get totalCents => subtotalCents + taxCents + deliveryCents;
  bool add(Product p) {
    if (p.unavailable || (_items[p.id]?.quantity ?? 0) >= 9999) return false;
    _items[p.id] = CartItem(p, (_items[p.id]?.quantity ?? 0) + 1);
    notifyListeners();
    return true;
  }

  bool setQuantity(int id, int quantity) {
    if (quantity < 1 || quantity > 9999 || !_items.containsKey(id)) {
      return false;
    }
    _items[id] = CartItem(_items[id]!.product, quantity);
    notifyListeners();
    return true;
  }

  void increase(int id) => setQuantity(id, (_items[id]?.quantity ?? 0) + 1);
  void decrease(int id) => setQuantity(id, (_items[id]?.quantity ?? 0) - 1);
  void remove(int id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
