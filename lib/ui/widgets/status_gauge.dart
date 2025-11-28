import 'package:flutter/material.dart';
import '../../config/constants.dart';

class StatusGauge extends StatelessWidget {
  final double angle;

  const StatusGauge({super.key, required this.angle});

  @override
  Widget build(BuildContext context) {
    // Determine Color based on Thresholds [cite: 200]
    Color color;
    String label;
    if (angle < AppConstants.SAFE_LIMIT) {
      color = Colors.green;
      label = "SAFE";
    } else if (angle < AppConstants.WARN_LIMIT) {
      color = Colors.yellow;
      label = "CAUTION";
    } else {
      color = Colors.red;
      label = "RISK";
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: CircularProgressIndicator(
            value: angle.clamp(0.0, 45.0) / 45.0, // Normalize 0-45 degrees
            strokeWidth: 25,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${angle.toStringAsFixed(1)}°",
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        )
      ],
    );
  }
}