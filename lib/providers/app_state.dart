import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/ble_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_service.dart';

class AppState extends ChangeNotifier {
  final BleService _bleService = BleService();
  final EncryptionService _cryptoService = EncryptionService();
  final CloudService _cloudService = CloudService();

  String? _activationKey;
  BleStatus _connectionStatus = BleStatus.disconnected;
  double _lumbarAngle = 0.0;
  List<double> _dataBuffer = [];

  // Getters
  BleStatus get connectionStatus => _connectionStatus;
  double get lumbarAngle => _lumbarAngle;
  bool get isConnected => _connectionStatus == BleStatus.connected;

  AppState() {
    _listenToBle();
  }

  void setActivationKey(String key) {
    _activationKey = key;
    _cryptoService.init(key); // Initialize encryption with key
    notifyListeners();
  }

  void startConnection() {
    if (_activationKey != null) {
      _bleService.scanAndHandshake(_activationKey!);
    }
  }

  void disconnect() {
    _bleService.disconnect();
  }

  void _listenToBle() {
    // Listen to Status
    _bleService.statusStream.listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });

    // Listen to Data
    _bleService.dataStream.listen((encryptedData) {
      if (encryptedData.isNotEmpty) {
        _processData(encryptedData);
      }
    });
  }

  void _processData(List<int> rawData) {
    // Note: In a real scenario, extract IV from packet.
    // Here we assume rawData is the payload for demo.
    // var decrypted = _cryptoService.decryptPacket(Uint8List.fromList(rawData), myIV);

    // Simulating parsing the angle from the decrypted bytes
    // Assume first byte is integer angle for simplicity of this snippet
    if (rawData.isNotEmpty) {
      // Updating angle for Real-time Visualization [cite: 200]
      _lumbarAngle = rawData[0].toDouble();

      // Buffer for Cloud [cite: 203]
      _dataBuffer.add(_lumbarAngle);
      if (_dataBuffer.length > 50) {
        _cloudService.sendTelemetry(List.from(_dataBuffer));
        _dataBuffer.clear();
      }

      notifyListeners();
    }
  }
}