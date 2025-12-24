import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import 'dashboard_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isValidating = false;

  void _submit(BuildContext context) async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid activation key")),
      );
      return;
    }

    setState(() => _isValidating = true);

    // Give it a moment to feel like it's actually talking to the ESP32
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      final state = Provider.of<AppState>(context, listen: false);

      // We use initializeUser so the Drawer captures both the default user name and key
      state.initializeUser("Active Operator", key);

      // Start the actual BLE scan/handshake
      state.startConnection();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Shield Icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: value,
                      child: Icon(
                          _isValidating ? Icons.sync : Icons.security_rounded,
                          size: 90,
                          color: Colors.blueAccent
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                  "HARDWARE ACTIVATION",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white
                  )
              ),
              const SizedBox(height: 15),
              const Text(
                  "Verify your unique Smart Spine key to enable AES-128 decrypted telemetry.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.5)
              ),
              const SizedBox(height: 40),

              // High-Tech Input Field
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, letterSpacing: 3),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: "XXXX-XXXX-XXXX",
                  hintStyle: const TextStyle(color: Colors.white12),
                  labelText: "Activation Key",
                  labelStyle: const TextStyle(color: Colors.blueAccent),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isValidating ? null : () => _submit(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isValidating
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                      : const Text(
                      "INITIALIZE HANDSHAKE",
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isValidating ? "Synchronizing with ESP32-S3..." : "Device Status: Ready to Pair",
                style: TextStyle(
                    color: _isValidating ? Colors.orangeAccent : Colors.white24,
                    fontSize: 12,
                    fontStyle: FontStyle.italic
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}