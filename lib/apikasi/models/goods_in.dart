import 'transaction_item.dart';

class GoodsIn {
  final int id;
  final String date;
  final String supplier;
  final String note;
  final List<TransactionItem> items;
  final String status;

  GoodsIn({
    required this.id,
    required this.date,
    required this.supplier,
    required this.note,
    required this.items,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'supplier': supplier,
      'note': note,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status,
    };
  }

  factory GoodsIn.fromJson(Map<String, dynamic> json) {
    return GoodsIn(
      id: json['id'],
      date: json['date'],
      supplier: json['supplier'],
      note: json['note'] ?? '',
      items: (json['items'] as List)
          .map((item) => TransactionItem.fromJson(item))
          .toList(),
      status: json['status'],
    );
  }
}