import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _safeLimit = 10.0;
  double _riskLimit = 15.0;
  bool _hapticEnabled = true;
  bool _cloudSync = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Customization")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Haptic Feedback"),
          SwitchListTile(
            title: const Text("Enable Vibration"),
            subtitle: const Text("Vibrate device when risk threshold is met"),
            value: _hapticEnabled,
            onChanged: (val) => setState(() => _hapticEnabled = val),
            secondary: const Icon(Icons.vibration, color: Colors.orange),
          ),

          const Divider(height: 30),
          _buildSectionHeader("Safety Thresholds"),
          const SizedBox(height: 10),

          const Text("Safe Zone Limit (Green)", style: TextStyle(color: Colors.grey)),
          Slider(
            value: _safeLimit,
            min: 5,
            max: 20,
            divisions: 15,
            label: "${_safeLimit.round()}°",
            activeColor: Colors.green,
            onChanged: (val) => setState(() => _safeLimit = val),
          ),

          const Text("Risk Zone Limit (Red)", style: TextStyle(color: Colors.grey)),
          Slider(
            value: _riskLimit,
            min: 15,
            max: 45,
            divisions: 30,
            label: "${_riskLimit.round()}°",
            activeColor: Colors.red,
            onChanged: (val) => setState(() => _riskLimit = val),
          ),

          const Divider(height: 30),
          _buildSectionHeader("Cloud & Data"),
          SwitchListTile(
            title: const Text("Sync to Cloud"),
            subtitle: const Text("Send anonymized data to AI model"),
            value: _cloudSync,
            onChanged: (val) => setState(() => _cloudSync = val),
            secondary: const Icon(Icons.cloud_upload, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
        letterSpacing: 1.2,
      ),
    );
  }
}