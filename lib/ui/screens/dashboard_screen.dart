import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';
import '../../services/biomechanical_analyzer.dart';
import '../../ui/widgets/spine_3d_visualizer.dart';
import '../widgets/main_drawer.dart';
import '../widgets/ai_model_placeholder.dart';

// Deep dark background for high-contrast OLED displays
const Color _cardBackgroundColor = Color(0xFF181818);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late BiomechanicalAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _analyzer = BiomechanicalAnalyzer();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        // Access control: If we are connected but the key failed to decrypt the data,
        // we show the Restriction Overlay instead of the UI.
        final bool showRestricted = state.isConnected && !state.isKeyValidated && !state.useDummyData;
        final displayData = state.currentSpineKinematics;

        return Scaffold(
          drawer: const MainDrawer(),
          appBar: AppBar(
            title: const Text("Lumbar Monitor"),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              // Bluetooth Toggle Button
              IconButton(
                icon: Icon(state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                color: state.isConnected ? Colors.blue : Colors.grey,
                onPressed: () {
                  if (state.isConnected) {
                    state.disconnect();
                  } else {
                    state.startConnection();
                  }
                },
              ),
              if (displayData != null && !showRestricted)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showBiomechanicsInfo(context, displayData),
                ),
            ],
          ),
          body: showRestricted
              ? _buildRestrictedOverlay(context, state)
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // --- PERSONALIZED GREETING ---
                  Text(
                    "Hello, ${state.userName}!",
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white
                    ),
                  ),
                  const Text(
                    "Welcome back to your spine health overview.",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),

                  const SizedBox(height: 24),
                  _buildConnectionCard(state),
                  const SizedBox(height: 24),

                  if (displayData != null) ...[
                    // 1. Data Grid
                    _buildBiomechanicsCard(displayData),
                    const SizedBox(height: 24),

                    // 2. 3D Visualization
                    const Spine3DVisualizer(),
                    const SizedBox(height: 24),

                    // 3. Motion Analysis (Warnings/Danger)
                    _buildMotionAnalysisSection(displayData),
                    const SizedBox(height: 24),

                    // 4. AI Predictive Model Placeholder
                    const AIModelPlaceholder(),
                    const SizedBox(height: 24),
                  ] else ...[
                    // Waiting State
                    _buildWaitingState(state),
                  ],

                  // Persistent Scan Button when disconnected
                  if (!state.isConnected)
                    _buildScanButton(state),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- NEW: Restricted Access UI ---
  Widget _buildRestrictedOverlay(BuildContext context, AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 100, color: Colors.redAccent),
          const SizedBox(height: 24),
          const Text(
            "ENCRYPTION ERROR",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            "The activation key provided does not match the hardware signature of this sensor node. Telemetry data cannot be decrypted.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pushReplacementNamed(context, '/auth'),
            child: const Text("UPDATE ACTIVATION KEY", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper for the loading/waiting UI
  Widget _buildWaitingState(AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80.0),
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 20),
            Text(
                state.connectionStatus == BleStatus.scanning
                    ? 'Searching for Spinal Sensors...'
                    : 'Waiting for IMU data Stream...',
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: state.connectionStatus == BleStatus.scanning
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(state.connectionStatus == BleStatus.error ? Icons.refresh : Icons.bluetooth_searching),
        label: Text(state.connectionStatus == BleStatus.scanning ? "Scanning..." : "Connect to Device"),
        onPressed: state.connectionStatus == BleStatus.scanning ? null : () => state.startConnection(),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: state.connectionStatus == BleStatus.error ? Colors.redAccent : Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: state.isConnected ? (state.isKeyValidated ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              state.isConnected ? (state.isKeyValidated ? Icons.check_circle : Icons.sync_problem) : Icons.error_outline,
              color: state.isConnected ? (state.isKeyValidated ? Colors.green : Colors.orangeAccent) : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SYSTEM STATUS", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.2)),
              Text(
                state.isConnected
                    ? (state.isKeyValidated ? "Live Tracking" : "Handshake Failed")
                    : "Sensor Offline",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
          const Spacer(),
          if (state.isConnected)
            Badge(
                label: Text(state.isKeyValidated ? "SECURE" : "LOCKED"),
                backgroundColor: state.isKeyValidated ? Colors.blueGrey : Colors.red.withOpacity(0.5)
            ),
        ],
      ),
    );
  }

  Widget _buildBiomechanicsCard(dynamic data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("REAL-TIME KINEMATICS",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12, letterSpacing: 1.1)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDataItem("Flexion", "${data.relativeFlexion.toStringAsFixed(1)}°", Colors.blue),
                const SizedBox(width: 15),
                _buildDataItem("Lateral", "${data.relativeLateralBend.toStringAsFixed(1)}°", Colors.green),
                const SizedBox(width: 15),
                _buildDataItem("Rotation", "${data.relativeRotation.toStringAsFixed(1)}°", Colors.redAccent),
                const SizedBox(width: 15),
                _buildDataItem("Strain", "${data.estimatedCompression.toStringAsFixed(1)}%", Colors.purpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
      ],
    );
  }

  Widget _buildMotionAnalysisSection(dynamic data) {
    final analysis = _analyzer.checkThresholds(data);
    final isSafe = analysis['isSafe'] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSafe ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSafe ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isSafe ? Icons.shield_outlined : Icons.gpp_bad_outlined,
                color: isSafe ? Colors.green : Colors.redAccent),
            const SizedBox(width: 8),
            Text(isSafe ? "Biomechanics: Safe" : "Risk Detected",
                style: TextStyle(color: isSafe ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          if (analysis['warnings'].isNotEmpty)
            ...analysis['warnings'].map((w) => Text("• $w", style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))),
          if (analysis['danger'].isNotEmpty)
            ...analysis['danger'].map((d) => Text("• $d", style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showBiomechanicsInfo(BuildContext context, dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("Sensor Placement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSensorRow("Upper IMU", "Placed at T12/L1 Vertebrae", Colors.blue),
            const SizedBox(height: 12),
            _buildSensorRow("Lower IMU", "Placed at L4/L5 Vertebrae", Colors.green),
            const Divider(height: 30, color: Colors.white10),
            const Text(
              "Calculation Logic: Relative posture is derived by subtracting the orientation of the lower sensor from the upper sensor.",
              style: TextStyle(fontSize: 12, color: Colors.white54),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(String title, String sub, Color color) {
    return Row(children: [
      Icon(Icons.location_on, color: color),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ])
    ]);
  }
}