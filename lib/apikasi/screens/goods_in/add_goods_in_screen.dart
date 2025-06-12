// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/management/inventory_provider.dart';
import '../../providers/management/goods_in_provider.dart';
import '../../models/goods_in.dart';
import '../../models/transaction_item.dart';

class AddGoodsInScreen extends StatefulWidget {
  const AddGoodsInScreen({super.key});

  @override
  _AddGoodsInScreenState createState() => _AddGoodsInScreenState();
}

class _AddGoodsInScreenState extends State<AddGoodsInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _supplierController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isInit = true;
  bool _isLoading = false;
  final Map<String, String> _errors = {};

  final List<Map<String, dynamic>> _items = [
    {
      'product': '',
      'quantity': '',
      'unit': '',
      'price': '',
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
    _supplierController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add({
        'product': '',
        'quantity': '',
        'unit': '',
        'price': '',
      });
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        // Remove any errors for this item
        _errors.remove('quantity-$index');
        _errors.remove('price-$index');
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

      // Pre-fill price if available and not already set
      if (selectedProduct.price > 0 && _items[index]['price'] == '') {
        _items[index]['price'] = selectedProduct.price.toString();
      }
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
        } else {
          _errors.remove('quantity-$index');
        }
      }
    });
  }

  void _updateItemPrice(int index, String value) {
    setState(() {
      _items[index]['price'] = value;

      // Validate price
      if (value.isNotEmpty) {
        final price = int.tryParse(value);
        if (price == null || price < 0) {
          _errors['price-$index'] = 'Harga tidak boleh negatif';
        } else {
          _errors.remove('price-$index');
        }
      } else {
        _errors.remove('price-$index');
      }
    });
  }

  Future<void> _saveForm() async {
    // Validate form
    if (_supplierController.text.isEmpty) {
      setState(() {
        _errors['supplier'] = 'Pemasok harus diisi';
      });
      return;
    } else {
      setState(() {
        _errors.remove('supplier');
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
        } else {
          setState(() {
            _errors.remove('quantity-$i');
          });
        }
      }

      if (_items[i]['price'].isNotEmpty) {
        final price = int.tryParse(_items[i]['price']);
        if (price == null || price < 0) {
          setState(() {
            _errors['price-$i'] = 'Harga tidak boleh negatif';
          });
          hasItemErrors = true;
        } else {
          setState(() {
            _errors.remove('price-$i');
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
      final goodsInProvider =
          Provider.of<GoodsInProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      // Create transaction items
      final transactionItems = _items.map((item) {
        return TransactionItem(
          product: item['product'],
          quantity: int.parse(item['quantity']),
          unit: item['unit'],
          price: item['price'].isEmpty ? 0 : int.parse(item['price']),
        );
      }).toList();

      // Create new transaction
      final newTransaction = GoodsIn(
        id: goodsInProvider.getNextId(),
        date: _dateController.text,
        supplier: _supplierController.text,
        note: _noteController.text,
        items: transactionItems,
        status: 'completed',
      );

      // Add transaction
      await goodsInProvider.addTransaction(newTransaction);

      // Update inventory quantities
      for (var item in transactionItems) {
        await inventoryProvider.updateStock(
          item.product,
          item.quantity,
          true, // isIncoming
        );
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi barang masuk berhasil disimpan'),
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
        title: const Text('Tambah Barang Masuk'),
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

                                  // Supplier Field
                                  const Text(
                                    'Pemasok',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _supplierController,
                                    decoration: InputDecoration(
                                      hintText: 'Nama pemasok',
                                      errorText: _errors['supplier'],
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        setState(() {
                                          _errors.remove('supplier');
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

                                    // Quantity, Unit, and Price Fields
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
                                        const SizedBox(width: 12),

                                        // Price Field
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Harga (Rp)',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(height: 8),
                                              TextFormField(
                                                initialValue: _items[index]
                                                    ['price'],
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '0',
                                                  errorText:
                                                      _errors['price-$index'],
                                                  border:
                                                      const OutlineInputBorder(),
                                                ),
                                                onChanged: (value) =>
                                                    _updateItemPrice(
                                                        index, value),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                      onPressed: _errors.isEmpty ? _saveForm : null,
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
