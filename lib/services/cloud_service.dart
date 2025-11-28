import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/constants.dart';

class CloudService {
  // Sends kinematic data window to Dockerized ML model [cite: 203]
  Future<void> sendTelemetry(List<double> motionWindow) async {
  try {
  final response = await http.post(
  Uri.parse(AppConstants.CLOUD_ENDPOINT),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({
  "data": motionWindow,
  "timestamp": DateTime.now().toIso8601String(),
  }),
  );
  if (response.statusCode != 200) {
  print("Cloud Sync Failed: ${response.statusCode}");
  }
  } catch (e) {
  print("Network Error: $e");
  }
  }
}