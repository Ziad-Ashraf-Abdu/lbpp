import 'package:flutter/material.dart';
import '../screens/account_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/info_screens.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. User Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
              image: DecorationImage(
                image: NetworkImage("https://www.transparenttextures.com/patterns/carbon-fibre.png"),
                fit: BoxFit.cover,
                opacity: 0.2,
              ),
            ),
            accountName: const Text("Active User", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Device ID: ESP32-S3-BETA"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.grey[800]),
            ),
          ),

          // 2. Navigation Items
          _buildDrawerItem(context, Icons.dashboard, "Dashboard", null), // Closes drawer
          _buildDrawerItem(context, Icons.person, "My Account", const AccountScreen()),
          _buildDrawerItem(context, Icons.tune, "Customization", const SettingsScreen()),

          const Divider(color: Colors.white24),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text("Information", style: TextStyle(color: Colors.grey)),
          ),

          _buildDrawerItem(context, Icons.gavel, "Legal & Privacy", const InfoScreen(type: InfoType.legal)),
          _buildDrawerItem(context, Icons.info_outline, "About Us", const InfoScreen(type: InfoType.about)),
          _buildDrawerItem(context, Icons.contact_support, "Contact Support", const InfoScreen(type: InfoType.contact)),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, Widget? destination) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context); // Close drawer first
        if (destination != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        }
      },
    );
  }
}