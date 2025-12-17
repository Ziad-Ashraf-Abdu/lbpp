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
  final bool showSideView; // Added to toggle view

  const Spine3DVisualizer({
    Key? key,
    this.width = 300,
    this.height = 400,
    this.showSideView = false,
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
              if (!showSideView)
                Center(
                  child: SizedBox(
                    width: width * 0.8,
                    height: height * 0.8,
                    child: CustomPaint(
                      painter: _BackViewPainter(kinematics: kinematics),
                      size: Size.infinite,
                    ),
                  ),
                ),
              if (showSideView)
                Center(
                  child: SizedBox(
                    width: width * 0.8,
                    height: height * 0.8,
                    child: CustomPaint(
                      painter: _SideViewPainter(kinematics: kinematics),
                      size: Size.infinite,
                    ),
                  ),
                ),
              
              if (kinematics != null)
                Positioned(
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
      child: Column(
        children: [
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
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

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
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5 
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final bottomY = size.height * 0.85;

    double flexion = kinematics?.relativeFlexion ?? 0;
    double extension = kinematics?.relativeExtension ?? 0;
    double angleDegrees = flexion - extension;
    
    double radians = angleDegrees * (pi / 180.0);
    
    canvas.drawLine(Offset(centerX - 20, bottomY), Offset(centerX + 20, bottomY), paint);
    
    final path = Path();
    path.moveTo(centerX, bottomY);
    
    double spineLength = size.height * 0.7;
    
    double topX = centerX + (spineLength * sin(radians));
    double topY = bottomY - (spineLength * cos(radians));
    
    double controlX = centerX + (spineLength * 0.5 * sin(radians * 0.5));
    double controlY = bottomY - (spineLength * 0.5 * cos(radians * 0.5));

    path.quadraticBezierTo(controlX, controlY, topX, topY);
    canvas.drawPath(path, paint);
    
    canvas.drawCircle(Offset(topX, topY), 10, Paint()..color = Colors.white..style = PaintingStyle.fill);
    
    canvas.drawLine(
        Offset(topX, topY), 
        Offset(topX + 15 * cos(radians), topY + 15 * sin(radians)), 
        Paint()..color = Colors.white..strokeWidth = 3
    );
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Flexion Label
    textPainter.text = const TextSpan(
      children: [
        TextSpan(text: "Flexion\n", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
        TextSpan(text: "(To the Front)", style: TextStyle(color: Colors.blue, fontSize: 10)),
      ],
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - 80, size.height / 2));
    
    // Extension Label
    textPainter.text = const TextSpan(
      children: [
        TextSpan(text: "Extension\n", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
        TextSpan(text: "(To the Back)", style: TextStyle(color: Colors.orange, fontSize: 10)),
      ],
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, size.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BackViewPainter extends CustomPainter {
  final SpineKinematics? kinematics;

  _BackViewPainter({this.kinematics});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final bottomY = size.height * 0.85;

    // Use lateral bend for back view moving line
    double lateralBend = kinematics?.relativeLateralBend ?? 0;
    
    // Convert to radians (Positive = Right, Negative = Left)
    double radians = lateralBend * (pi / 180.0);
    
    // Base (Pelvis)
    canvas.drawLine(Offset(centerX - 20, bottomY), Offset(centerX + 20, bottomY), paint);
    
    final path = Path();
    path.moveTo(centerX, bottomY);
    
    double spineLength = size.height * 0.7;
    
    // Top point (Head position) - rotating around the bottom center
    double topX = centerX + (spineLength * sin(radians));
    double topY = bottomY - (spineLength * cos(radians));
    
    // Curved line effect
    double controlX = centerX + (spineLength * 0.5 * sin(radians * 0.5));
    double controlY = bottomY - (spineLength * 0.5 * cos(radians * 0.5));

    path.quadraticBezierTo(controlX, controlY, topX, topY);
    canvas.drawPath(path, paint);
    
    // Head/Top Node
    canvas.drawCircle(Offset(topX, topY), 10, Paint()..color = Colors.white..style = PaintingStyle.fill);
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Left Label
    textPainter.text = const TextSpan(
      children: [
        TextSpan(text: "Bend Left\n", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        TextSpan(text: "(To the Left)", style: TextStyle(color: Colors.green, fontSize: 10)),
      ],
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, size.height / 2));
    
    // Right Label
    textPainter.text = const TextSpan(
      children: [
        TextSpan(text: "Bend Right\n", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
        TextSpan(text: "(To the Right)", style: TextStyle(color: Colors.blue, fontSize: 10)),
      ],
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - 85, size.height / 2));
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
    double lateralBend = kinematics?.relativeLateralBend ?? 0;
    double rotation = kinematics?.relativeRotation ?? 0;
    double compression = kinematics?.estimatedCompression ?? 0;

    _drawSacrum(canvas, centerX, bottomY);

    double currentY = bottomY - 20;
    double unitHeight = 45.0 * (1.0 - (compression / 200.0).clamp(0.0, 0.2));

    for (int i = 5; i >= 1; i--) {
      double levelFactor = (6 - i) / 5.0;
      double levelRotation = rotation * levelFactor;
      double ySpacing = unitHeight * (1.0 - (flexion.abs() / 150.0));
      
      double bendCurve = pow(levelFactor, 1.5).toDouble();
      double drawX = centerX + (lateralBend * 4.0 * bendCurve);
      
      if (i < 5) {
        _drawDisc(canvas, drawX, currentY + (unitHeight/2), levelRotation);
      }

      _drawVertebra(canvas, drawX, currentY, i, levelRotation);
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
    path.moveTo(x - 35, y);
    path.lineTo(x + 35, y);
    path.lineTo(x + 15, y + 50);
    path.lineTo(x - 15, y + 50);
    path.close();

    canvas.drawPath(path, paint);
    
    final detailPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawPath(path, detailPaint);
  }

  void _drawVertebra(Canvas canvas, double x, double y, int level, double rotationDegrees) {
    double widthBase = 60.0 + (level * 2.0);
    double heightBase = 35.0;

    double radians = rotationDegrees * vector.degrees2Radians;
    double visibleWidth = widthBase * cos(radians).abs();
    if (visibleWidth < 20) visibleWidth = 20;
    
    final rect = Rect.fromCenter(center: Offset(x, y), width: visibleWidth, height: heightBase);
    
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.grey[200]!, Colors.grey[400]!],
        stops: [0.2, 1.0],
      ).createShader(rect);

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
    
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: "L$level",
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - visibleWidth/2 - 25, y - 6));
  }

  void _drawDisc(Canvas canvas, double x, double y, double rotation) {
    double width = 50.0 * cos(rotation * vector.degrees2Radians).abs();
    if (width < 15) width = 15;
    
    final rect = Rect.fromCenter(center: Offset(x, y), width: width, height: 12);
    
    final paint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.6);

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
