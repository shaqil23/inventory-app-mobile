// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/management/goods_in_provider.dart';
import '../../utils/date_formatter.dart';
import '../../utils/currency_formatter.dart';

class GoodsInDetailScreen extends StatelessWidget {
  final int transactionId;

  const GoodsInDetailScreen(this.transactionId, {super.key});

  @override
  Widget build(BuildContext context) {
    final goodsInProvider =
        Provider.of<GoodsInProvider>(context, listen: false);

    try {
      final transaction = goodsInProvider.findById(transactionId);

      // Calculate total value
      final totalValue = transaction.items.fold(
        0,
        (sum, item) => sum + (item.quantity * item.price),
      );

      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Transaksi'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Barang Masuk #${transaction.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        Icons.calendar_today,
                        'Tanggal',
                        DateFormatter.formatDateWithDay(transaction.date),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.person,
                        'Pemasok',
                        transaction.supplier,
                      ),
                      if (transaction.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          Icons.description,
                          'Catatan',
                          transaction.note,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        null,
                        'Nilai Total',
                        CurrencyFormatter.format(totalValue),
                        valueColor: Theme.of(context).colorScheme.secondary,
                        valueBold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Barang',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Barang')),
                            DataColumn(
                              label: Text('Jumlah'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Harga'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('Subtotal'),
                              numeric: true,
                            ),
                          ],
                          rows: [
                            ...transaction.items.map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(Text(
                                    item.product,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  )),
                                  DataCell(
                                      Text('${item.quantity} ${item.unit}')),
                                  DataCell(Text(
                                      CurrencyFormatter.format(item.price))),
                                  DataCell(Text(
                                    CurrencyFormatter.format(
                                        item.quantity * item.price),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            // Total Row
                            DataRow(
                              cells: [
                                DataCell(Container()),
                                DataCell(Container()),
                                const DataCell(Text(
                                  'Total:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                )),
                                DataCell(Text(
                                  CurrencyFormatter.format(totalValue),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Back Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Kembali ke Barang Masuk'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      // Transaction not found
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Transaksi'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Transaksi tidak ditemukan'),
        ),
      );
    }
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData? icon,
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: Colors.grey,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
