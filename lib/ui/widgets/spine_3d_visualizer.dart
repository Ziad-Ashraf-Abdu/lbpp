import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' as vector;
import '../../models/biomechanical_data.dart';
import '../../services/biomechanical_analyzer.dart';
import '../../providers/app_state.dart';
import 'package:provider/provider.dart';

/// 3D visualization of human spine with IMU data overlay
class Spine3DVisualizer extends StatelessWidget {
  final double width;
  final double height;

  const Spine3DVisualizer({
    Key? key,
    this.width = 300,
    this.height = 400,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final kinematics = appState.currentSpineKinematics;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildGrid(),
              CustomPaint(
                painter: _RealisticSpinePainter(
                  kinematics: kinematics,
                ),
                size: Size(width, height),
              ),
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
                          painter: _SideViewPainter(kinematics: kinematics),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (kinematics != null)
                Positioned(
                  // 1. INCREASED POSITION FROM TOP (20 -> 50)
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildDataOverlay(kinematics),
                )
              else
                const Center(
                  child: Text(
                    'Waiting for IMU data...',
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      size: Size(width, height),
      painter: _GridPainter(),
    );
  }

  Widget _buildDataOverlay(SpineKinematics kinematics) {
    final analyzer = BiomechanicalAnalyzer();
    final analysis = analyzer.checkThresholds(kinematics);

    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(2),
      // decoration: BoxDecoration(
      //   // 2. INCREASED OPACITY (0.8 -> 0.95)
      //   color: Colors.black.withOpacity(0.95),
      //   borderRadius: BorderRadius.circular(12),
      //   border: Border.all(color: Colors.white12),
      // ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

            ],
          ),
          const SizedBox(height: 10),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     _buildMotionIndicator('Flexion', kinematics.relativeFlexion, 60.0),
          //     _buildMotionIndicator('Ext', kinematics.relativeExtension, 30.0),
          //     _buildMotionIndicator('Bend', kinematics.relativeLateralBend, 30.0, isDirectional: true),
          //     _buildMotionIndicator('Rot', kinematics.relativeRotation, 30.0, isDirectional: true),
          //     _buildMotionIndicator('Comp', kinematics.estimatedCompression, 100.0),
          //   ],
          // ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: analysis['isSafe'] ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: analysis['isSafe'] ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  analysis['isSafe'] ? Icons.check_circle : Icons.warning,
                  color: analysis['isSafe'] ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  analysis['isSafe'] ? 'SAFE POSTURE' : 'POSTURE WARNING',
                  style: TextStyle(
                    color: analysis['isSafe'] ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMotionIndicator(String label, double value, double max, {bool isDirectional = false}) {
    final percentage = (value.abs() / max).clamp(0.0, 1.0);
    Color color;
    if (percentage < 0.7) {
      color = const Color(0xFF69F0AE); // Bright Green
    } else if (percentage < 0.85) {
      color = const Color(0xFFFFAB40); // Orange Accent
    } else {
      color = const Color(0xFFFF5252); // Red Accent
    }

    String valueText = value.abs().toStringAsFixed(0);
    if (isDirectional && value.abs() > 1.0) {
      valueText += value > 0 ? " R" : " L";
    }

    return Column(
      children: [
        Text(
          valueText,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Vertical lines
    for (double i = 0; i <= size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    // Horizontal lines
    for (double i = 0; i <= size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Center line
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
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 3; // Moved slightly left to allow forward bend space
    final bottomY = size.height * 0.85;

    // Calculate bend angle
    // Facing RIGHT: Flexion (Forward) rotates clockwise (+), Extension (Backward) rotates counter-clockwise (-)
    double flexion = kinematics?.relativeFlexion ?? 0;
    double extension = kinematics?.relativeExtension ?? 0;
    double angleDegrees = flexion - extension;

    // Convert to radians
    double radians = angleDegrees * (pi / 180.0);

    // Base (Pelvis)
    canvas.drawLine(Offset(centerX - 10, bottomY), Offset(centerX + 10, bottomY), paint);

    // Spine Curve
    final path = Path();
    path.moveTo(centerX, bottomY);

    double spineLength = size.height * 0.6;

    // Top point (Head position) based on angle
    // x = sin(angle)
    // y = cos(angle) up
    double topX = centerX + (spineLength * sin(radians));
    double topY = bottomY - (spineLength * cos(radians));

    // Control point to make it curved, not stick
    double controlX = centerX + (spineLength * 0.5 * sin(radians * 0.5));
    double controlY = bottomY - (spineLength * 0.5 * cos(radians * 0.5));

    path.quadraticBezierTo(controlX, controlY, topX, topY);
    canvas.drawPath(path, paint);

    // Head
    canvas.drawCircle(Offset(topX, topY), 5, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Direction Indicator (Nose pointing Right)
    // Rotated by the spine angle
    canvas.drawLine(
        Offset(topX, topY),
        Offset(topX + 8 * cos(radians), topY + 8 * sin(radians)),
        Paint()..color = Colors.white..strokeWidth = 1.5
    );

    // Labels
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

/// A more realistic painter for the Lumbar Spine
class _RealisticSpinePainter extends CustomPainter {
  final SpineKinematics? kinematics;

  _RealisticSpinePainter({this.kinematics});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bottomY = size.height * 0.85;

    // Kinematic values (default to 0 if null)
    double flexion = kinematics?.relativeFlexion ?? 0;
    double extension = kinematics?.relativeExtension ?? 0;
    double lateralBend = kinematics?.relativeLateralBend ?? 0;
    double rotation = kinematics?.relativeRotation ?? 0;
    double compression = kinematics?.estimatedCompression ?? 0;

    // Calculate scaling factors for visualization
    // Lateral Bend: Shift X coordinate
    // Rotation: Rotate the individual vertebrae rectangles
    // Flexion/Extension: Compress vertical space (perspective) + slight X/Y shift for curvature

    // Draw Sacrum (Base)
    _drawSacrum(canvas, centerX, bottomY);

    // Draw 5 Lumbar Vertebrae (L5 at bottom -> L1 at top)
    // We accumulate offsets as we go up
    double currentY = bottomY - 20; // Start above sacrum
    double currentX = centerX;

    // Height of one functional spinal unit (vertebra + disc)
    // Compress if compression value is high
    double unitHeight = 45.0 * (1.0 - (compression / 200.0).clamp(0.0, 0.2));

    for (int i = 5; i >= 1; i--) {
      // Calculate cumulative bend at this level
      // Lower vertebrae (L5, L4) move less than upper ones (L1, L2)
      double levelFactor = (6 - i) / 5.0; // 0.2 for L5, 1.0 for L1

      // Lateral curve offset
      // Exaggerated multiplier for visibility
      double xOffset = lateralBend * 3.0 * levelFactor;

      // Rotation at this level
      // Cumulative rotation: L5 rotates a little, L1 rotates the full amount
      double levelRotation = rotation * levelFactor;

      // Flexion effect: Forward bend "arches" the spine
      // In 2D posterior view, flexion often looks like vertical compression
      // or a slight vertical curve if we assume perspective.
      // We'll simulate flexion by spacing them closer (looking down)
      double ySpacing = unitHeight * (1.0 - (flexion.abs() / 150.0));

      // Calculate position for this vertebra
      // Using a slight quadratic curve for natural bending
      double bendCurve = pow(levelFactor, 1.5).toDouble();
      double drawX = centerX + (lateralBend * 4.0 * bendCurve);

      // Draw Disc below (except for L5 which sits on sacrum)
      if (i < 5) {
        _drawDisc(canvas, drawX, currentY + (unitHeight/2), levelRotation);
      }

      // Draw Vertebra
      _drawVertebra(canvas, drawX, currentY, i, levelRotation, flexion, extension);

      // Move up for next one
      currentY -= ySpacing;
    }
  }

  void _drawSacrum(Canvas canvas, double x, double y) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.grey[300]!, Colors.grey[600]!],
      ).createShader(Rect.fromCenter(center: Offset(x, y + 20), width: 80, height: 60));

    final path = Path();
    // Triangular shape for sacrum
    path.moveTo(x - 35, y); // Top Left
    path.lineTo(x + 35, y); // Top Right
    path.lineTo(x + 15, y + 50); // Bottom Right tip
    path.lineTo(x - 15, y + 50); // Bottom Left tip
    path.close();

    canvas.drawPath(path, paint);

    // Detail lines
    final detailPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(path, detailPaint);
  }

  void _drawVertebra(Canvas canvas, double x, double y, int level, double rotationDegrees, double flexion, double extension) {
    // L1 is smaller than L5 naturally
    double widthBase = 60.0 + (level * 2.0);
    double heightBase = 35.0;

    // Perspective transformation for Rotation
    // When rotated, width appears smaller
    double radians = rotationDegrees * vector.degrees2Radians;
    double visibleWidth = widthBase * cos(radians).abs();
    if (visibleWidth < 20) visibleWidth = 20; // Min width

    // Perspective for Flexion/Extension (Tilting)
    // Extension (leaning back) -> we see more of the "top" or front, looks taller?
    // Flexion (leaning forward) -> we see more of the "back", spinous process moves up?
    // Simplified: Flexion makes the body look slightly compressed vertically in this view

    final rect = Rect.fromCenter(center: Offset(x, y), width: visibleWidth, height: heightBase);

    // Body Paint (Bone color)
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.grey[200]!, Colors.grey[400]!],
        stops: [0.2, 1.0],
      ).createShader(rect);

    // Draw vertebral body (Main block)
    RRect rRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rRect, paint);

    // Outline
    canvas.drawRRect(rRect, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // DRAW SPINOUS PROCESS (The bump on the back)
    // This is crucial for visualizing rotation.
    // If rotated Left, spinous process moves Right.
    // If rotated Right, spinous process moves Left.

    // Calculate offset of spinous process based on rotation
    // The "back" moves opposite to the "front" face rotation
    double processOffset = -1.0 * (widthBase * 0.4) * sin(radians);

    double processX = x + processOffset;
    double processY = y; // Centered vertically usually

    // Draw Pedicles (connections)
    canvas.drawLine(Offset(x - visibleWidth/4, y), Offset(processX, processY), Paint()..color=Colors.grey[500]!..strokeWidth=4);
    canvas.drawLine(Offset(x + visibleWidth/4, y), Offset(processX, processY), Paint()..color=Colors.grey[500]!..strokeWidth=4);

    // Draw Process
    final processRect = Rect.fromCenter(center: Offset(processX, processY), width: 18, height: 22);
    final processPaint = Paint()..color = Colors.grey[300]!;
    canvas.drawOval(processRect, processPaint);
    canvas.drawOval(processRect, Paint()..color=Colors.black38..style=PaintingStyle.stroke..strokeWidth=1);

    // Label (L1, L2, etc.)
    // Draw text next to the vertebra so it doesn't get obscured by rotation
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: "L$level",
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - visibleWidth/2 - 25, y - 6));

    // Visual cue for "Twist" direction
    if (rotationDegrees.abs() > 5) {
      // Draw a small arrow near the process indicating movement
      Paint arrowPaint = Paint()..color = rotationDegrees > 0 ? Colors.redAccent : Colors.blueAccent ..style=PaintingStyle.stroke..strokeWidth=2;
      // Simplified visual cue
    }
  }

  void _drawDisc(Canvas canvas, double x, double y, double rotation) {
    // Disc is smaller, bluish/cartilage color
    double width = 50.0 * cos(rotation * vector.degrees2Radians).abs();
    if (width < 15) width = 15;

    final rect = Rect.fromCenter(center: Offset(x, y), width: width, height: 12);

    final paint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.6); // Light Blue transparent

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}