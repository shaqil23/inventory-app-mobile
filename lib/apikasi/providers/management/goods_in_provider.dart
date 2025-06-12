import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:komby_bento_inventory/apikasi/models/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goods_in.dart';

class GoodsInProvider with ChangeNotifier {
  List<GoodsIn> _transactions = [];
  bool _isLoading = false;

  List<GoodsIn> get transactions {
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
      if (!prefs.containsKey('goods_in')) {
        _transactions = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final transactionsData = prefs.getString('goods_in');
      final List<dynamic> decodedData = json.decode(transactionsData!);

      _transactions =
          decodedData.map((item) => GoodsIn.fromJson(item)).toList();

      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (error) {
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(GoodsIn transaction) async {
    try {
      _transactions.add(transaction);

      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_in',
          json.encode(_transactions.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateTransaction(GoodsIn updatedTransaction) async {
    try {
      final transactionIndex = _transactions
          .indexWhere((transaction) => transaction.id == updatedTransaction.id);
      if (transactionIndex >= 0) {
        _transactions[transactionIndex] = updatedTransaction;

        // Sort by date (newest first)
        _transactions.sort((a, b) => b.date.compareTo(a.date));

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('goods_in',
            json.encode(_transactions.map((item) => item.toJson()).toList()));

        notifyListeners();
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      _transactions.removeWhere((transaction) => transaction.id == id);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_in',
          json.encode(_transactions.map((item) => item.toJson()).toList()));

      notifyListeners();
    } catch (error) {
      if (kDebugMode) {
        print('Error deleting goods-in transaction: $error');
      }
      rethrow;
    }
  }

  GoodsIn findById(int id) {
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

  List<GoodsIn> getTransactionsByDateRange(
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

  // Method to generate sample data for testing
  Future<void> generateSampleData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final lastWeek = today.subtract(const Duration(days: 7));

      final sampleTransactions = [
        GoodsIn(
          id: 1,
          date: today.toIso8601String().split('T')[0],
          supplier: 'Supplier Daging Segar',
          note: 'Pengiriman rutin mingguan',
          items: [
            TransactionItem(
              product: 'Daging Sapi',
              quantity: 10,
              unit: 'kg',
              price: 120000,
            ),
            TransactionItem(
              product: 'Telur',
              quantity: 50,
              unit: 'pcs',
              price: 2500,
            ),
          ],
          status: 'completed',
        ),
        GoodsIn(
          id: 2,
          date: yesterday.toIso8601String().split('T')[0],
          supplier: 'Toko Mie Jaya',
          note: 'Pembelian mie ramen',
          items: [
            TransactionItem(
              product: 'Mie Ramen',
              quantity: 30,
              unit: 'pcs',
              price: 15000,
            ),
          ],
          status: 'completed',
        ),
        GoodsIn(
          id: 3,
          date: lastWeek.toIso8601String().split('T')[0],
          supplier: 'Toko Kemasan Bersama',
          note: 'Pembelian kemasan',
          items: [
            TransactionItem(
              product: 'Kotak Bento',
              quantity: 100,
              unit: 'pcs',
              price: 5000,
            ),
            TransactionItem(
              product: 'Sumpit',
              quantity: 200,
              unit: 'pcs',
              price: 500,
            ),
            TransactionItem(
              product: 'Tisu',
              quantity: 20,
              unit: 'pack',
              price: 15000,
            ),
          ],
          status: 'completed',
        ),
      ];

      _transactions = sampleTransactions;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('goods_in',
          json.encode(_transactions.map((item) => item.toJson()).toList()));
      // ignore: empty_catches
    } catch (error) {}

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
      prefs.remove('goods_in');
    } catch (error) {
      if (kDebugMode) {
        print('Error clearing data: $error');
      }
    }

    _isLoading = false;
    notifyListeners();
  }
}
