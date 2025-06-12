// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/management/inventory_provider.dart';
import '../../providers/management/goods_out_provider.dart';
import '../../models/goods_out.dart';
import '../../models/transaction_item.dart';
import '../../utils/currency_formatter.dart';

class AddGoodsOutScreen extends StatefulWidget {
  const AddGoodsOutScreen({super.key});

  @override
  _AddGoodsOutScreenState createState() => _AddGoodsOutScreenState();
}

class _AddGoodsOutScreenState extends State<AddGoodsOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _recipientController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isInit = true;
  bool _isLoading = false;
  final Map<String, String> _errors = {};

  final List<Map<String, dynamic>> _items = [
    {
      'product': '',
      'quantity': '',
      'unit': '',
      'available': 0,
      'price': 0,
    }
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });
      Provider.of<InventoryProvider>(context).fetchAndSetInventory().then((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _recipientController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add({
        'product': '',
        'quantity': '',
        'unit': '',
        'available': 0,
        'price': 0,
      });
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        // Remove any errors for this item
        _errors.remove('quantity-$index');
      });
    }
  }

  void _updateItemProduct(int index, String productName) {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final selectedProduct = inventoryProvider.items.firstWhere(
      (item) => item.name == productName,
      orElse: () => throw Exception('Product not found'),
    );

    setState(() {
      _items[index]['product'] = productName;
      _items[index]['unit'] = selectedProduct.unit;
      _items[index]['available'] = selectedProduct.stock;
      _items[index]['price'] = selectedProduct.price;

      // Clear any existing quantity errors when product changes
      _errors.remove('quantity-$index');
    });
  }

  void _updateItemQuantity(int index, String value) {
    setState(() {
      _items[index]['quantity'] = value;

      // Validate quantity
      if (value.isEmpty) {
        _errors['quantity-$index'] = 'Jumlah harus diisi';
      } else {
        final quantity = int.tryParse(value);
        if (quantity == null || quantity <= 0) {
          _errors['quantity-$index'] = 'Jumlah harus lebih dari 0';
        } else if (quantity > _items[index]['available']) {
          _errors['quantity-$index'] =
              'Melebihi stok yang tersedia (${_items[index]['available']})';
        } else {
          _errors.remove('quantity-$index');
        }
      }
    });
  }

  Future<void> saveForm() async {
    // Validate form
    if (_recipientController.text.isEmpty) {
      setState(() {
        _errors['recipient'] = 'Penerima harus diisi';
      });
      return;
    } else {
      setState(() {
        _errors.remove('recipient');
      });
    }

    // Validate items
    bool hasItemErrors = false;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i]['product'].isEmpty) {
        setState(() {
          _errors['product-$i'] = 'Barang harus dipilih';
        });
        hasItemErrors = true;
      } else {
        setState(() {
          _errors.remove('product-$i');
        });
      }

      if (_items[i]['quantity'].isEmpty) {
        setState(() {
          _errors['quantity-$i'] = 'Jumlah harus diisi';
        });
        hasItemErrors = true;
      } else {
        final quantity = int.tryParse(_items[i]['quantity']);
        if (quantity == null || quantity <= 0) {
          setState(() {
            _errors['quantity-$i'] = 'Jumlah harus lebih dari 0';
          });
          hasItemErrors = true;
        } else if (quantity > _items[i]['available']) {
          setState(() {
            _errors['quantity-$i'] =
                'Melebihi stok yang tersedia (${_items[i]['available']})';
          });
          hasItemErrors = true;
        } else {
          setState(() {
            _errors.remove('quantity-$i');
          });
        }
      }
    }

    if (_errors.isNotEmpty || hasItemErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap perbaiki kesalahan sebelum mengirimkan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final goodsOutProvider =
          Provider.of<GoodsOutProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      // Create transaction items
      final transactionItems = _items.map((item) {
        return TransactionItem(
          product: item['product'],
          quantity: int.parse(item['quantity']),
          unit: item['unit'],
          price: item['price'],
        );
      }).toList();

      // Create new transaction
      final newTransaction = GoodsOut(
        id: goodsOutProvider.getNextId(),
        date: _dateController.text,
        recipient: _recipientController.text,
        note: _noteController.text,
        items: transactionItems,
        status: 'completed',
      );

      // Add transaction
      await goodsOutProvider.addTransaction(newTransaction);

      // Update inventory quantities
      for (var item in transactionItems) {
        await inventoryProvider.updateStock(
          item.product,
          item.quantity,
          false, // isIncoming = false (goods out)
        );
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi barang keluar berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Terjadi kesalahan'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final inventory = inventoryProvider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Barang Keluar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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
                                  // Date Field
                                  const Text(
                                    'Tanggal',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _dateController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _dateController.text = date
                                              .toIso8601String()
                                              .split('T')[0];
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Recipient Field
                                  const Text(
                                    'Penerima',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _recipientController,
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan nama penerima',
                                      errorText: _errors['recipient'],
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        setState(() {
                                          _errors.remove('recipient');
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Note Field
                                  const Text(
                                    'Catatan (Opsional)',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _noteController,
                                    decoration: const InputDecoration(
                                      hintText: 'Catatan tambahan',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Items List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daftar Barang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Barang'),
                                onPressed: _addItem,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).colorScheme.secondary,
                                  side: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Items Cards
                          ...List.generate(_items.length, (index) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Field
                                    const Text(
                                      'Nama Barang',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _items[index]['product'].isEmpty
                                          ? null
                                          : _items[index]['product'],
                                      decoration: InputDecoration(
                                        hintText: 'Pilih barang',
                                        errorText: _errors['product-$index'],
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: inventory.map((item) {
                                        return DropdownMenuItem(
                                          value: item.name,
                                          child: Text(
                                              '${item.name} (${item.stock} ${item.unit})'),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateItemProduct(index, value);
                                          setState(() {
                                            _errors.remove('product-$index');
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Quantity and Unit Fields
                                    Row(
                                      children: [
                                        // Quantity Field
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Jumlah',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                initialValue: _items[index]
                                                    ['quantity'],
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  errorText: _errors[
                                                      'quantity-$index'],
                                                  border:
                                                      const OutlineInputBorder(),
                                                ),
                                                onChanged: (value) =>
                                                    _updateItemQuantity(
                                                        index, value),
                                              ),
                                              if (_items[index]['available'] >
                                                      0 &&
                                                  !_errors.containsKey(
                                                      'quantity-$index'))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: Text(
                                                    'Tersedia: ${_items[index]['available']} ${_items[index]['unit']}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Unit Field
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Satuan',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                readOnly: true,
                                                initialValue: _items[index]
                                                    ['unit'],
                                                decoration: InputDecoration(
                                                  border:
                                                      const OutlineInputBorder(),
                                                  filled: true,
                                                  fillColor: Colors.grey[200],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (_items[index]['price'] > 0)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 12.0),
                                        child: Row(
                                          children: [
                                            const Text(
                                              'Harga:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${CurrencyFormatter.format(_items[index]['price'])} / ${_items[index]['unit']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    if (_items.length > 1)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.delete,
                                              size: 18),
                                          label: const Text('Hapus'),
                                          onPressed: () => _removeItem(index),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          if (_errors.isNotEmpty)
                            Card(
                              color: Colors.red[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Harap perbaiki kesalahan sebelum mengirimkan formulir',
                                        style:
                                            TextStyle(color: Colors.red[800]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Save Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Transaksi'),
                      onPressed: _errors.isEmpty ? saveForm : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
