import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Personal Information", style: TextStyle(fontSize: 18, color: Colors.blueAccent)),
              const SizedBox(height: 20),

              _buildTextField("Full Name", Icons.person),
              const SizedBox(height: 15),
              _buildTextField("Email Address", Icons.email),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(child: _buildTextField("Height (cm)", Icons.height)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField("Weight (kg)", Icons.monitor_weight)),
                ],
              ),

              const SizedBox(height: 40),
              const Text("Device Security", style: TextStyle(fontSize: 18, color: Colors.blueAccent)),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: "1234567890abcdef",
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Activation Key (Active)",
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white10,
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Profile Updated Successfully")),
                    );
                  },
                  child: const Text("Save Changes"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white10,
      ),
    );
  }
}