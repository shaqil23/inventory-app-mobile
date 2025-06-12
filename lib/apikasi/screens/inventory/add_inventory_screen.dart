// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:komby_bento_inventory/apikasi/providers/management/inventory_provider.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_item.dart';

class AddInventoryScreen extends StatefulWidget {
  @override
  _AddInventoryScreenState createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  final _customUnitController = TextEditingController();

  String _selectedCategory = '';
  String _selectedUnit = '';
  bool _isCustomUnit = false;
  final Map<String, String> _errors = {};
  bool _isLoading = false;

  final List<String> _categories = [
    'Bahan Utama',
    'Bahan',
    'Bumbu',
    'Kemasan',
    'Lainnya',
  ];

  final List<String> _units = [
    'kg',
    'g',
    'liter',
    'ml',
    'pcs',
    'box',
    'other',
  ];

  final Map<String, String> _unitLabels = {
    'kg': 'Kilogram (kg)',
    'g': 'Gram (g)',
    'liter': 'Liter (L)',
    'ml': 'Mililiter (ml)',
    'pcs': 'Buah (pcs)',
    'box': 'Box',
    'other': 'Lainnya',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    if (value.isEmpty) {
      setState(() {
        _errors['name'] = 'Nama barang tidak boleh kosong';
      });
      return;
    }

    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final items = inventoryProvider.items;
    final isDuplicate =
        items.any((item) => item.name.toLowerCase() == value.toLowerCase());

    if (isDuplicate) {
      setState(() {
        _errors['name'] = 'Barang dengan nama ini sudah ada';
      });
    } else {
      setState(() {
        _errors.remove('name');
      });
    }
  }

  void _validateStock(String value) {
    if (value.isEmpty) {
      setState(() {
        _errors['stock'] = 'Jumlah stok tidak boleh kosong';
      });
      return;
    }

    final stock = int.tryParse(value);
    if (stock == null || stock <= 0) {
      setState(() {
        _errors['stock'] = 'Jumlah stok harus lebih dari 0';
      });
    } else {
      setState(() {
        _errors.remove('stock');
      });
    }
  }

  void _validatePrice(String value) {
    if (value.isEmpty) {
      setState(() {
        _errors.remove('price');
      });
      return;
    }

    final price = int.tryParse(value);
    if (price == null || price < 0) {
      setState(() {
        _errors['price'] = 'Harga tidak boleh negatif';
      });
    } else {
      setState(() {
        _errors.remove('price');
      });
    }
  }

  Future<void> _saveForm() async {
    // Validate form
    _validateName(_nameController.text);
    _validateStock(_stockController.text);
    _validatePrice(_priceController.text);

    if (_selectedCategory.isEmpty) {
      setState(() {
        _errors['category'] = 'Kategori harus dipilih';
      });
      return;
    } else {
      setState(() {
        _errors.remove('category');
      });
    }

    if (_selectedUnit.isEmpty) {
      setState(() {
        _errors['unit'] = 'Satuan harus dipilih';
      });
      return;
    } else {
      setState(() {
        _errors.remove('unit');
      });
    }

    if (_selectedUnit == 'other' && _customUnitController.text.isEmpty) {
      setState(() {
        _errors['customUnit'] = 'Satuan kustom tidak boleh kosong';
      });
      return;
    } else {
      setState(() {
        _errors.remove('customUnit');
      });
    }

    if (_errors.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      final newItem = InventoryItem(
        id: inventoryProvider.getNextId(),
        name: _nameController.text,
        category: _selectedCategory,
        stock: int.parse(_stockController.text),
        unit: _selectedUnit == 'other'
            ? _customUnitController.text
            : _selectedUnit,
        price: _priceController.text.isEmpty
            ? 0
            : int.parse(_priceController.text),
        lastUpdate: DateTime.now().toIso8601String().split('T')[0],
      );

      await inventoryProvider.addInventoryItem(newItem);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barang berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Terjadi kesalahan'),
          content: const Text('Gagal menambahkan barang baru.'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Barang Baru'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        const Text(
                          'Nama Barang',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama barang',
                            errorText: _errors['name'],
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: _validateName,
                        ),
                        const SizedBox(height: 16),

                        // Category Field
                        const Text(
                          'Kategori',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory.isEmpty
                              ? null
                              : _selectedCategory,
                          decoration: InputDecoration(
                            hintText: 'Pilih kategori',
                            errorText: _errors['category'],
                            border: const OutlineInputBorder(),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                              _errors.remove('category');
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Stock, Unit, and Price Fields
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stock Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jumlah Stok',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      errorText: _errors['stock'],
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: _validateStock,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Unit Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Satuan',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _selectedUnit.isEmpty
                                        ? null
                                        : _selectedUnit,
                                    decoration: InputDecoration(
                                      hintText: 'Pilih satuan',
                                      errorText: _errors['unit'],
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: _units.map((unit) {
                                      return DropdownMenuItem(
                                        value: unit,
                                        child: Text(_unitLabels[unit]!),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedUnit = value!;
                                        _isCustomUnit = value == 'other';
                                        _errors.remove('unit');
                                      });
                                    },
                                  ),
                                  if (_isCustomUnit) ...[
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _customUnitController,
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan satuan kustom',
                                        errorText: _errors['customUnit'],
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          setState(() {
                                            _errors.remove('customUnit');
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Price Field
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Harga Satuan (Rp)',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      errorText: _errors['price'],
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: _validatePrice,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Simpan Barang'),
                            onPressed: _saveForm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
