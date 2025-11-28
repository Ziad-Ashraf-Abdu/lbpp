import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';
import '../../config/constants.dart';
import '../widgets/status_gauge.dart';
import '../widgets/main_drawer.dart'; // Import the new Drawer

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      // Add the Drawer here
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text("Lumbar Monitor"),
        actions: [
          IconButton(
            icon: Icon(state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            color: state.isConnected ? Colors.blue : Colors.grey,
            onPressed: () => state.isConnected ? state.disconnect() : state.startConnection(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Status Card
            _buildConnectionCard(state),
            const Spacer(),
            // Main Visualization
            StatusGauge(angle: state.lumbarAngle),
            const Spacer(),

            // Connect Button (Handles Scanning, Disconnected, AND Error states)
            if (!state.isConnected)
              ElevatedButton.icon(
                icon: state.connectionStatus == BleStatus.scanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(state.connectionStatus == BleStatus.error ? Icons.refresh : Icons.search),
                label: Text(
                    state.connectionStatus == BleStatus.scanning ? "Scanning..." :
                    state.connectionStatus == BleStatus.error ? "Scan Failed - Retry" : "Connect to Device"
                ),
                // ENABLE BUTTON if Disconnected OR Error
                onPressed: (state.connectionStatus == BleStatus.disconnected || state.connectionStatus == BleStatus.error)
                    ? () => state.startConnection()
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  // Turn button red if there was an error
                  backgroundColor: state.connectionStatus == BleStatus.error ? Colors.redAccent : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: state.isConnected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            child: Icon(Icons.monitor_heart, color: state.isConnected ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("System Status", style: TextStyle(color: Colors.grey)),
              Text(
                state.isConnected ? "Live Monitoring" : "Waiting for Connection",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          )
        ],
      ),
    );
  }
}