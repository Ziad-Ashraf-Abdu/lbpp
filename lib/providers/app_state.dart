import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/ble_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_service.dart';
import '../models/biomechanical_data.dart';
import '../services/biomechanical_analyzer.dart';

class AppState extends ChangeNotifier {
  final BleService _bleService = BleService();
  final EncryptionService _cryptoService = EncryptionService();
  final CloudService _cloudService = CloudService();
  final BiomechanicalAnalyzer _biomechanicalAnalyzer = BiomechanicalAnalyzer();

  String? _activationKey;
  BleStatus _connectionStatus = BleStatus.disconnected;
  double _lumbarAngle = 0.0;

  int _packetCounter = 0;

  SpineKinematics? _currentSpineKinematics;
  List<SpineKinematics> _spineHistory = [];
  Map<String, dynamic> _motionAnalysis = {};
  bool _useDummyData = true;
  bool _isBiomechanicsActive = false;

  StreamSubscription? _dummyDataSubscription;

  BleStatus get connectionStatus => _connectionStatus;
  double get lumbarAngle => _lumbarAngle;
  bool get isConnected => _connectionStatus == BleStatus.connected;

  SpineKinematics? get currentSpineKinematics => _currentSpineKinematics;
  List<SpineKinematics> get spineHistory => _spineHistory;
  Map<String, dynamic> get motionAnalysis => _motionAnalysis;
  bool get useDummyData => _useDummyData;
  bool get isBiomechanicsActive => _isBiomechanicsActive;

  AppState() {
    _listenToBle();
    _initializeBiomechanics();
  }

  @override
  void dispose() {
    _dummyDataSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  void setActivationKey(String key) {
    _activationKey = key;
    _cryptoService.init(key);
    notifyListeners();
  }

  void startConnection() {
    if (_activationKey == null) {
      setActivationKey("LBPP-DEMO-KEY-2024");
    }
    _bleService.scanAndHandshake(_activationKey!);
  }

  void disconnect() {
    _bleService.disconnect();
  }

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
    _dummyDataSubscription?.cancel();
    _dummyDataSubscription = _bleService.getMockIMUData().listen((kinematics) {
      if (!_useDummyData) return;

      _currentSpineKinematics = kinematics;
      _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);

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

    _spineHistory.add(kinematics);
    if (_spineHistory.length > 100) {
      _spineHistory.removeAt(0);
    }

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

    final dangerousReadings = _spineHistory.where((k) => _biomechanicalAnalyzer.checkThresholds(k)['danger'].isNotEmpty).length;
    final warningReadings = _spineHistory.where((k) => _biomechanicalAnalyzer.checkThresholds(k)['warnings'].isNotEmpty).length;
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
    _bleService.statusStream.listen((status) {
      _connectionStatus = status;
      if (status == BleStatus.connected) {
        debugPrint("🔌 [AppState] Connected. Initializing encryption.");
        if (_activationKey != null) {
          _cryptoService.init(_activationKey!); 
        }
        _useDummyData = false;
        _stopDummyDataStream();
        _currentSpineKinematics = null;
      } else if (status == BleStatus.disconnected) {
        debugPrint("🔌 [AppState] Disconnected. Switching to dummy data.");
        _useDummyData = true;
        _initializeBiomechanics();
      }
      notifyListeners();
    });

    // Listen to Data, Decrypt it, and Process it
    _bleService.dataStream.listen((encryptedPacket) {
      if (encryptedPacket.isEmpty || _useDummyData) return;

      // Decrypt the entire packet. The service now correctly handles the IV stream.
      final String decryptedData = _cryptoService.decrypt(Uint8List.fromList(encryptedPacket));

      if (decryptedData.isNotEmpty) {
        // The ESP32 sends one complete CSV string per notification, without a newline.
        // We can process it directly.
        final line = decryptedData.trim();
        if (line.isNotEmpty) {
          _processData(line);
        }
      }
    });
  }

  void _processData(String dataString) {
    _packetCounter++;
    try {
      debugPrint("📊 [AppState] Processing line #$_packetCounter: $dataString");

      final parts = dataString.trim().split(',');
      if (parts.length >= 6) {
        final upperPitch = double.tryParse(parts[0]) ?? 0.0;
        final upperRoll = double.tryParse(parts[1]) ?? 0.0;
        final upperYaw = double.tryParse(parts[2]) ?? 0.0;
        final lowerPitch = double.tryParse(parts[3]) ?? 0.0;
        final lowerRoll = double.tryParse(parts[4]) ?? 0.0;
        final lowerYaw = double.tryParse(parts[5]) ?? 0.0;

        final upperIMU = IMUSensorData(sensorId: 'upper', timestamp: DateTime.now(), pitch: upperPitch, roll: upperRoll, yaw: upperYaw, accelX: 0.0, accelY: 0.0, accelZ: 9.8);
        final lowerIMU = IMUSensorData(sensorId: 'lower', timestamp: DateTime.now(), pitch: lowerPitch, roll: lowerRoll, yaw: lowerYaw, accelX: 0.0, accelY: 0.0, accelZ: 9.8);

        final kinematics = _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
        _updateRealtimeKinematics(kinematics);
      } else {
        debugPrint("❌ [AppState] Invalid packet format in line #$_packetCounter. Expected 6 values, got ${parts.length}. Data: '$dataString'");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AppState] Error processing line #$_packetCounter: $e");
      debugPrint("❌ [AppState] Stack trace: $stackTrace");
    }
  }

  void updateKinematicsManually(SpineKinematics kinematics) {
    _currentSpineKinematics = kinematics;
    _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);
    notifyListeners();
  }

  Color getMotionSafetyColor() {
    if (_motionAnalysis['danger']?.isNotEmpty == true) {
      return Colors.red;
    } else if (_motionAnalysis['warnings']?.isNotEmpty == true) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

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
