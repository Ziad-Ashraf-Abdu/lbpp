import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import '../services/ble_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_service.dart';
import '../models/biomechanical_data.dart'; // Add this import
import '../services/biomechanical_analyzer.dart'; // Add this import

class AppState extends ChangeNotifier {
  final BleService _bleService = BleService();
  final EncryptionService _cryptoService = EncryptionService();
  final CloudService _cloudService = CloudService();
  final BiomechanicalAnalyzer _biomechanicalAnalyzer = BiomechanicalAnalyzer(); // Add analyzer

  String? _activationKey;
  BleStatus _connectionStatus = BleStatus.disconnected;
  double _lumbarAngle = 0.0;
  List<double> _dataBuffer = [];

  // New biomechanical data fields
  SpineKinematics? _currentSpineKinematics;
  List<SpineKinematics> _spineHistory = [];
  Map<String, dynamic> _motionAnalysis = {};
  bool _useDummyData = true; // Start with dummy data
  bool _isBiomechanicsActive = false;

  StreamSubscription? _dummyDataSubscription;

  // Getters
  BleStatus get connectionStatus => _connectionStatus;
  double get lumbarAngle => _lumbarAngle;
  bool get isConnected => _connectionStatus == BleStatus.connected;

  // New getters for biomechanical data
  SpineKinematics? get currentSpineKinematics => _currentSpineKinematics;
  List<SpineKinematics> get spineHistory => _spineHistory;
  Map<String, dynamic> get motionAnalysis => _motionAnalysis;
  bool get useDummyData => _useDummyData;
  bool get isBiomechanicsActive => _isBiomechanicsActive;

  AppState() {
    _listenToBle();
    _initializeBiomechanics(); // Initialize biomechanics
  }

  @override
  void dispose() {
    _dummyDataSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  void setActivationKey(String key) {
    _activationKey = key;
    _cryptoService.init(key); // Initialize encryption with key
    notifyListeners();
  }

  void startConnection() {
    if (_activationKey == null) {
      // Set a default key if none exists (e.g., when bypassing ActivationScreen)
      setActivationKey("LBPP-DEMO-KEY-2024");
    }
    _bleService.scanAndHandshake(_activationKey!);
  }

  void disconnect() {
    _bleService.disconnect();
  }

  // New methods for biomechanical features
  void toggleDummyData() {
    _useDummyData = !_useDummyData;
    if (_useDummyData) {
      _startDummyDataStream();
    } else {
      _stopDummyDataStream();
    }
    notifyListeners();
  }

  void toggleBiomechanics() {
    _isBiomechanicsActive = !_isBiomechanicsActive;
    if (_isBiomechanicsActive && _useDummyData) {
      _startDummyDataStream();
    }
    notifyListeners();
  }

  void _initializeBiomechanics() {
    // Start with dummy data
    if (_useDummyData) {
      _currentSpineKinematics = _biomechanicalAnalyzer.generateDummyData();
      _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(_currentSpineKinematics!);
      _startDummyDataStream();
    } else {
      _currentSpineKinematics = null;
      _motionAnalysis = {};
    }
  }

  void _startDummyDataStream() {
    _dummyDataSubscription?.cancel(); // Ensure no multiple subscriptions
    _dummyDataSubscription = _bleService.getMockIMUData().listen((kinematics) {
      if (!_useDummyData) return; // Only process if we are in dummy mode

      _currentSpineKinematics = kinematics;
      _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);

      // Add to history (keep last 100 readings)
      _spineHistory.add(kinematics);
      if (_spineHistory.length > 100) {
        _spineHistory.removeAt(0);
      }

      notifyListeners();
    });
  }

  void _stopDummyDataStream() {
    _dummyDataSubscription?.cancel();
    _dummyDataSubscription = null;
  }

  void _updateRealtimeKinematics(SpineKinematics kinematics) {
    _currentSpineKinematics = kinematics;
    _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);

    // Add to history
    _spineHistory.add(kinematics);
    if (_spineHistory.length > 100) {
      _spineHistory.removeAt(0);
    }

    // Send to cloud if compression is high
    if (kinematics.estimatedCompression > 70) {
      _sendBiomechanicalAlert();
    }

