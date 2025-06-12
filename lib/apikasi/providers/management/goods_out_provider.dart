// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:komby_bento_inventory/apikasi/models/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goods_out.dart';

class GoodsOutProvider with ChangeNotifier {
  List<GoodsOut> _transactions = [];
  bool _isLoading = false;

  List<GoodsOut> get transactions {
    return [..._transactions];
  }

  bool get isLoading {
    return _isLoading;
  }

  Future<void> fetchAndSetTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('goods_out')) {
        _transactions = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final transactionsData = prefs.getString('goods_out');
      final List<dynamic> decodedData = json.decode(transactionsData!);

      _transactions =
          decodedData.map((item) => GoodsOut.fromJson(item)).toList();

      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (error) {
      print('Error fetching goods-out transactions: $error');
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(GoodsOut transaction) async {
    try {
      _transactions.add(transaction);

      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_out',
          json.encode(_transactions.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      print('Error adding goods-out transaction: $error');
      rethrow;
    }
  }

  Future<void> updateTransaction(GoodsOut updatedTransaction) async {
    try {
      final transactionIndex = _transactions
          .indexWhere((transaction) => transaction.id == updatedTransaction.id);
      if (transactionIndex >= 0) {
        _transactions[transactionIndex] = updatedTransaction;

        // Sort by date (newest first)
        _transactions.sort((a, b) => b.date.compareTo(a.date));

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('goods_out',
            json.encode(_transactions.map((item) => item.toJson()).toList()));

        notifyListeners();
      }
    } catch (error) {
      print('Error updating goods-out transaction: $error');
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      _transactions.removeWhere((transaction) => transaction.id == id);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_out',
          json.encode(_transactions.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      print('Error deleting goods-out transaction: $error');
      rethrow;
    }
  }

  GoodsOut findById(int id) {
    return _transactions.firstWhere((transaction) => transaction.id == id);
  }

  int getNextId() {
    if (_transactions.isEmpty) {
      return 1;
    }
    return _transactions
            .map((transaction) => transaction.id)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  List<GoodsOut> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _transactions.where((transaction) {
      final transactionDate = DateTime.parse(transaction.date);
      return transactionDate
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          transactionDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  int getTotalValueByDateRange(DateTime startDate, DateTime endDate) {
    final filteredTransactions = getTransactionsByDateRange(startDate, endDate);
    return filteredTransactions.fold(
      0,
      (sum, transaction) =>
          sum +
          transaction.items.fold(
            0,
            (itemSum, item) => itemSum + (item.quantity * item.price),
          ),
    );
  }

  Map<String, Map<String, dynamic>> getTopItemsByDateRange(
      DateTime startDate, DateTime endDate) {
    final filteredTransactions = getTransactionsByDateRange(startDate, endDate);
    Map<String, Map<String, dynamic>> itemUsage = {};

    for (var transaction in filteredTransactions) {
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

    return itemUsage;
  }

  // Method to generate sample data for testing
  Future<void> generateSampleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final lastWeek = today.subtract(const Duration(days: 7));

      final sampleTransactions = [
        GoodsOut(
          id: 1,
          date: today.toIso8601String().split('T')[0],
          recipient: 'Cabang Kemang',
          note: 'Pengiriman harian',
          items: [
            TransactionItem(
              product: 'Daging Sapi',
              quantity: 5,
              unit: 'kg',
              price: 120000,
            ),
            TransactionItem(
              product: 'Mie Ramen',
              quantity: 10,
              unit: 'pcs',
              price: 15000,
            ),
            TransactionItem(
              product: 'Telur',
              quantity: 20,
              unit: 'pcs',
              price: 2500,
            ),
            TransactionItem(
              product: 'Kotak Bento',
              quantity: 30,
              unit: 'pcs',
              price: 5000,
            ),
          ],
          status: 'completed',
        ),
        GoodsOut(
          id: 2,
          date: yesterday.toIso8601String().split('T')[0],
          recipient: 'Cabang Senopati',
          note: 'Pengiriman tambahan',
          items: [
            TransactionItem(
              product: 'Daging Sapi',
              quantity: 3,
              unit: 'kg',
              price: 120000,
            ),
            TransactionItem(
              product: 'Mie Ramen',
              quantity: 8,
              unit: 'pcs',
              price: 15000,
            ),
            TransactionItem(
              product: 'Kotak Bento',
              quantity: 20,
              unit: 'pcs',
              price: 5000,
            ),
          ],
          status: 'completed',
        ),
        GoodsOut(
          id: 3,
          date: lastWeek.toIso8601String().split('T')[0],
          recipient: 'Cabang Menteng',
          note: 'Pengiriman mingguan',
          items: [
            TransactionItem(
              product: 'Daging Sapi',
              quantity: 8,
              unit: 'kg',
              price: 120000,
            ),
            TransactionItem(
              product: 'Mie Ramen',
              quantity: 15,
              unit: 'pcs',
              price: 15000,
            ),
            TransactionItem(
              product: 'Telur',
              quantity: 30,
              unit: 'pcs',
              price: 2500,
            ),
            TransactionItem(
              product: 'Kotak Bento',
              quantity: 40,
              unit: 'pcs',
              price: 5000,
            ),
            TransactionItem(
              product: 'Sumpit',
              quantity: 80,
              unit: 'pcs',
              price: 500,
            ),
          ],
          status: 'completed',
        ),
      ];

      _transactions = sampleTransactions;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_out',
          json.encode(_transactions.map((item) => item.toJson()).toList()));
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
      _transactions = [];

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('goods_out');
    } catch (error) {
      print('Error clearing data: $error');
    }

    _isLoading = false;
    notifyListeners();
  }
}
