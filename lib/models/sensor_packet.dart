import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

class SensorPacket {
  final double flexionAngle;      // Sagittal plane (Forward/Back)
  final double lateralBendAngle;  // Frontal plane (Side-to-side)
  final double twistAngle;        // Transverse plane (Rotation)
  final int timestamp;            // For synchronization
  final double batteryLevel;      // System health


  SensorPacket({
    required this.flexionAngle,
    required this.lateralBendAngle,
    required this.twistAngle,
    required this.timestamp,
    required this.batteryLevel,
  });

  /// Factory to parse raw decrypted bytes from the ESP32.
  /// Assumes a standard struct format (e.g., 3 floats + 1 int + 1 byte)
  factory SensorPacket.fromBytes(List<int> bytes) {
    final buffer = Uint8List.fromList(bytes).buffer;
    final data = ByteData.view(buffer);

    // Byte layout assumption (matches typical C++ struct packing):
    // 0-3: Flexion (Float32)
    // 4-7: Lateral (Float32)
    // 8-11: Twist (Float32)
    // 12-15: Timestamp (Uint32)
    // 16: Battery (Uint8)

    try {
      if (bytes.length < 17) {
        // Fallback or throw error if packet is incomplete
        return SensorPacket.empty();
      }

      return SensorPacket(
        flexionAngle: data.getFloat32(0, Endian.little),
        lateralBendAngle: data.getFloat32(4, Endian.little),
        twistAngle: data.getFloat32(8, Endian.little),
        timestamp: data.getUint32(12, Endian.little),
        batteryLevel: data.getUint8(16).toDouble(),
      );
    } catch (e) {
      print("Packet Parsing Error: $e");
      return SensorPacket.empty();
    }
  }

  factory SensorPacket.empty() {
    return SensorPacket(
      flexionAngle: 0.0,
      lateralBendAngle: 0.0,
      twistAngle: 0.0,
      timestamp: 0,
      batteryLevel: 0.0,
    );
  }

  // Helper to get a List for the Cloud API
  List<double> toFeatureVector() {
    return [flexionAngle, lateralBendAngle, twistAngle];
  }
}