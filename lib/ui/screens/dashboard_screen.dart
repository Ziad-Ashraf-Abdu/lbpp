import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';
import '../../config/constants.dart';
import '../../services/biomechanical_analyzer.dart';
import '../../ui/widgets/spine_3d_visualizer.dart';
import '../widgets/main_drawer.dart';
import '../widgets/ai_model_placeholder.dart';

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
        final displayData = state.currentSpineKinematics;

        return Scaffold(
          drawer: const MainDrawer(),
          appBar: AppBar(
            title: const Text("Lumbar Monitor"),
            actions: [
              // Connection Status Indicator
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: state.isConnected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state.isConnected ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: state.isConnected ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: state.isConnected ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                color: state.isConnected ? Colors.blue : Colors.grey,
                onPressed: () => state.isConnected ? state.disconnect() : state.startConnection(),
              ),
              if (displayData != null)
                IconButton(
                  icon: const Icon(Icons.biotech),
                  onPressed: () => _showBiomechanicsInfo(context, state),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // System Status Card
                  _buildConnectionCard(state),
                  const SizedBox(height: 24),

                  if (state.isConnected) ...[
                    // Real-time Posture State (from ESP32)
                    _buildPostureStateCard(state),
                    const SizedBox(height: 24),

                    // Primary Metric: Relative Flexion (ESP32 calculated)
                    _buildFlexionCard(state),
                    const SizedBox(height: 24),

                    // Raw IMU Data from ESP32
                    _buildRawIMUData(state),
                    const SizedBox(height: 24),

                    // 3D Spine Visualizer
                    const Spine3DVisualizer(),
                    const SizedBox(height: 24),

                    // Motion Analysis
                    if (displayData != null) _buildMotionAnalysisSection(displayData),
                    const SizedBox(height: 24),

                    // AI Placeholder
                    const AIModelPlaceholder(),
                    const SizedBox(height: 24),

                  ] else ...[
                    // Loading/Disconnected State
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bluetooth_searching, size: 64, color: Colors.white24),
                            SizedBox(height: 20),
                            Text(
                              'Waiting for device connection...',
                              style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Connection Button
                  if (!state.isConnected)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton.icon(
                        icon: state.connectionStatus == BleStatus.scanning
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Icon(state.connectionStatus == BleStatus.error ? Icons.refresh : Icons.bluetooth_searching),
                        label: Text(state.connectionStatus == BleStatus.scanning
                            ? "Scanning for ESP32..."
                            : state.connectionStatus == BleStatus.error
                            ? "Connection Failed - Retry"
                            : "Connect to Device"),
                        onPressed: (state.connectionStatus == BleStatus.disconnected ||
                            state.connectionStatus == BleStatus.error)
                            ? () => state.startConnection()
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: state.connectionStatus == BleStatus.error ? Colors.redAccent : Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: state.isConnected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monitor_heart, color: state.isConnected ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("System Status", style: TextStyle(color: Colors.grey)),
                Text(
                  state.isConnected ? "Live Monitoring Active" : "Waiting for Connection",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.sensors, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text("2 IMUs + ZUPT", style: TextStyle(color: Colors.blue, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureStateCard(AppState state) {
    Color stateColor;
    IconData stateIcon;
    String stateText;

    switch (state.postureState) {
      case PostureState.safe:
        stateColor = Colors.green;
        stateIcon = Icons.check_circle;
        stateText = 'SAFE POSTURE';
        break;
      case PostureState.warning:
        stateColor = Colors.orange;
        stateIcon = Icons.warning;
        stateText = 'WARNING - CHECK POSTURE';
        break;
      case PostureState.critical:
        stateColor = Colors.red;
        stateIcon = Icons.error;
        stateText = 'CRITICAL - ADJUST NOW';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: stateColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stateColor, width: 2),
      ),
      child: Row(
        children: [
          Icon(stateIcon, color: stateColor, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateText,
                  style: TextStyle(
                    color: stateColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ESP32 Real-time Analysis',
                  style: TextStyle(color: stateColor.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlexionCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.straighten, color: Colors.blue),
              SizedBox(width: 8),
              Text("Lumbar Flexion Angle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${state.relativeFlexion.toStringAsFixed(1)}°",
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Calculated by ESP32 Filters",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildThresholdIndicator("Safe", Colors.green, state.relativeFlexion < 20),
              const SizedBox(width: 16),
              _buildThresholdIndicator("Warning", Colors.orange, state.relativeFlexion >= 20 && state.relativeFlexion < 30),
              const SizedBox(width: 16),
              _buildThresholdIndicator("Critical", Colors.red, state.relativeFlexion >= 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdIndicator(String label, Color color, bool isActive) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.grey,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildRawIMUData(AppState state) {
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
          const Row(
            children: [
              Icon(Icons.sensors, color: Colors.purple),
              SizedBox(width: 8),
              Text("Raw IMU Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildIMUColumn("Pelvis", state.pelvisPitch, state.pelvisRoll, state.pelvisYaw, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildIMUColumn("Lumbar", state.lumbarPitch, state.lumbarRoll, state.lumbarYaw, Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIMUColumn(String label, double pitch, double roll, double yaw, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _buildIMURow("Pitch", pitch, color),
          _buildIMURow("Roll", roll, color),
          _buildIMURow("Yaw", yaw, color),
        ],
      ),
    );
  }

  Widget _buildIMURow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text("${value.toStringAsFixed(1)}°", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMotionAnalysisSection(dynamic data) {
    final analysis = _analyzer.checkThresholds(data);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBackgroundColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: analysis['isSafe'] ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: analysis['isSafe'] ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                analysis['isSafe'] ? 'All Movements Safe' : 'Motion Warnings Detected',
                style: TextStyle(color: analysis['isSafe'] ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (analysis['warnings'].isNotEmpty) ...[
            ...analysis['warnings'].map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(warning, style: const TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            )),
          ],
          if (analysis['danger'].isNotEmpty) ...[
            const SizedBox(height: 8),
            ...analysis['danger'].map((danger) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.error, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(danger, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
            )),
          ],
          if (analysis['warnings'].isEmpty && analysis['danger'].isEmpty)
            const Text('All movements within safe limits.', style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      ),
    );
  }

  void _showBiomechanicsInfo(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.biotech, color: Colors.blue),
            SizedBox(width: 8),
            Text('System Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('IMU Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildInfoRow('Pelvis IMU', 'L4/L5 Reference Sensor', Colors.blue),
              _buildInfoRow('Lumbar IMU', 'T12/L1 Upper Sensor', Colors.green),
              const SizedBox(height: 16),
              const Text('Current Data:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Pelvis: P${state.pelvisPitch.toStringAsFixed(1)}° R${state.pelvisRoll.toStringAsFixed(1)}° Y${state.pelvisYaw.toStringAsFixed(1)}°'),
              Text('Lumbar: P${state.lumbarPitch.toStringAsFixed(1)}° R${state.lumbarRoll.toStringAsFixed(1)}° Y${state.lumbarYaw.toStringAsFixed(1)}°'),
              Text('Relative Flexion: ${state.relativeFlexion.toStringAsFixed(1)}°', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('State: ${state.getPostureStateString()}', style: TextStyle(color: state.getMotionSafetyColor())),
              const SizedBox(height: 16),
              const Text('Filter Stack:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Complementary Filter (β=0.03)', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('• SHOE ZUPT Detector (N=5)', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('• Quaternion-based Orientation', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
                Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}