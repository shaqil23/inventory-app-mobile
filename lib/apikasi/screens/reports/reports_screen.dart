// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/management/inventory_provider.dart';
import '../../providers/management/goods_in_provider.dart';
import '../../providers/management/goods_out_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInit = true;
  bool _isLoading = false;
  String _selectedPeriod = 'week';

  // Report data
  List<Map<String, dynamic>> _topItems = [];
  Map<String, dynamic> _inventorySummary = {
    'totalItems': 0,
    'lowStock': 0,
    'totalValue': 'Rp 0',
  };
  Map<String, dynamic> _transactionSummary = {
    'goodsIn': {'count': 0, 'value': 'Rp 0'},
    'goodsOut': {'count': 0, 'value': 'Rp 0'},
  };

  List<dynamic> _goodsInTransactions = [];
  List<dynamic> _goodsOutTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });

      // Load all data
      Provider.of<InventoryProvider>(context).fetchAndSetInventory().then((_) {
        Provider.of<GoodsInProvider>(context)
            .fetchAndSetTransactions()
            .then((_) {
          Provider.of<GoodsOutProvider>(context)
              .fetchAndSetTransactions()
              .then((_) {
            // Generate report with default period
            _generateReport(_selectedPeriod);
            setState(() {
              _isLoading = false;
            });
          });
        });
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  void _generateReport(String period) {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final goodsInProvider =
        Provider.of<GoodsInProvider>(context, listen: false);
    final goodsOutProvider =
        Provider.of<GoodsOutProvider>(context, listen: false);

    // Get inventory data
    final inventory = inventoryProvider.items;

    // Filter transactions based on period
    final DateTime today = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'today':
        startDate = DateTime(today.year, today.month, today.day);
        break;
      case 'week':
        startDate = today.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(today.year, today.month - 1, today.day);
        break;
      case 'year':
        startDate = DateTime(today.year - 1, today.month, today.day);
        break;
      default:
        startDate = today.subtract(const Duration(days: 7));
    }

    // Filter transactions
    final filteredGoodsIn =
        goodsInProvider.getTransactionsByDateRange(startDate, today);
    final filteredGoodsOut =
        goodsOutProvider.getTransactionsByDateRange(startDate, today);

    // Set filtered transactions for detailed view
    _goodsInTransactions = filteredGoodsIn;
    _goodsOutTransactions = filteredGoodsOut;

    // Calculate top items (most frequently used in goods-out)
    Map<String, Map<String, dynamic>> itemUsage = {};

    for (var transaction in filteredGoodsOut) {
      for (var item in transaction.items) {
        if (!itemUsage.containsKey(item.product)) {
          itemUsage[item.product] = {
            'quantity': 0,
            'unit': item.unit,
          };
        }
        itemUsage[item.product]!['quantity'] += item.quantity;
      }
    }

    // Convert to list and sort
    List<Map<String, dynamic>> topItems = itemUsage.entries.map((entry) {
      return {
        'name': entry.key,
        'quantity': entry.value['quantity'],
        'unit': entry.value['unit'],
      };
    }).toList();

    // Sort by quantity (descending) and take top 5
    topItems
        .sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
    _topItems = topItems.take(5).toList();

    // Calculate inventory summary
    const lowStockThreshold = 10;
    final lowStockItems =
        inventory.where((item) => item.stock <= lowStockThreshold).toList();

    // Calculate total inventory value
    final totalValue = inventory.fold(
      0,
      (sum, item) => sum + (item.stock * item.price),
    );

    _inventorySummary = {
      'totalItems': inventory.length,
      'lowStock': lowStockItems.length,
      'totalValue': CurrencyFormatter.format(totalValue),
    };

    // Calculate transaction summary
    final goodsInValue = filteredGoodsIn.fold(
      0,
      (sum, transaction) =>
          sum +
          transaction.items.fold(
            0,
            (itemSum, item) => itemSum + (item.quantity * item.price),
          ),
    );

    final goodsOutValue = filteredGoodsOut.fold(
      0,
      (sum, transaction) =>
          sum +
          transaction.items.fold(
            0,
            (itemSum, item) => itemSum + (item.quantity * item.price),
          ),
    );

    _transactionSummary = {
      'goodsIn': {
        'count': filteredGoodsIn.length,
        'value': CurrencyFormatter.format(goodsInValue),
      },
      'goodsOut': {
        'count': filteredGoodsOut.length,
        'value': CurrencyFormatter.format(goodsOutValue),
      },
    };

    setState(() {
      _selectedPeriod = period;
    });
  }

  Future<void> _downloadReport() async {
    try {
      // Create PDF document
      final pdf = pw.Document();

      // Period labels for display
      final Map<String, String> periodLabels = {
        'today': 'Hari Ini',
        'week': 'Minggu Ini',
        'month': 'Bulan Ini',
        'year': 'Tahun Ini',
      };

      // Add content to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'LAPORAN INVENTARIS KOMBY BENTO',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Periode: ${periodLabels[_selectedPeriod]} | Tanggal Cetak: ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(),
              ],
            ),
          ),
          build: (context) => [
            // Inventory Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RINGKASAN INVENTARIS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      // Stock Info
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Informasi Stok',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                  'Total Item: ${_inventorySummary['totalItems']}'),
                              pw.Text(
                                  'Stok Menipis: ${_inventorySummary['lowStock']}'),
                              pw.Text(
                                  'Nilai Total: ${_inventorySummary['totalValue']}'),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      // Transaction Info
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Informasi Transaksi',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                'Barang Masuk: ${_transactionSummary['goodsIn']['count']} transaksi (${_transactionSummary['goodsIn']['value']})',
                              ),
                              pw.Text(
                                'Barang Keluar: ${_transactionSummary['goodsOut']['count']} transaksi (${_transactionSummary['goodsOut']['value']})',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  // Top Items
                  pw.Text(
                    'Item Terlaris',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      // Header
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'No',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Nama Barang',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Jumlah',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      // Items
                      ..._topItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('${index + 1}'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(item['name']),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  '${item['quantity']} ${item['unit']}'),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Goods In Transactions
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DETAIL TRANSAKSI BARANG MASUK',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _goodsInTransactions.isEmpty
                      ? pw.Center(
                          child: pw.Text(
                            'Tidak ada transaksi barang masuk untuk periode ini',
                            style: pw.TextStyle(
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey,
                            ),
                          ),
                        )
                      : pw.Column(
                          children: _goodsInTransactions.map((transaction) {
                            // Calculate transaction total
                            final total = transaction.items.fold(
                              0,
                              (sum, item) => sum + (item.quantity * item.price),
                            );

                            return pw.Container(
                              margin: const pw.EdgeInsets.only(bottom: 16),
                              padding: const pw.EdgeInsets.only(bottom: 16),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom:
                                      pw.BorderSide(color: PdfColors.grey300),
                                ),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        'Tanggal: ${DateFormatter.formatDate(transaction.date)}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold),
                                      ),
                                      pw.Text(
                                        'Pemasok: ${transaction.supplier}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (transaction.note.isNotEmpty) ...[
                                    pw.SizedBox(height: 4),
                                    pw.Text('Catatan: ${transaction.note}'),
                                  ],
                                  pw.SizedBox(height: 8),
                                  pw.Table(
                                    border: pw.TableBorder.all(
                                        color: PdfColors.grey300),
                                    children: [
                                      // Header
                                      pw.TableRow(
                                        decoration: const pw.BoxDecoration(
                                            color: PdfColors.grey200),
                                        children: [
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Barang',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Jumlah',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Harga',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Subtotal',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Items
                                      ...transaction.items.map((item) {
                                        final subtotal =
                                            item.quantity * item.price;
                                        return pw.TableRow(
                                          children: [
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(item.product),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  '${item.quantity} ${item.unit}'),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  'Rp ${NumberFormat('#,###', 'id_ID').format(item.price)}'),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  'Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}'),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                      // Total
                                      pw.TableRow(
                                        decoration: const pw.BoxDecoration(
                                            color: PdfColors.grey100),
                                        children: [
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Container(),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Container(),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Total:',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Rp ${NumberFormat('#,###', 'id_ID').format(total)}',
                                              style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                color: PdfColors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Goods Out Transactions
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DETAIL TRANSAKSI BARANG KELUAR',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _goodsOutTransactions.isEmpty
                      ? pw.Center(
                          child: pw.Text(
                            'Tidak ada transaksi barang keluar untuk periode ini',
                            style: pw.TextStyle(
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey,
                            ),
                          ),
                        )
                      : pw.Column(
                          children: _goodsOutTransactions.map((transaction) {
                            // Calculate transaction total
                            final total = transaction.items.fold(
                              0,
                              (sum, item) => sum + (item.quantity * item.price),
                            );

                            return pw.Container(
                              margin: const pw.EdgeInsets.only(bottom: 16),
                              padding: const pw.EdgeInsets.only(bottom: 16),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom:
                                      pw.BorderSide(color: PdfColors.grey300),
                                ),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        'Tanggal: ${DateFormatter.formatDate(transaction.date)}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold),
                                      ),
                                      pw.Text(
                                        'Penerima: ${transaction.recipient}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  if (transaction.note.isNotEmpty) ...[
                                    pw.SizedBox(height: 4),
                                    pw.Text('Catatan: ${transaction.note}'),
                                  ],
                                  pw.SizedBox(height: 8),
                                  pw.Table(
                                    border: pw.TableBorder.all(
                                        color: PdfColors.grey300),
                                    children: [
                                      // Header
                                      pw.TableRow(
                                        decoration: const pw.BoxDecoration(
                                            color: PdfColors.grey200),
                                        children: [
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Barang',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Jumlah',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Harga',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Subtotal',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Items
                                      ...transaction.items.map((item) {
                                        final subtotal =
                                            item.quantity * item.price;
                                        return pw.TableRow(
                                          children: [
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(item.product),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  '${item.quantity} ${item.unit}'),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  'Rp ${NumberFormat('#,###', 'id_ID').format(item.price)}'),
                                            ),
                                            pw.Padding(
                                              padding:
                                                  const pw.EdgeInsets.all(8),
                                              child: pw.Text(
                                                  'Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}'),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                      // Total
                                      pw.TableRow(
                                        decoration: const pw.BoxDecoration(
                                            color: PdfColors.grey100),
                                        children: [
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Container(),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Container(),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Total:',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold),
                                            ),
                                          ),
                                          pw.Padding(
                                            padding: const pw.EdgeInsets.all(8),
                                            child: pw.Text(
                                              'Rp ${NumberFormat('#,###', 'id_ID').format(total)}',
                                              style: pw.TextStyle(
                                                fontWeight: pw.FontWeight.bold,
                                                color: PdfColors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ],
          footer: (context) => pw.Center(
            child: pw.Text(
              '© ${DateTime.now().year} Komby Bento. Laporan dibuat pada ${DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey,
              ),
            ),
          ),
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/laporan-komby-bento-$_selectedPeriod-${DateTime.now().toIso8601String().split('T')[0]}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Show preview and print options
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'laporan-komby-bento-$_selectedPeriod-${DateTime.now().toIso8601String().split('T')[0]}.pdf',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan berhasil diunduh'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh laporan: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.trending_up),
            SizedBox(width: 8),
            Text('Laporan'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Barang Masuk'),
            Tab(text: 'Barang Keluar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Period Selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Periode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'today',
                        child: Text('Hari Ini'),
                      ),
                      DropdownMenuItem(
                        value: 'week',
                        child: Text('Minggu Ini'),
                      ),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('Bulan Ini'),
                      ),
                      DropdownMenuItem(
                        value: 'year',
                        child: Text('Tahun Ini'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _generateReport(value);
                      }
                    },
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Summary Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    context,
                                    Icons.inventory,
                                    'Total Item',
                                    _inventorySummary['totalItems'].toString(),
                                    '${_inventorySummary['lowStock']} stok menipis',
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildSummaryCard(
                                    context,
                                    Icons.bar_chart,
                                    'Nilai Inventaris',
                                    _inventorySummary['totalValue'],
                                    'Nilai total barang',
                                    Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Transaction Summary
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ringkasan Transaksi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.login,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Barang Masuk',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${_transactionSummary['goodsIn']['count']} transaksi',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      _transactionSummary[
                                                          'goodsIn']['value'],
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black87,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.logout,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Barang Keluar',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${_transactionSummary['goodsOut']['count']} transaksi',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      _transactionSummary[
                                                          'goodsOut']['value'],
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .secondary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Top Items
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Item Terlaris',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _topItems.isEmpty
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: Text(
                                                'Tidak ada data untuk periode yang dipilih',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Column(
                                            children: _topItems
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final index = entry.key;
                                              final item = entry.value;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .secondary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(item['name']),
                                                    ),
                                                    Text(
                                                      '${item['quantity']} ${item['unit']}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Goods In Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.login,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Detail Transaksi Barang Masuk',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _goodsInTransactions.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32.0),
                                          child: Text(
                                            'Tidak ada transaksi barang masuk untuk periode ini',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: _goodsInTransactions
                                            .map((transaction) {
                                          // Calculate transaction total
                                          final total = transaction.items.fold(
                                            0,
                                            (sum, item) =>
                                                sum +
                                                (item.quantity * item.price),
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 24),
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey[300]!,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Transaction header
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.calendar_today,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          DateFormatter
                                                              .formatDate(
                                                                  transaction
                                                                      .date),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.person,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(transaction
                                                            .supplier),
                                                      ],
                                                    ),
                                                  ],
                                                ),

                                                if (transaction
                                                    .note.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.description,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          transaction.note,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[700],
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],

                                                const SizedBox(height: 12),

                                                // Items table
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                    children: [
                                                      // Table header
                                                      const Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              'Barang',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Jumlah',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Harga',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Subtotal',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const Divider(),

                                                      // Table rows
                                                      ...transaction.items
                                                          .map((item) {
                                                        final subtotal =
                                                            item.quantity *
                                                                item.price;
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      4.0),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(item
                                                                    .product),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  '${item.quantity} ${item.unit}',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  CurrencyFormatter
                                                                      .format(item
                                                                          .price),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  CurrencyFormatter
                                                                      .format(
                                                                          subtotal),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),

                                                      const Divider(),

                                                      // Total row
                                                      Row(
                                                        children: [
                                                          const Expanded(
                                                            flex: 7,
                                                            child: Text(
                                                              'Total:',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              CurrencyFormatter
                                                                  .format(
                                                                      total),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .secondary,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Goods Out Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      color: Colors.black87,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Detail Transaksi Barang Keluar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _goodsOutTransactions.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32.0),
                                          child: Text(
                                            'Tidak ada transaksi barang keluar untuk periode ini',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: _goodsOutTransactions
                                            .map((transaction) {
                                          // Calculate transaction total
                                          final total = transaction.items.fold(
                                            0,
                                            (sum, item) =>
                                                sum +
                                                (item.quantity * item.price),
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 24),
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey[300]!,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Transaction header
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.calendar_today,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          DateFormatter
                                                              .formatDate(
                                                                  transaction
                                                                      .date),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.person,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(transaction
                                                            .recipient),
                                                      ],
                                                    ),
                                                  ],
                                                ),

                                                if (transaction
                                                    .note.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.description,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          transaction.note,
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[700],
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],

                                                const SizedBox(height: 12),

                                                // Items table
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                    children: [
                                                      // Table header
                                                      const Row(
                                                        children: [
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              'Barang',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Jumlah',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Harga',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              'Subtotal',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const Divider(),

                                                      // Table rows
                                                      ...transaction.items
                                                          .map((item) {
                                                        final subtotal =
                                                            item.quantity *
                                                                item.price;
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical:
                                                                      4.0),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 3,
                                                                child: Text(item
                                                                    .product),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  '${item.quantity} ${item.unit}',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  CurrencyFormatter
                                                                      .format(item
                                                                          .price),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Text(
                                                                  CurrencyFormatter
                                                                      .format(
                                                                          subtotal),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .right,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),

                                                      const Divider(),

                                                      // Total row
                                                      Row(
                                                        children: [
                                                          const Expanded(
                                                            flex: 7,
                                                            child: Text(
                                                              'Total:',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              CurrencyFormatter
                                                                  .format(
                                                                      total),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .secondary,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .right,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Download Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Unduh Laporan'),
                    onPressed: _downloadReport,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 0),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    IconData icon,
    String title,
    String value,
    String subtitle,
    Color iconColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
