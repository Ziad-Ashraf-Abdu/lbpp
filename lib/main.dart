  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:permission_handler/permission_handler.dart';
  import 'config/theme.dart';
  import 'providers/app_state.dart';
  import 'ui/screens/activation_screen.dart';
  import 'ui/screens/dashboard_screen.dart'; // Add this import
  import 'services/biomechanical_analyzer.dart'; // Add this import

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect].request();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          Provider<BiomechanicalAnalyzer>(create: (_) => BiomechanicalAnalyzer()), // Add provider
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
        // Temporarily change to DashboardScreen for testing
        // home: const ActivationScreen(),
        home: DashboardScreen(), // Change to this for testing
        debugShowCheckedModeBanner: false,
      );
    }
  }