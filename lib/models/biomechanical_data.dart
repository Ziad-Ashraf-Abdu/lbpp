// Create: lib/models/biomechanical_data.dart

/// Represents data from a single IMU sensor
class IMUSensorData {
  final String sensorId; // "upper" or "lower"
  final DateTime timestamp;

  // Raw IMU data (in degrees)
  final double pitch;    // Forward/backward tilt (-90 to 90)
  final double roll;     // Left/right tilt (-90 to 90)
  final double yaw;      // Rotation (0 to 360)

  // Acceleration data (for compression estimation)
  final double accelX;
  final double accelY;
  final double accelZ;

  IMUSensorData({
    required this.sensorId,
    required this.timestamp,
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });
}

/// Combined data from both IMUs with calculated relative angles
class SpineKinematics {
  final IMUSensorData upperSensor; // T12/L1
  final IMUSensorData lowerSensor; // L4/L5 (reference)
  final DateTime timestamp;

  // Relative angles between sensors (lower sensor as reference)
  final double relativeFlexion;    // Positive = forward bending
  final double relativeExtension;  // Negative = backward bending
  final double relativeLateralBend; // Positive = bend to right
  final double relativeRotation;    // Positive = rotate clockwise

  // Estimated compression (derived from vertical acceleration/position)
  final double estimatedCompression; // Percentage of max

  SpineKinematics({
    required this.upperSensor,
    required this.lowerSensor,
    required this.timestamp,
    required this.relativeFlexion,
    required this.relativeExtension,
    required this.relativeLateralBend,
    required this.relativeRotation,
    required this.estimatedCompression,
  });
}

/// Medical thresholds for safe spine movements
class MotionThresholds {
  // In degrees - based on biomechanical literature
  static const double maxSafeFlexion = 60.0;     // Max forward bend
  static const double maxSafeExtension = 30.0;   // Max backward bend
  static const double maxSafeLateralBend = 30.0; // Max side bend
  static const double maxSafeRotation = 30.0;    // Max rotation

  // Compression thresholds (percentage of body weight)
  static const double warningCompression = 70.0; // 70% of max
  static const double dangerCompression = 85.0;  // 85% of max
}