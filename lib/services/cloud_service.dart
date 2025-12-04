// lib/services/cloud_service.dart - CORRECTED
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/constants.dart';
import '../models/biomechanical_data.dart';

class CloudService {
  // Sends lumbar angle data window to Dockerized ML model [cite: 203]
  Future<void> sendTelemetry(List<double> motionWindow) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.CLOUD_ENDPOINT),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "data": motionWindow,
          "timestamp": DateTime.now().toIso8601String(),
          "type": "lumbar_angle",
        }),
      );

      if (response.statusCode != 200) {
        print("Cloud Sync Failed: ${response.statusCode}");
      } else {
        print("✅ Lumbar telemetry sent successfully");
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  // Send biomechanical alert data to cloud
  Future<void> sendBiomechanicalAlert(Map<String, dynamic> alertData) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/alerts'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          ...alertData,
          "alert_type": "biomechanical",
          "device_id": "spine_monitor_001",
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Biomechanical alert sent to cloud");
      } else {
        print("⚠️ Alert send failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error sending alert: $e");
    }
  }

  // Send complete spine kinematics data
  Future<void> sendSpineKinematics(SpineKinematics kinematics) async {
    try {
      final data = {
        "timestamp": kinematics.timestamp.toIso8601String(),
        "flexion": kinematics.relativeFlexion,
        "extension": kinematics.relativeExtension,
        "lateral_bend": kinematics.relativeLateralBend,
        "rotation": kinematics.relativeRotation,
        "compression": kinematics.estimatedCompression,
        "upper_sensor": {
          "pitch": kinematics.upperSensor.pitch,
          "roll": kinematics.upperSensor.roll,
          "yaw": kinematics.upperSensor.yaw,
          "accel_x": kinematics.upperSensor.accelX,
          "accel_y": kinematics.upperSensor.accelY,
          "accel_z": kinematics.upperSensor.accelZ,
        },
        "lower_sensor": {
          "pitch": kinematics.lowerSensor.pitch,
          "roll": kinematics.lowerSensor.roll,
          "yaw": kinematics.lowerSensor.yaw,
          "accel_x": kinematics.lowerSensor.accelX,
          "accel_y": kinematics.lowerSensor.accelY,
          "accel_z": kinematics.lowerSensor.accelZ,
        },
        "type": "spine_kinematics",
      };

      final response = await http.post(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/kinematics'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print("✅ Spine kinematics sent to cloud");
      } else {
        print("⚠️ Kinematics send failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error sending kinematics: $e");
    }
  }

  // Send batch IMU data for analysis
  Future<void> sendIMUDataBatch(List<IMUSensorData> imuData) async {
    try {
      final formattedData = imuData.map((sensor) => {
        "sensor_id": sensor.sensorId,
        "timestamp": sensor.timestamp.toIso8601String(),
        "pitch": sensor.pitch,
        "roll": sensor.roll,
        "yaw": sensor.yaw,
        "acceleration": {
          "x": sensor.accelX,
          "y": sensor.accelY,
          "z": sensor.accelZ,
        }
      }).toList();

      final response = await http.post(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/imu_batch'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "imu_data": formattedData,
          "batch_size": imuData.length,
          "type": "imu_batch",
        }),
      );

      if (response.statusCode == 200) {
        print("✅ IMU batch data sent (${imuData.length} records)");
      } else {
        print("⚠️ IMU batch send failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error sending IMU batch: $e");
    }
  }

  // Get motion thresholds from cloud (for dynamic updates)
  Future<Map<String, dynamic>> getMotionThresholds() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/thresholds'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Loaded motion thresholds from cloud");
        return data;
      } else {
        print("⚠️ Failed to load thresholds: ${response.statusCode}");
        return {};
      }
    } catch (e) {
      print("Network Error loading thresholds: $e");
      return {};
    }
  }

  // Send posture summary for daily report
  Future<void> sendPostureSummary({
    required DateTime date,
    required int totalReadings,
    required int dangerousPostures,
    required int warningPostures,
    required double avgFlexion,
    required double avgCompression,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/summary'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "date": date.toIso8601String(),
          "total_readings": totalReadings,
          "dangerous_postures": dangerousPostures,
          "warning_postures": warningPostures,
          "avg_flexion": avgFlexion,
          "avg_compression": avgCompression,
          "posture_score": _calculatePostureScore(
            dangerousPostures,
            warningPostures,
            totalReadings,
            avgFlexion,
          ),
          "type": "daily_summary",
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Posture summary sent for ${date.toLocal().toString().split(' ')[0]}");
      } else {
        print("⚠️ Summary send failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error sending summary: $e");
    }
  }

  // Helper: Calculate posture score (0-100)
  double _calculatePostureScore(
      int dangerous,
      int warnings,
      int total,
      double avgFlexion,
      ) {
    if (total == 0) return 100.0;

    final dangerPenalty = (dangerous / total) * 50;
    final warningPenalty = (warnings / total) * 25;
    final flexionPenalty = avgFlexion > 30 ? (avgFlexion - 30) * 0.5 : 0;

    final score = 100 - dangerPenalty - warningPenalty - flexionPenalty;
    return score.clamp(0.0, 100.0);
  }

  // Check cloud connectivity
  Future<bool> checkCloudConnection() async {
    try {
      final response = await http.get(
        Uri.parse(AppConstants.CLOUD_ENDPOINT),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print("Cloud connection check failed: $e");
      return false;
    }
  }

  // Test cloud service
  Future<void> testCloudConnection() async {
    print("Testing cloud connection...");

    // Test 1: Basic connectivity
    final isConnected = await checkCloudConnection();
    print("Cloud connected: $isConnected");

    if (isConnected) {
      // Test 2: Send test telemetry
      await sendTelemetry([10.5, 15.2, 12.8, 18.3, 14.7]);

      // Test 3: Send test biomechanics data
      final testAlert = {
        'timestamp': DateTime.now().toIso8601String(),
        'flexion': 45.5,
        'extension': 5.2,
        'lateral_bend': 12.3,
        'compression': 75.8,
        'warnings': ['High flexion detected', 'High compression'],
        'danger': [],
      };
      await sendBiomechanicalAlert(testAlert);

      print("✅ Cloud service tests completed");
    } else {
      print("⚠️ Cloud endpoint is unreachable. Check your connection.");
    }
  }

  // Simple ping to check if service is alive
  Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/ping'),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Upload session data
  Future<bool> uploadSessionData(Map<String, dynamic> sessionData) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.CLOUD_ENDPOINT}/sessions'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(sessionData),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print("Session upload failed: $e");
      return false;
    }
  }
}