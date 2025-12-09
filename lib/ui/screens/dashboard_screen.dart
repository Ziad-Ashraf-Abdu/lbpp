// lib/ui/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';
import '../../models/biomechanical_data.dart';
import '../../services/biomechanical_analyzer.dart';
import '../../ui/widgets/spine_3d_visualizer.dart';
import '../widgets/main_drawer.dart';
import '../widgets/ai_model_placeholder.dart';

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
    final state = Provider.of<AppState>(context);
    final displayData = state.currentSpineKinematics ?? _analyzer.generateDummyData();

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text("Lumbar Monitor"),
        actions: [
          IconButton(
            icon: Icon(state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            color: state.isConnected ? Colors.blue : Colors.grey,
            onPressed: () => state.isConnected ? state.disconnect() : state.startConnection(),
          ),
          IconButton(
            icon: const Icon(Icons.biotech),
            onPressed: () => _showBiomechanicsInfo(context, displayData),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildConnectionCard(state),
              const SizedBox(height: 16),
              _buildBiomechanicsCard(displayData),
              const SizedBox(height: 16),

              // --- CHANGE IS HERE ---
              // A new Column to hold both the visualizer AND its data overlay below it.
              Column(
                children: [
                  AspectRatio(
                    aspectRatio: 0.85,
                    child: Spine3DVisualizer(kinematics: displayData),
                  ),
                  // The overlay is now here, placed slightly below the visualizer.
                  if (displayData != null)
                    Transform.translate(
                      offset: const Offset(0, -20), // Nudges the overlay up slightly to overlap the bottom edge
                      child: _buildDataOverlay(displayData),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const AIModelPlaceholder(),
              const SizedBox(height: 16),
              _buildMotionAnalysisSection(displayData),
              const SizedBox(height: 16),
              if (!state.isConnected) _buildConnectButton(state),
            ],
          ),
        ),
      ),
    );
  }

  // --- METHODS MOVED HERE FROM THE VISUALIZER WIDGET ---

  Widget _buildDataOverlay(SpineKinematics kinematics) {
    final analysis = _analyzer.checkThresholds(kinematics);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSensorDot('T12/L1', Colors.blue),
              const SizedBox(width: 20),
              _buildSensorDot('L4/L5', Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMotionIndicator('Flexion', kinematics.relativeFlexion, 60.0),
              _buildMotionIndicator('Ext', kinematics.relativeExtension, 30.0),
              _buildMotionIndicator('Bend', kinematics.relativeLateralBend, 30.0, isDirectional: true),
              _buildMotionIndicator('Rot', kinematics.relativeRotation, 30.0, isDirectional: true),
              _buildMotionIndicator('Comp', kinematics.estimatedCompression, 100.0),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: analysis['isSafe'] ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: analysis['isSafe'] ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  analysis['isSafe'] ? Icons.check_circle : Icons.warning,
                  color: analysis['isSafe'] ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  analysis['isSafe'] ? 'SAFE POSTURE' : 'POSTURE WARNING',
                  style: TextStyle(
                    color: analysis['isSafe'] ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMotionIndicator(String label, double value, double max, {bool isDirectional = false}) {
    final percentage = (value.abs() / max).clamp(0.0, 1.0);
    Color color;
    if (percentage < 0.7) {
      color = const Color(0xFF69F0AE);
    } else if (percentage < 0.85) {
      color = const Color(0xFFFFAB40);
    } else {
      color = const Color(0xFFFF5252);
    }
    String valueText = value.abs().toStringAsFixed(0);
    if (isDirectional && value.abs() > 1.0) {
      valueText += value > 0 ? " R" : " L";
    }
    return Column(
      children: [
        Text(
          valueText,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  // --- The rest of the file is unchanged ---
  Widget _buildConnectButton(AppState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: state.connectionStatus == BleStatus.scanning
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(state.connectionStatus == BleStatus.error ? Icons.refresh : Icons.bluetooth_searching),
        label: Text(state.connectionStatus == BleStatus.scanning
            ? "Scanning..."
            : state.connectionStatus == BleStatus.error
            ? "Scan Failed - Retry"
            : "Connect to Device"),
        onPressed: (state.connectionStatus == BleStatus.disconnected || state.connectionStatus == BleStatus.error)
            ? () => state.startConnection()
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: state.connectionStatus == BleStatus.error ? Colors.redAccent : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showBiomechanicsInfo(BuildContext context, SpineKinematics data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.biotech, color: Colors.blue),
            SizedBox(width: 8),
            Flexible(
              child: Text('Biomechanics Information'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('IMU Sensor Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSensorInfo('T12/L1 IMU', 'Upper sensor at thoracolumbar junction', Colors.blue),
              _buildSensorInfo('L4/L5 IMU', 'Lower reference sensor at lumbosacral junction', Colors.green),
              const SizedBox(height: 16),
              const Text('Current Reading:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Flexion: ${data.relativeFlexion.toStringAsFixed(1)}°'),
              Text('Extension: ${data.relativeExtension.toStringAsFixed(1)}°'),
              Text('Lateral Bend: ${data.relativeLateralBend.toStringAsFixed(1)}°'),
              Text('Rotation: ${data.relativeRotation.toStringAsFixed(1)}°'),
              Text('Compression: ${data.estimatedCompression.toStringAsFixed(1)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMotionAnalysisSection(SpineKinematics data) {
    final analysis = _analyzer.checkThresholds(data);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: analysis['isSafe'] ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: analysis['isSafe'] ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                analysis['isSafe'] ? 'All Motions Within Safe Limits' : 'Motion Warnings Detected',
                style: TextStyle(
                  color: analysis['isSafe'] ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (analysis['warnings'].isNotEmpty) ...[
            ...analysis['warnings'].map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning, style: const TextStyle(color: Colors.orange, fontSize: 12))),
                ],
              ),
            )),
          ],
          if (analysis['danger'].isNotEmpty) ...[
            const SizedBox(height: 8),
            ...analysis['danger'].map((danger) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(danger, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            )),
          ],
          if (analysis['warnings'].isEmpty && analysis['danger'].isEmpty)
            const Text(
              'All spine movements are within safe biomechanical limits.',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: state.isConnected ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monitor_heart, color: state.isConnected ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("System Status", style: TextStyle(color: Colors.grey)),
              Text(state.isConnected ? "Live Monitoring" : "Waiting for Connection", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.sensors, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Text("2 IMUs", style: TextStyle(color: Colors.blue, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomechanicsCard(SpineKinematics data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.biotech, color: Colors.blue),
              SizedBox(width: 8),
              Text("Biomechanical Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 8),
                _buildDataItem("Flexion", "${data.relativeFlexion.toStringAsFixed(1)}°", Colors.blue),
                const SizedBox(width: 12),
                _buildDataItem("Extension", "${data.relativeExtension.toStringAsFixed(1)}°", Colors.orange),
                const SizedBox(width: 12),
                _buildDataItem("Side Bend", "${data.relativeLateralBend.toStringAsFixed(1)}°", Colors.green),
                const SizedBox(width: 12),
                _buildDataItem("Rotation", "${data.relativeRotation.toStringAsFixed(1)}°", Colors.red),
                const SizedBox(width: 12),
                _buildDataItem("Compression", "${data.estimatedCompression.toStringAsFixed(1)}%", Colors.purple),
                const SizedBox(width: 8),
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
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(label.substring(0, 1), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(
          label.length > 8 ? label.split(' ')[0] : label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildSensorInfo(String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
