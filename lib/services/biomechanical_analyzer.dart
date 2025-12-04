import 'package:vector_math/vector_math.dart';
import '../models/biomechanical_data.dart';

class BiomechanicalAnalyzer {

  /// Calculate relative angles between two IMUs
  SpineKinematics calculateKinematics(
      IMUSensorData upper,
      IMUSensorData lower,
      ) {
    // Calculate relative angles (using vector math)
    final relativeFlexion = upper.pitch - lower.pitch;
    final relativeExtension = -(upper.pitch - lower.pitch); // Invert for extension

    final relativeLateralBend = upper.roll - lower.roll;
    final relativeRotation = upper.yaw - lower.yaw;

    // Normalize rotation to -180 to 180 degrees
    final normalizedRotation = _normalizeAngle(relativeRotation);

    // Estimate compression from vertical acceleration difference
    final compression = _estimateCompression(upper, lower);

    return SpineKinematics(
      upperSensor: upper,
      lowerSensor: lower,
      timestamp: DateTime.now(),
      relativeFlexion: relativeFlexion > 0 ? relativeFlexion : 0,
      relativeExtension: relativeExtension > 0 ? relativeExtension : 0,
      relativeLateralBend: relativeLateralBend.abs(),
      relativeRotation: normalizedRotation.abs(),
      estimatedCompression: compression,
    );
  }

  /// Normalize angle to -180 to 180 degrees
  double _normalizeAngle(double angle) {
    angle %= 360;
    if (angle > 180) angle -= 360;
    if (angle < -180) angle += 360;
    return angle;
  }

  /// Estimate spinal compression from acceleration data
  double _estimateCompression(IMUSensorData upper, IMUSensorData lower) {
    // Simple model: Compression correlates with vertical acceleration difference
    // In real implementation, this would use more sophisticated biomechanical model
    final verticalAccelDiff = (upper.accelZ - lower.accelZ).abs();

    // Normalize to 0-100% scale (dummy calculation - needs calibration)
    final compression = (verticalAccelDiff * 10).clamp(0.0, 100.0);
    return compression;
  }

  /// Check if motion exceeds safe thresholds
  Map<String, dynamic> checkThresholds(SpineKinematics kinematics) {
    final warnings = <String>[];
    final danger = <String>[];

    // Check flexion
    if (kinematics.relativeFlexion > MotionThresholds.maxSafeFlexion * 0.8) {
      warnings.add('High flexion detected');
    }
    if (kinematics.relativeFlexion > MotionThresholds.maxSafeFlexion) {
      danger.add('Dangerous flexion level!');
    }

    // Check extension
    if (kinematics.relativeExtension > MotionThresholds.maxSafeExtension * 0.8) {
      warnings.add('High extension detected');
    }
    if (kinematics.relativeExtension > MotionThresholds.maxSafeExtension) {
      danger.add('Dangerous extension level!');
    }

    // Check lateral bending
    if (kinematics.relativeLateralBend > MotionThresholds.maxSafeLateralBend * 0.8) {
      warnings.add('High lateral bending detected');
    }
    if (kinematics.relativeLateralBend > MotionThresholds.maxSafeLateralBend) {
      danger.add('Dangerous lateral bending!');
    }

    // ✅ ADD ROTATION CHECKS - RIGHT HERE:
    // Check rotation (twist)
    if (kinematics.relativeRotation > 10.0) { // Warning threshold
      warnings.add('High rotation detected: ${kinematics.relativeRotation.toStringAsFixed(1)}°');
    }
    if (kinematics.relativeRotation > 15.0) { // Danger threshold
      danger.add('Dangerous rotation level: ${kinematics.relativeRotation.toStringAsFixed(1)}°');
    }

    // Check compression
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

  /// Generate dummy data for testing (matching IMU data structure)
  SpineKinematics generateDummyData() {
    final now = DateTime.now();

    // Simulate normal standing posture with slight rotation
    final upperSensor = IMUSensorData(
      sensorId: 'upper',
      timestamp: now,
      pitch: 5.0,    // Slight forward tilt
      roll: 2.0,     // Slight right tilt
      yaw: 3.0,      // ✅ ADDED: Slight right rotation
      accelX: 0.1,
      accelY: 0.0,
      accelZ: 9.8,   // Gravity
    );

    final lowerSensor = IMUSensorData(
      sensorId: 'lower',
      timestamp: now,
      pitch: 0.0,    // Reference (vertical)
      roll: 0.0,     // Reference
      yaw: 0.0,      // Reference
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 9.8,
    );

    return calculateKinematics(upperSensor, lowerSensor);
  }

  /// Generate dummy data with variations for testing
  SpineKinematics generateVaryingDummyData(int count) {
    final now = DateTime.now();

    // Create varying data based on count
    final upperSensor = IMUSensorData(
      sensorId: 'upper',
      timestamp: now,
      pitch: 5.0 + (count % 20).toDouble() * 0.5, // Vary between 5-15°
      roll: 2.0 + (count % 10).toDouble() * 0.3,  // Vary between 2-5°
      yaw: 3.0 + (count % 15).toDouble() * 0.2,   // ✅ ADDED: Vary rotation 3-6°
      accelX: 0.1,
      accelY: 0.0,
      accelZ: 9.8,
    );

    final lowerSensor = IMUSensorData(
      sensorId: 'lower',
      timestamp: now,
      pitch: 0.0,
      roll: 0.0,
      yaw: 0.0,
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 9.8,
    );

    return calculateKinematics(upperSensor, lowerSensor);
  }
}