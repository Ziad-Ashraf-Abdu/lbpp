import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _key = TextEditingController();
  bool _isHovering = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    if (_name.text.isNotEmpty && _key.text.isNotEmpty) {
      // Pass data to AppState - This updates the MainDrawer and sets the AES key
      context.read<AppState>().initializeUser(_name.text.trim(), _key.text.trim());

      // Start connection logic
      context.read<AppState>().startConnection();

      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text("Incomplete Credentials: Sensor link requires Name and Key."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Deep space black
      body: Stack(
        children: [
          // Background Aesthetic Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.05),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeController,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // High-tech Icon
                      const Icon(Icons.hub_outlined, size: 60, color: Colors.blueAccent),
                      const SizedBox(height: 24),

                      const Text(
                        "System Login",
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Secure link to Smart Spine hardware required.",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),

                      const SizedBox(height: 50),

                      // Username Input
                      _buildTextField(
                        controller: _name,
                        label: "OPERATOR NAME",
                        icon: Icons.person_outline,
                        hint: "Enter your name",
                      ),

                      const SizedBox(height: 30),

                      // Activation Key Input
                      _buildTextField(
                        controller: _key,
                        label: "ACTIVATION CODE",
                        icon: Icons.vpn_key_outlined,
                        hint: "XXXX-XXXX-XXXX",
                        isPassword: true,
                        helper: "Unique ESP32-S3 Encryption Key",
                      ),

                      const SizedBox(height: 60),

                      // Sign In Button
                      MouseRegion(
                        onEnter: (_) => setState(() => _isHovering = true),
                        onExit: (_) => setState(() => _isHovering = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(_isHovering ? 0.4 : 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _handleSignIn,
                            child: const Text(
                              "ESTABLISH LINK",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          "AES-128 END-TO-END ENCRYPTED",
                          style: TextStyle(
                            color: Colors.white12,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.blueAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white10),
            prefixIcon: Icon(icon, color: Colors.white24, size: 20),
            helperText: helper,
            helperStyle: const TextStyle(color: Colors.white24, fontSize: 11),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}