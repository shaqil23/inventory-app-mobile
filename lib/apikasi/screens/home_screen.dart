// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:komby_bento_inventory/apikasi/screens/goods_in/goods_in_screen.dart';
import 'package:komby_bento_inventory/apikasi/screens/goods_out/goods_out_screen.dart';
import 'package:provider/provider.dart';
import '../providers/management/goods_in_provider.dart';
import '../providers/management/goods_out_provider.dart';
import '../utils/date_formatter.dart';
import 'inventory/inventory_screen.dart';
import 'package:komby_bento_inventory/apikasi/screens/reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInit = true;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      setState(() {
        _isLoading = true;
      });
      Provider.of<GoodsInProvider>(context).fetchAndSetTransactions().then((_) {
        Provider.of<GoodsOutProvider>(context)
            .fetchAndSetTransactions()
            .then((_) {
          setState(() {
            _isLoading = false;
          });
        });
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final goodsInProvider = Provider.of<GoodsInProvider>(context);
    final goodsOutProvider = Provider.of<GoodsOutProvider>(context);

    final today = DateFormatter.getTodayDate();

    final todayGoodsIn = goodsInProvider.transactions
        .where((transaction) => transaction.date == today)
        .length;

    final todayGoodsOut = goodsOutProvider.transactions
        .where((transaction) => transaction.date == today)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 30, height: 30),
            const SizedBox(width: 8),
            const Text('Komby Bento'),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Admin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistem Gudang',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            context,
                            'Barang Masuk',
                            todayGoodsIn.toString(),
                            Icons.login,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            context,
                            'Barang Keluar',
                            todayGoodsOut.toString(),
                            Icons.logout,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Menu Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildMenuCard(
                          context,
                          'Inventaris',
                          'Kelola semua barang',
                          Icons.inventory,
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const InventoryScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          'Barang Masuk',
                          'Lihat riwayat barang masuk',
                          Icons.login,
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const GoodsInScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          'Barang Keluar',
                          'Catat barang keluar',
                          Icons.logout,
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const GoodsOutScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          'Laporan',
                          'Lihat statistik & laporan',
                          Icons.trending_up,
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const ReportsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const InventoryScreen()),
              );
              break;
            case 2:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const GoodsInScreen()),
              );
              break;
            case 3:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const GoodsOutScreen()),
              );
              break;
            case 4:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const ReportsScreen()),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventaris',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: 'Masuk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Keluar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).appBarTheme.foregroundColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const Text(
              'Hari Ini',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).appBarTheme.foregroundColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
