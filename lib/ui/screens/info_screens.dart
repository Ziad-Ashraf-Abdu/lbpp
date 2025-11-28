import 'package:flutter/material.dart';

enum InfoType { legal, about, contact }

class InfoScreen extends StatelessWidget {
  final InfoType type;

  const InfoScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    String title = "";
    Widget content = const SizedBox();

    switch (type) {
      case InfoType.legal:
        title = "Legal & Privacy";
        content = _buildLegalContent();
        break;
      case InfoType.about:
        title = "About Us";
        content = _buildAboutContent();
        break;
      case InfoType.contact:
        title = "Contact Support";
        content = _buildContactContent();
        break;
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: content,
      ),
    );
  }

  Widget _buildLegalContent() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Terms of Service", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text("By using this Smart Spine Monitor, you agree that the data provided is for informational purposes only and does not constitute medical advice.", style: TextStyle(color: Colors.grey)),
        SizedBox(height: 20),
        Text("Privacy Policy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text("We collect anonymized kinematic data to improve our machine learning models. Your personal activation key is encrypted locally.", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildAboutContent() {
    return const Column(
      children: [
        Icon(Icons.monitor_heart, size: 80, color: Colors.blue),
        SizedBox(height: 20),
        Text("Smart Spine Monitor", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text("Version 1.0.0 (BETA)", style: TextStyle(color: Colors.grey)),
        SizedBox(height: 30),
        Text("A research-backed injury prevention system designed to monitor lumbar spine kinematics in real-time. Developed using Flutter, ESP32, and Advanced Sensor Fusion.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildContactContent() {
    return Column(
      children: [
        _buildContactCard(Icons.email, "Email Support", "support@smartspine.com"),
        const SizedBox(height: 10),
        _buildContactCard(Icons.web, "Website", "www.smartspine.com"),
        const SizedBox(height: 10),
        _buildContactCard(Icons.location_on, "Headquarters", "Cairo University, Faculty of Engineering"),
      ],
    );
  }

  Widget _buildContactCard(IconData icon, String title, String detail) {
    return Card(
      color: Colors.white10,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(detail, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}