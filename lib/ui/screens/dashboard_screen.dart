import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ble_service.dart';
import '../../config/constants.dart';
import '../../services/biomechanical_analyzer.dart';
import '../../ui/widgets/spine_3d_visualizer.dart';
import '../widgets/main_drawer.dart';

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
    // Use a Consumer at a higher level to react to state changes for the whole screen
    return Consumer<AppState>(
      builder: (context, state, child) {
        final displayData = state.currentSpineKinematics;

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
              if (displayData != null)
                IconButton(
                  icon: const Icon(Icons.biotech),
                  onPressed: () => _showBiomechanicsInfo(context, displayData),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildConnectionCard(state),
                          const SizedBox(height: 16),

                          // Use a ternary operator to handle the null case for data-dependent widgets
                          if (displayData != null) ...[
                            _buildBiomechanicsCard(displayData),
                            const SizedBox(height: 16),
                            const Expanded(child: Spine3DVisualizer()),
                            const SizedBox(height: 16),
                            _buildMotionAnalysisSection(displayData),
                            const SizedBox(height: 16),
                          ] else ...[
                            // Show a loading/waiting view until data arrives
                            const Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 20),
                                    Text('Waiting for IMU data...', 
                                         style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          if (!state.isConnected)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ElevatedButton.icon(
                                icon: state.connectionStatus == BleStatus.scanning
                                    ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
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
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("System Status", style: TextStyle(color: Colors.grey)),
              Text(state.isConnected ? "Live Monitoring" : "Waiting for Connection",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
            child: const Row(children: [
              Icon(Icons.sensors, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text("2 IMUs", style: TextStyle(color: Colors.blue, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomechanicsCard(dynamic data) {
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
          const Row(children: [
            Icon(Icons.biotech, color: Colors.blue),
            SizedBox(width: 8),
            Text("Biomechanical Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
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
          width: 37, height: 37,
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
        Text(label.length > 8 ? label.split(' ')[0] : label, 
             style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildMotionAnalysisSection(dynamic data) {
    final analysis = _analyzer.checkThresholds(data);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: analysis['isSafe'] ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: analysis['isSafe'] ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(analysis['isSafe'] ? 'All Motions Within Safe Limits' : 'Motion Warnings Detected',
              style: TextStyle(color: analysis['isSafe'] ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 12),
          if (analysis['warnings'].isNotEmpty) ...[
            ...analysis['warnings'].map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(warning, style: TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            )),
          ],
          if (analysis['danger'].isNotEmpty) ...[
            const SizedBox(height: 8),
            ...analysis['danger'].map((danger) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.error, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(danger, style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
            )),
          ],
          if (analysis['warnings'].isEmpty && analysis['danger'].isEmpty)
            const Text('All spine movements are within safe biomechanical limits.', style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      ),
    );
  }

  void _showBiomechanicsInfo(BuildContext context, dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.biotech, color: Colors.blue), SizedBox(width: 8), Text('Biomechanics Information')]),
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildSensorInfo(String name, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
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
