import 'transaction_item.dart';

class GoodsOut {
  final int id;
  final String date;
  final String recipient;
  final String note;
  final List<TransactionItem> items;
  final String status;

  GoodsOut({
    required this.id,
    required this.date,
    required this.recipient,
    required this.note,
    required this.items,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'recipient': recipient,
      'note': note,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status,
    };
  }

  factory GoodsOut.fromJson(Map<String, dynamic> json) {
    return GoodsOut(
      id: json['id'],
      date: json['date'],
      recipient: json['recipient'],
      note: json['note'] ?? '',
      items: (json['items'] as List)
          .map((item) => TransactionItem.fromJson(item))
          .toList(),
      status: json['status'],
    );
  }
}