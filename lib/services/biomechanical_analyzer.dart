// lib/services/biomechanical_analyzer.dart

import 'package:vector_math/vector_math.dart';
import '../models/biomechanical_data.dart';
import '../utils/moving_average.dart'; // Import the new utility

class BiomechanicalAnalyzer {
  // Create instances of the moving average filter for each kinematic value
  final _flexionSmoother = MovingAverage(windowSize: 10);
  final _extensionSmoother = MovingAverage(windowSize: 10);
  final _lateralBendSmoother = MovingAverage(windowSize: 10);
  final _rotationSmoother = MovingAverage(windowSize: 10);
  final _compressionSmoother = MovingAverage(windowSize: 10);


  /// Calculate relative angles between two IMUs, now with smoothing
  SpineKinematics calculateKinematics(
      IMUSensorData upper,
      IMUSensorData lower,
      ) {
    // --- Step 1: Calculate raw relative angles ---
    final rawRelativeFlexion = upper.pitch - lower.pitch;
    final rawRelativeExtension = -(upper.pitch - lower.pitch);
    final rawRelativeLateralBend = upper.roll - lower.roll;
    final rawRelativeRotation = upper.yaw - lower.yaw;
    final rawCompression = _estimateCompression(upper, lower);
    final normalizedRotation = _normalizeAngle(rawRelativeRotation);

    // --- Step 2: Pass raw values through the smoothing filters ---
    final smoothFlexion = _flexionSmoother.add(rawRelativeFlexion > 0 ? rawRelativeFlexion : 0);
    final smoothExtension = _extensionSmoother.add(rawRelativeExtension > 0 ? rawRelativeExtension : 0);
    final smoothLateralBend = _lateralBendSmoother.add(rawRelativeLateralBend.abs());
    final smoothRotation = _rotationSmoother.add(normalizedRotation.abs());
    final smoothCompression = _compressionSmoother.add(rawCompression);

    // --- Step 3: Return kinematics object with smoothed data ---
    return SpineKinematics(
      upperSensor: upper,
      lowerSensor: lower,
      timestamp: DateTime.now(),
      relativeFlexion: smoothFlexion,
      relativeExtension: smoothExtension,
      relativeLateralBend: smoothLateralBend,
      relativeRotation: smoothRotation,
      estimatedCompression: smoothCompression,
    );
  }

  // ... (rest of the file remains the same: _normalizeAngle, _estimateCompression, checkThresholds, etc.)
  /// Normalize angle to -180 to 180 degrees
  double _normalizeAngle(double angle) {
    angle %= 360;
    if (angle > 180) angle -= 360;
    if (angle < -180) angle += 360;
    return angle;
  }

  /// Estimate spinal compression from acceleration data
  double _estimateCompression(IMUSensorData upper, IMUSensorData lower) {
    final verticalAccelDiff = (upper.accelZ - lower.accelZ).abs();
    final compression = (verticalAccelDiff * 10).clamp(0.0, 100.0);
    return compression;
  }

  /// Check if motion exceeds safe thresholds
  Map<String, dynamic> checkThresholds(SpineKinematics kinematics) {
    final warnings = <String>[];
    final danger = <String>[];

    if (kinematics.relativeFlexion > MotionThresholds.maxSafeFlexion * 0.8) {
      warnings.add('High flexion detected');
    }
    if (kinematics.relativeFlexion > MotionThresholds.maxSafeFlexion) {
      danger.add('Dangerous flexion level!');
    }

    if (kinematics.relativeExtension > MotionThresholds.maxSafeExtension * 0.8) {
      warnings.add('High extension detected');
    }
    if (kinematics.relativeExtension > MotionThresholds.maxSafeExtension) {
      danger.add('Dangerous extension level!');
    }

    if (kinematics.relativeLateralBend > MotionThresholds.maxSafeLateralBend * 0.8) {
      warnings.add('High lateral bending detected');
    }
    if (kinematics.relativeLateralBend > MotionThresholds.maxSafeLateralBend) {
      danger.add('Dangerous lateral bending!');
    }

    if (kinematics.relativeRotation > 10.0) {
      warnings.add('High rotation detected: ${kinematics.relativeRotation.toStringAsFixed(1)}°');
    }
    if (kinematics.relativeRotation > 15.0) {
      danger.add('Dangerous rotation level: ${kinematics.relativeRotation.toStringAsFixed(1)}°');
    }

    if (kinematics.estimatedCompression > MotionThresholds.warningCompression) {
      warnings.add('High spinal compression');
    }
    if (kinematics.estimatedCompression > MotionThresholds.dangerCompression) {
      danger.add('Dangerous compression level!');
    }

    return {
      'warnings': warnings,
      'danger': danger,
      'isSafe': danger.isEmpty,
    };
  }

  SpineKinematics generateDummyData() {
    final now = DateTime.now();
    final upperSensor = IMUSensorData(sensorId: 'upper', timestamp: now, pitch: 5.0, roll: 2.0, yaw: 3.0, accelX: 0.1, accelY: 0.0, accelZ: 9.8);
    final lowerSensor = IMUSensorData(sensorId: 'lower', timestamp: now, pitch: 0.0, roll: 0.0, yaw: 0.0, accelX: 0.0, accelY: 0.0, accelZ: 9.8);
    return calculateKinematics(upperSensor, lowerSensor);
  }
}

