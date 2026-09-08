import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const StockWiseApp());
}

class StockWiseApp extends StatelessWidget {
  const StockWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF75A972)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
