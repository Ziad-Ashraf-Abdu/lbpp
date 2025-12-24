import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Config & Providers
import 'config/theme.dart';
import 'providers/app_state.dart';

// Services
import 'services/biomechanical_analyzer.dart';

// Screens
import 'ui/screens/initialization_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/dashboard_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before permission requests
  WidgetsFlutterBinding.ensureInitialized();

  // Request necessary Bluetooth and Location permissions for ESP32 communication
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location
  ].request();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<BiomechanicalAnalyzer>(create: (_) => BiomechanicalAnalyzer()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Spine Monitor',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,

      // We start with the funny swinging spine initialization
      initialRoute: '/',

      routes: {
        // 1. Funny Intro Screen
        '/': (context) => const InitializationScreen(),

        // 2. Login / Auth Screen
        '/auth': (context) => const AuthScreen(),

        // 3. Main Application Dashboard
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}