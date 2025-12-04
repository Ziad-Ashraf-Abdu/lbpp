import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/constants.dart';

class SpineVisualizer extends StatelessWidget {
  final double flexionAngle; // Forward bending
  final double lateralAngle; // Side bending (optional visualization)

  const SpineVisualizer({
    super.key,
    required this.flexionAngle,
    this.lateralAngle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
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
  }
}

class _SpinePainter extends CustomPainter {
  final double angle;
  final Color color;

  _SpinePainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // We draw the spine as a quadratic bezier curve to simulate bending
    final Path path = Path();

    // Start point (Sacrum/Pelvis - bottom center)
    final double startX = size.width / 2;
    final double startY = size.height * 0.9;

    path.moveTo(startX, startY);

    // Calculate the end point (Thorax/T12) based on the angle
    // - A positive angle means bending forward (assuming viewing from side or abstract)
    // - We simplify the visualization: 0 degrees is straight up.

    // Convert degrees to radians for trig functions
    // We dampen the visual effect slightly so it stays on screen (angle * 1.5 pixels)
    final double radian = (angle - 90) * (math.pi / 180.0);

    // Control point for the curve (Mid-lumbar)
    // As angle increases, the control point moves out to create the "C" shape curve
    double curveFactor = angle * 2.5;

    // End point (Top of lumbar spine)
    // We simply shift the top X coordinate based on the angle to show "lean"
    double endX = startX + curveFactor;
    double endY = size.height * 0.1;

    // Control point creates the bend
    double controlX = startX + (curveFactor * 0.5);
    double controlY = size.height * 0.5;

    // Draw a quadratic bezier to look like a bending spine
    path.quadraticBezierTo(controlX, controlY, endX, endY);

    // Draw the main spine curve
    canvas.drawPath(path, paint);

    // Draw vertebrae (dots/segments along the path)
    _drawVertebrae(canvas, path, paint);
  }

  void _drawVertebrae(Canvas canvas, Path path, Paint mainPaint) {
    // Draw 5 distinct lumbar vertebrae (L1-L5) along the curve
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // This is a simplified visualization. In a full implementation,
    // we would calculate points along the bezier curve.
    // For now, we just draw the base.
    
    // Visual embellishment: Draw a "Base" for the sacrum
    // Safely accessing path bounds
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
    return oldDelegate.angle != angle || oldDelegate.color != color;
  }
}