    notifyListeners();
  }

  void _sendBiomechanicalAlert() {
    if (_currentSpineKinematics != null) {
      final alertData = {
        'timestamp': DateTime.now().toIso8601String(),
        'flexion': _currentSpineKinematics!.relativeFlexion,
        'extension': _currentSpineKinematics!.relativeExtension,
        'lateral_bend': _currentSpineKinematics!.relativeLateralBend,
        'compression': _currentSpineKinematics!.estimatedCompression,
        'warnings': _motionAnalysis['warnings'],
        'danger': _motionAnalysis['danger'],
      };

      _cloudService.sendBiomechanicalAlert(alertData);
    }
  }

  void clearBiomechanicsHistory() {
    _spineHistory.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> getBiomechanicsSummary() {
    if (_spineHistory.isEmpty) return [];

    final dangerousReadings = _spineHistory.where(
            (k) => _biomechanicalAnalyzer.checkThresholds(k)['danger'].isNotEmpty
    ).length;

    final warningReadings = _spineHistory.where(
            (k) => _biomechanicalAnalyzer.checkThresholds(k)['warnings'].isNotEmpty
    ).length;

    final avgFlexion = _spineHistory.map((k) => k.relativeFlexion).reduce((a, b) => a + b) / _spineHistory.length;
    final avgCompression = _spineHistory.map((k) => k.estimatedCompression).reduce((a, b) => a + b) / _spineHistory.length;

    return [
      {'label': 'Total Readings', 'value': _spineHistory.length.toString()},
      {'label': 'Dangerous Postures', 'value': dangerousReadings.toString()},
      {'label': 'Warning Postures', 'value': warningReadings.toString()},
      {'label': 'Avg. Flexion', 'value': '${avgFlexion.toStringAsFixed(1)}°'},
      {'label': 'Avg. Compression', 'value': '${avgCompression.toStringAsFixed(1)}%'},
    ];
  }

  void _listenToBle() {
    // Listen to Status
    _bleService.statusStream.listen((status) {
      _connectionStatus = status;
      
      if (status == BleStatus.connected) {
        _useDummyData = false; // Switch to real data when connected
        _stopDummyDataStream(); // Stop dummy data
        // Clear the screen to wait for real data
        _currentSpineKinematics = null;
      } else if (status == BleStatus.disconnected) {
        _useDummyData = true;
        _initializeBiomechanics();
      }
      
      notifyListeners();
    });

    // Listen to Data and DECRYPT IT
    _bleService.dataStream.listen((encryptedData) {
      if (encryptedData.isNotEmpty && !_useDummyData) {
        // 1. DECRYPT THE DATA using the updated service
        final decryptedData = _cryptoService.decrypt(Encrypted(Uint8List.fromList(encryptedData)));
        
        // 2. PROCESS THE DECRYPTED STRING
        if (decryptedData.isNotEmpty) {
          _processData(decryptedData);
        }
      }
    });
  }

  void _processData(String dataString) {
    try {
      final parts = dataString.trim().split(',');

      if (parts.length >= 6) {
        final upperPitch = double.tryParse(parts[0]) ?? 0.0;
        final upperRoll = double.tryParse(parts[1]) ?? 0.0;
        final upperYaw = double.tryParse(parts[2]) ?? 0.0;
        final lowerPitch = double.tryParse(parts[3]) ?? 0.0;
        final lowerRoll = double.tryParse(parts[4]) ?? 0.0;
        final lowerYaw = double.tryParse(parts[5]) ?? 0.0;

        final upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: DateTime.now(),
          pitch: upperPitch, roll: upperRoll, yaw: upperYaw,
          accelX: 0.0, accelY: 0.0, accelZ: 9.8, 
        );

        final lowerIMU = IMUSensorData(
          sensorId: 'lower',
          timestamp: DateTime.now(),
          pitch: lowerPitch, roll: lowerRoll, yaw: lowerYaw,
          accelX: 0.0, accelY: 0.0, accelZ: 9.8, 
        );

        final kinematics = _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
        _updateRealtimeKinematics(kinematics);
      }
    } catch (e) {
      debugPrint("Error processing decrypted data: $e");
    }
  }

  // Method to manually update kinematics (for testing)
  void updateKinematicsManually(SpineKinematics kinematics) {
    _currentSpineKinematics = kinematics;
    _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);
    notifyListeners();
  }

  // Get color based on motion safety
  Color getMotionSafetyColor() {
    if (_motionAnalysis['danger']?.isNotEmpty == true) {
      return Colors.red;
    } else if (_motionAnalysis['warnings']?.isNotEmpty == true) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  // Get safety status text
  String getMotionSafetyText() {
    if (_motionAnalysis['danger']?.isNotEmpty == true) {
      return 'Dangerous Posture';
    } else if (_motionAnalysis['warnings']?.isNotEmpty == true) {
      return 'Warning - Check Posture';
    } else {
      return 'Safe Posture';
    }
  }
}