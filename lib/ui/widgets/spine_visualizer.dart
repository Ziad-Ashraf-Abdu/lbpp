import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../providers/app_state.dart';

class SpineVisualizer extends StatelessWidget {
  const SpineVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final kinematics = appState.currentSpineKinematics;
        final flexionAngle = kinematics?.relativeFlexion ?? 0.0;
        final lateralAngle = kinematics?.relativeLateralBend ?? 0.0;

        // Determine color based on paper thresholds
        Color spineColor = Colors.green;
        if (flexionAngle.abs() >= AppConstants.WARN_LIMIT) {
          spineColor = Colors.redAccent;
        } else if (flexionAngle.abs() >= AppConstants.SAFE_LIMIT) {
          spineColor = Colors.yellowAccent;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(200, 300),
              painter: _SpinePainter(
                angle: flexionAngle,
                lateral: lateralAngle,
                color: spineColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Lumbar Alignment",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpinePainter extends CustomPainter {
  final double angle;
  final double lateral;
  final Color color;

  _SpinePainter({required this.angle, required this.lateral, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    final double startX = size.width / 2;
    final double startY = size.height * 0.9;

    path.moveTo(startX, startY);

    // Flexion creates vertical/forward lean
    // Lateral creates horizontal shift
    double curveFactorX = (angle * 1.5) + (lateral * 2.0);
    double endX = startX + curveFactorX;
    double endY = size.height * 0.1;

    double controlX = startX + (curveFactorX * 0.5);
    double controlY = size.height * 0.5;

    path.quadraticBezierTo(controlX, controlY, endX, endY);
    canvas.drawPath(path, paint);
    _drawVertebrae(canvas, path, paint);
  }

  void _drawVertebrae(Canvas canvas, Path path, Paint mainPaint) {
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final bounds = path.getBounds();
    if (!bounds.isEmpty) {
        canvas.drawCircle(
            Offset(bounds.bottomCenter.dx, bounds.bottomCenter.dy),
            6,
            nodePaint
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SpinePainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.lateral != lateral || oldDelegate.color != color;
  }
}
