// lib/ui/widgets/spine_3d_visualizer.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' as vector;
import '../../models/biomechanical_data.dart';

// NOTE: The overlay logic has been completely removed from this widget.
class Spine3DVisualizer extends StatefulWidget {
  final SpineKinematics? kinematics;

  const Spine3DVisualizer({
    Key? key,
    this.kinematics,
  }) : super(key: key);

  @override
  State<Spine3DVisualizer> createState() => _Spine3DVisualizerState();
}

class _Spine3DVisualizerState extends State<Spine3DVisualizer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            // Background grid
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _GridPainter(),
            ),

            // Main spine visualization
            CustomPaint(
              painter: _RealisticSpinePainter(
                kinematics: widget.kinematics,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),

            // Side View (Flexion/Extension Helper)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text("Side View", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ),
                    Expanded(
                      child: CustomPaint(
                        painter: _SideViewPainter(kinematics: widget.kinematics),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // The data overlay has been moved to dashboard_screen.dart
            if (widget.kinematics == null)
              const Center(
                child: Text(
                  'Waiting for IMU data...',
                  style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      }),
    );
  }
}

// All painter classes (_GridPainter, _SideViewPainter, _RealisticSpinePainter) remain exactly the same.
// ... (rest of the painter code is unchanged)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (double i = 0; i <= size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    paint.color = Colors.white.withOpacity(0.1);
    canvas.drawLine(Offset(size.width/2, 0), Offset(size.width/2, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SideViewPainter extends CustomPainter {
  final SpineKinematics? kinematics;
  _SideViewPainter({this.kinematics});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final centerX = size.width / 3;
    final bottomY = size.height * 0.85;
    double flexion = kinematics?.relativeFlexion ?? 0;
    double extension = kinematics?.relativeExtension ?? 0;
    double angleDegrees = flexion - extension;
    double radians = angleDegrees * (pi / 180.0);
    canvas.drawLine(Offset(centerX - 10, bottomY), Offset(centerX + 10, bottomY), paint);
    final path = Path();
    path.moveTo(centerX, bottomY);
    double spineLength = size.height * 0.6;
    double topX = centerX + (spineLength * sin(radians));
    double topY = bottomY - (spineLength * cos(radians));
    double controlX = centerX + (spineLength * 0.5 * sin(radians * 0.5));
    double controlY = bottomY - (spineLength * 0.5 * cos(radians * 0.5));
    path.quadraticBezierTo(controlX, controlY, topX, topY);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(topX, topY), 5, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawLine(Offset(topX, topY), Offset(topX + 8 * cos(radians), topY + 8 * sin(radians)), Paint()..color = Colors.white..strokeWidth = 1.5);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: "Fwd", style: TextStyle(color: Colors.blue.withOpacity(0.5), fontSize: 8));
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - 25, size.height / 2));
    textPainter.text = TextSpan(text: "Back", style: TextStyle(color: Colors.orange.withOpacity(0.5), fontSize: 8));
    textPainter.layout();
    textPainter.paint(canvas, Offset(2, size.height / 2));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RealisticSpinePainter extends CustomPainter {
  final SpineKinematics? kinematics;
  _RealisticSpinePainter({this.kinematics});
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bottomY = size.height * 0.85;
    double flexion = kinematics?.relativeFlexion ?? 0;
    double extension = kinematics?.relativeExtension ?? 0;
    double lateralBend = kinematics?.relativeLateralBend ?? 0;
    double rotation = kinematics?.relativeRotation ?? 0;
    double compression = kinematics?.estimatedCompression ?? 0;
    _drawSacrum(canvas, centerX, bottomY);
    double currentY = bottomY - 20;
    double unitHeight = 45.0 * (1.0 - (compression / 200.0).clamp(0.0, 0.2));
    for (int i = 5; i >= 1; i--) {
      double levelFactor = (6 - i) / 5.0;
      double xOffset = lateralBend * 3.0 * levelFactor;
      double levelRotation = rotation * levelFactor;
      double ySpacing = unitHeight * (1.0 - (flexion.abs() / 150.0));
      double bendCurve = pow(levelFactor, 1.5).toDouble();
      double drawX = centerX + (lateralBend * 4.0 * bendCurve);
      if (i < 5) {
        _drawDisc(canvas, drawX, currentY + (unitHeight/2), levelRotation);
      }
      _drawVertebra(canvas, drawX, currentY, i, levelRotation, flexion, extension);
      currentY -= ySpacing;
    }
  }

  void _drawSacrum(Canvas canvas, double x, double y) {
    final paint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.grey[300]!, Colors.grey[600]!]).createShader(Rect.fromCenter(center: Offset(x, y + 20), width: 80, height: 60));
    final path = Path();
    path.moveTo(x - 35, y);
    path.lineTo(x + 35, y);
    path.lineTo(x + 15, y + 50);
    path.lineTo(x - 15, y + 50);
    path.close();
    canvas.drawPath(path, paint);
    final detailPaint = Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawPath(path, detailPaint);
  }

  void _drawVertebra(Canvas canvas, double x, double y, int level, double rotationDegrees, double flexion, double extension) {
    double widthBase = 60.0 + (level * 2.0);
    double heightBase = 35.0;
    double radians = rotationDegrees * vector.degrees2Radians;
    double visibleWidth = widthBase * cos(radians).abs();
    if (visibleWidth < 20) visibleWidth = 20;
    final rect = Rect.fromCenter(center: Offset(x, y), width: visibleWidth, height: heightBase);
    final paint = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey[200]!, Colors.grey[400]!], stops: [0.2, 1.0]).createShader(rect);
    RRect rRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rRect, paint);
    canvas.drawRRect(rRect, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1.5);
    double processOffset = -1.0 * (widthBase * 0.4) * sin(radians);
    double processX = x + processOffset;
    double processY = y;
    canvas.drawLine(Offset(x - visibleWidth/4, y), Offset(processX, processY), Paint()..color=Colors.grey[500]!..strokeWidth=4);
    canvas.drawLine(Offset(x + visibleWidth/4, y), Offset(processX, processY), Paint()..color=Colors.grey[500]!..strokeWidth=4);
    final processRect = Rect.fromCenter(center: Offset(processX, processY), width: 18, height: 22);
    final processPaint = Paint()..color = Colors.grey[300]!;
    canvas.drawOval(processRect, processPaint);
    canvas.drawOval(processRect, Paint()..color=Colors.black38..style=PaintingStyle.stroke..strokeWidth=1);
    TextPainter textPainter = TextPainter(text: TextSpan(text: "L$level", style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - visibleWidth/2 - 25, y - 6));
    if (rotationDegrees.abs() > 5) {
      Paint arrowPaint = Paint()..color = rotationDegrees > 0 ? Colors.redAccent : Colors.blueAccent ..style=PaintingStyle.stroke..strokeWidth=2;
    }
  }

  void _drawDisc(Canvas canvas, double x, double y, double rotation) {
    double width = 50.0 * cos(rotation * vector.degrees2Radians).abs();
    if (width < 15) width = 15;
    final rect = Rect.fromCenter(center: Offset(x, y), width: width, height: 12);
    final paint = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.6);
    canvas.drawOval(rect, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
