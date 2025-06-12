class TransactionItem {
  final String product;
  final int quantity;
  final String unit;
  final int price;

  TransactionItem({
    required this.product,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'product': product,
      'quantity': quantity,
      'unit': unit,
      'price': price,
    };
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      product: json['product'],
      quantity: json['quantity'],
      unit: json['unit'],
      price: json['price'] ?? 0,
    );
  }
}