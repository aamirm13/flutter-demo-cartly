import 'product.dart';

class CartItem {
  const CartItem(this.product, this.quantity);
  final Product product;
  final int quantity;
  int get subtotalCents => product.priceCents * quantity;
}
