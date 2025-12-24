import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../screens/account_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/info_screens.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the state to get the username and connection status
    final state = context.watch<AppState>();

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. User Header (Updated with dynamic User Data)
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
              image: DecorationImage(
                image: NetworkImage("https://www.transparenttextures.com/patterns/carbon-fibre.png"),
                fit: BoxFit.cover,
                opacity: 0.2,
              ),
            ),
            // Replaced "Active User" with the real username from state
            accountName: Text(state.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            // Replaced static ID with dynamic status/ID
            accountEmail: Text(state.isConnected ? "ID: ESP32-S3-BETA (Active)" : "Device Offline"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.grey[800]),
            ),
          ),

          // 2. Navigation Items
          _buildDrawerItem(context, Icons.dashboard, "Dashboard", null),
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

          const Divider(color: Colors.white24),
          // Added Logout to handle session cleanup
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              state.disconnect();
              Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
            },
          ),
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