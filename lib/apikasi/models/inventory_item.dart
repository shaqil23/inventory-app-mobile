class InventoryItem {
  final int id;
  final String name;
  final String category;
  int stock;
  final String unit;
  int price;
  String lastUpdate;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.unit,
    required this.price,
    required this.lastUpdate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'stock': stock,
      'unit': unit,
      'price': price,
      'lastUpdate': lastUpdate,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      stock: json['stock'],
      unit: json['unit'],
      price: json['price'] ?? 0,
      lastUpdate: json['lastUpdate'],
    );
  }
}