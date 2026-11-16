import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'services/push_service.dart';
import 'services/local_data_session.dart';

// Initialize app services before showing the first screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalDataSession.instance.initialize();
  runApp(const StockWiseApp());
  PushService.instance.initialize().catchError((Object _) {});
}

// Apply the shared theme and account entry gate.
class StockWiseApp extends StatelessWidget {
  const StockWiseApp({super.key});

  // Render the stock wise app component.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StockWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
