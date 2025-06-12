// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/inventory_item.dart';

class InventoryProvider with ChangeNotifier {
  List<InventoryItem> _items = [];
  bool _isLoading = false;

  List<InventoryItem> get items {
    return [..._items];
  }

  bool get isLoading {
    return _isLoading;
  }

  Future<void> fetchAndSetInventory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('inventory')) {
        _items = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final inventoryData = prefs.getString('inventory');
      final List<dynamic> decodedData = json.decode(inventoryData!);

      _items = decodedData.map((item) => InventoryItem.fromJson(item)).toList();

      // Sort by name
      _items.sort((a, b) => a.name.compareTo(b.name));
    } catch (error) {
      print('Error fetching inventory: $error');
      _items = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    try {
      // Generate new ID (max ID + 1)
      int newId = 1;
      if (_items.isNotEmpty) {
        newId =
            _items.map((item) => item.id).reduce((a, b) => a > b ? a : b) + 1;
      }

      final newItem = InventoryItem(
        id: newId,
        name: item.name,
        category: item.category,
        stock: item.stock,
        unit: item.unit,
        price: item.price,
        lastUpdate: DateTime.now().toIso8601String().split('T')[0],
      );

      _items.add(newItem);

      // Sort by name
      _items.sort((a, b) => a.name.compareTo(b.name));

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('inventory',
          json.encode(_items.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      print('Error adding inventory item: $error');
      rethrow;
    }
  }

  Future<void> updateInventoryItem(InventoryItem updatedItem) async {
    try {
      final itemIndex = _items.indexWhere((item) => item.id == updatedItem.id);
      if (itemIndex >= 0) {
        _items[itemIndex] = updatedItem;

        // Sort by name
        _items.sort((a, b) => a.name.compareTo(b.name));

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('inventory',
            json.encode(_items.map((item) => item.toJson()).toList()));

        notifyListeners();
      }
    } catch (error) {
      print('Error updating inventory item: $error');
      rethrow;
    }
  }

  Future<void> deleteInventoryItem(int id) async {
    try {
      _items.removeWhere((item) => item.id == id);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('inventory',
          json.encode(_items.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      print('Error deleting inventory item: $error');
      rethrow;
    }
  }

  Future<void> updateStock(
      String productName, int quantity, bool isIncoming) async {
    try {
      final itemIndex = _items.indexWhere((item) => item.name == productName);
      if (itemIndex >= 0) {
        final item = _items[itemIndex];

        // Update stock (add for incoming, subtract for outgoing)
        final newStock =
            isIncoming ? item.stock + quantity : item.stock - quantity;

        // Create updated item
        final updatedItem = InventoryItem(
          id: item.id,
          name: item.name,
          category: item.category,
          stock: newStock,
          unit: item.unit,
          price: item.price,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        );

        _items[itemIndex] = updatedItem;

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('inventory',
            json.encode(_items.map((item) => item.toJson()).toList()));

        notifyListeners();
      }
    } catch (error) {
      print('Error updating stock: $error');
      rethrow;
    }
  }

  InventoryItem findById(int id) {
    return _items.firstWhere((item) => item.id == id);
  }

  InventoryItem? findByName(String name) {
    try {
      return _items.firstWhere((item) => item.name == name);
    } catch (error) {
      return null;
    }
  }

  List<InventoryItem> getLowStockItems(int threshold) {
    return _items.where((item) => item.stock <= threshold).toList();
  }

  int getTotalInventoryValue() {
    return _items.fold(0, (sum, item) => sum + (item.stock * item.price));
  }

  // Method to generate sample data for testing
  Future<void> generateSampleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final sampleItems = [
        InventoryItem(
          id: 1,
          name: 'Daging Sapi',
          category: 'Bahan Utama',
          stock: 25,
          unit: 'kg',
          price: 120000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 2,
          name: 'Mie Ramen',
          category: 'Bahan Utama',
          stock: 100,
          unit: 'pcs',
          price: 15000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 3,
          name: 'Telur',
          category: 'Bahan',
          stock: 200,
          unit: 'pcs',
          price: 2500,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 4,
          name: 'Daun Bawang',
          category: 'Bumbu',
          stock: 15,
          unit: 'kg',
          price: 25000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 5,
          name: 'Garam',
          category: 'Bumbu',
          stock: 30,
          unit: 'kg',
          price: 10000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 6,
          name: 'Kotak Bento',
          category: 'Kemasan',
          stock: 500,
          unit: 'pcs',
          price: 5000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 7,
          name: 'Sumpit',
          category: 'Kemasan',
          stock: 1000,
          unit: 'pcs',
          price: 500,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
        InventoryItem(
          id: 8,
          name: 'Tisu',
          category: 'Lainnya',
          stock: 100,
          unit: 'pack',
          price: 15000,
          lastUpdate: DateTime.now().toIso8601String().split('T')[0],
        ),
      ];

      _items = sampleItems;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('inventory',
          json.encode(_items.map((item) => item.toJson()).toList()));
    } catch (error) {
      print('Error generating sample data: $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Method to clear all data
  Future<void> clearData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = [];

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('inventory');
    } catch (error) {
      print('Error clearing data: $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  getNextId() {}
}
