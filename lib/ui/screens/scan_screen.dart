import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Animation for the Radar Pulse effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Trigger the Auto-Connect Logic immediately upon entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      if (!state.isConnected) {
        state.startConnection();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AppState to handle navigation and UI updates
    return Consumer<AppState>(
      builder: (context, state, child) {

        // Auto-close screen if connected successfully
        if (state.connectionStatus == BleStatus.connected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context); // Return to Dashboard
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                state.disconnect(); // Cancel attempt
                Navigator.pop(context);
              },
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Dynamic Animation Widget
                SizedBox(
                  height: 300,
                  width: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radar Waves (Only show when scanning/connecting)
                      if (state.connectionStatus == BleStatus.scanning ||
                          state.connectionStatus == BleStatus.connecting)
                        _buildRadarWaves(),

                      // Central Icon
                      _buildStatusIcon(state.connectionStatus),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 2. Status Text
                Text(
                  _getStatusTitle(state.connectionStatus),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _getStatusSubtitle(state.connectionStatus),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),

                const SizedBox(height: 50),

                // 3. Retry Button (if disconnected or error)
                if (state.connectionStatus == BleStatus.disconnected ||
                    state.connectionStatus == BleStatus.error)
                  ElevatedButton.icon(
                    onPressed: () => state.startConnection(),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry Connection"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  Widget _buildRadarWaves() {
    return CustomPaint(
      painter: _RadarPainter(_animationController),
      child: Container(),
    );
  }

  Widget _buildStatusIcon(BleStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case BleStatus.scanning:
        icon = Icons.bluetooth_searching;
        color = Colors.blue;
        break;
      case BleStatus.connecting:
        icon = Icons.bluetooth_connected;
        color = Colors.yellow;
        break;
      case BleStatus.handshake:
        icon = Icons.security; // The "Lock" icon for your Handshake feature
        color = Colors.orangeAccent;
        break;
      case BleStatus.connected:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case BleStatus.error:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
      case BleStatus.disconnected:
      default:
        icon = Icons.signal_wifi_off;
        color = Colors.red;
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  // --- Helper Texts ---

  String _getStatusTitle(BleStatus status) {
    switch (status) {
      case BleStatus.scanning: return "Searching...";
      case BleStatus.connecting: return "Device Found";
      case BleStatus.handshake: return "Verifying Security";
      case BleStatus.connected: return "Connected!";
      case BleStatus.error: return "Connection Failed";
      case BleStatus.disconnected: return "No Device Found";
    }
  }

  String _getStatusSubtitle(BleStatus status) {
    switch (status) {
      case BleStatus.scanning:
        return "Looking for nearby ESP32 devices\nwith the Injury Prevention Service.";
      case BleStatus.connecting:
        return "Establishing Bluetooth link...";
      case BleStatus.handshake:
        return "Sending Activation Key for secure handshake.\nPlease wait...";
      case BleStatus.connected:
        return "Redirecting to Dashboard...";
      case BleStatus.error:
        return "An error occurred during connection.\nPlease check the device and try again.";
      case BleStatus.disconnected:
        return "Make sure your device is turned on\nand within range.";
    }
  }
}

// --- Custom Painter for Radar Effect ---

class _RadarPainter extends CustomPainter {
  final Animation<double> _animation;

  _RadarPainter(this._animation) : super(repaint: _animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Offset center = Offset(size.width / 2, size.height / 2);

    // Draw 3 expanding circles
    for (int i = 0; i < 3; i++) {
      // Stagger the animation for each circle
      final double progress = (_animation.value + (i * 0.33)) % 1.0;
      final double radius = progress * (size.width / 2);
      final double opacity = 1.0 - progress; // Fade out as it expands

      paint.color = Colors.blue.withOpacity(opacity * 0.5);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}