import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> with TickerProviderStateMixin {
  late AnimationController _swingController;
  late AnimationController _pulseController;
  int _messageIndex = 0;

  final List<String> _funnyMessages = [
    "WAKING UP THE VERTEBRAE...",
    "CONVINCING SENSORS TO COOPERATE...",
    "INJECTING CAFFEINE INTO THE CIRCUITRY...",
    "ALIGNING YOUR COSMIC ALIGNMENT...",
    "BANISHING BACK PAIN DEMONS...",
    "NEGOTIATING WITH THE ESP32...",
    "LOAD BALANCING THE UNIVERSE...",
    "SYSTEMS NOMINAL. MOSTLY."
  ];

  @override
  void initState() {
    super.initState();

    // Controller for the "Swinging" Spine effect
    _swingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Controller for the glowing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Cycle through funny messages
    Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (mounted && _messageIndex < _funnyMessages.length - 1) {
        setState(() => _messageIndex++);
      } else {
        t.cancel();
      }
    });

    // Navigate to Auth after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
    });
  }

  @override
  void dispose() {
    _swingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background Glow
          Center(
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.1, end: 0.3).animate(_pulseController),
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // THE SWINGING SPINAL CORD
                AnimatedBuilder(
                  animation: _swingController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: math.sin(_swingController.value * 2 * math.pi) * 0.15,
                      child: CustomPaint(
                        size: const Size(100, 200),
                        painter: SpinePainter(animationValue: _swingController.value),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 50),

                // HUMOROUS STATUS TERMINAL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _funnyMessages[_messageIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontFamily: 'Courier', // Monospace feel
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white10,
                          color: Colors.blueAccent,
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw the spinal vertebrae blocks
class SpinePainter extends CustomPainter {
  final double animationValue;
  SpinePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3;

    double centerX = size.width / 2;
    int segments = 8;
    double segmentHeight = size.height / segments;

    for (int i = 0; i < segments; i++) {
      // Logic to make each vertebrae follow the one above with a delay (swinging)
      double offset = math.sin((animationValue * 2 * math.pi) + (i * 0.4)) * 15;

      // Draw connecting line
      if (i < segments - 1) {
        double nextOffset = math.sin((animationValue * 2 * math.pi) + ((i + 1) * 0.4)) * 15;
        canvas.drawLine(
          Offset(centerX + offset, i * segmentHeight + 10),
          Offset(centerX + nextOffset, (i + 1) * segmentHeight),
          linePaint,
        );
      }

      // Draw vertebrae block
      Rect rect = Rect.fromCenter(
        center: Offset(centerX + offset, i * segmentHeight),
        width: 30 - (i * 2), // Tapers down
        height: 12,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}