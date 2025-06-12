import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../apikasi/app_theme.dart';
import 'apikasi/providers/management/inventory_provider.dart';
import 'apikasi/providers/management/goods_in_provider.dart';
import 'apikasi/providers/management/goods_out_provider.dart';
import 'apikasi/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => InventoryProvider()),
        ChangeNotifierProvider(create: (ctx) => GoodsInProvider()),
        ChangeNotifierProvider(create: (ctx) => GoodsOutProvider()),
      ],
      child: MaterialApp(
        title: 'Komby Bento Inventory',
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'), // Indonesian
          Locale('en', 'US'), // English
        ],
        locale: const Locale('id', 'ID'),
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
