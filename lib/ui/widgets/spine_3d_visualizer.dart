import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' as vector;
import '../../models/biomechanical_data.dart';
import '../../providers/app_state.dart';
import 'package:provider/provider.dart';

/// 3D visualization of human spine with IMU data overlay
class Spine3DVisualizer extends StatelessWidget {
  final double width;
  final double height;
  final bool showSideView; 

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
              
              if (kinematics == null)
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

    double lateralBend = kinematics?.relativeLateralBend ?? 0;
    
    double radians = lateralBend * (pi / 180.0);
    
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
