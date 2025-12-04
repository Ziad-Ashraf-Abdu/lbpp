import 'package:flutter/material.dart';
import '../../config/constants.dart';

class StatusGauge extends StatelessWidget {
  final double angle;
  final Color spineColor;

  const StatusGauge({super.key, required this.angle, required this.spineColor});

  @override
  Widget build(BuildContext context) {
    // Determine label based on angle
    String label;
    if (angle < AppConstants.SAFE_LIMIT) {
      label = "SAFE";
    } else if (angle < AppConstants.WARN_LIMIT) {
      label = "CAUTION";
    } else {
      label = "RISK";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "${angle.toStringAsFixed(1)}°",
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              color: spineColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2
          ),
        ),
      ],
    );
  }
}