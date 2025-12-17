import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/ble_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_service.dart';
import '../models/biomechanical_data.dart';
import '../services/biomechanical_analyzer.dart';

enum PostureState { safe, warning, critical }

class AppState extends ChangeNotifier {
  final BleService _bleService = BleService();
  final EncryptionService _cryptoService = EncryptionService();
  final CloudService _cloudService = CloudService();
  final BiomechanicalAnalyzer _biomechanicalAnalyzer = BiomechanicalAnalyzer();

  String? _activationKey;
  BleStatus _connectionStatus = BleStatus.disconnected;

  // ESP32 sends these directly now
  double _pelvisPitch = 0.0;
  double _pelvisRoll = 0.0;
  double _pelvisYaw = 0.0;
  double _lumbarPitch = 0.0;
  double _lumbarRoll = 0.0;
  double _lumbarYaw = 0.0;
  double _relativeFlexion = 0.0; // Calculated on ESP32
  PostureState _postureState = PostureState.safe;

  int _packetCounter = 0;

  SpineKinematics? _currentSpineKinematics;
  List<SpineKinematics> _spineHistory = [];
  Map<String, dynamic> _motionAnalysis = {};
  bool _useDummyData = true;
  bool _isBiomechanicsActive = false;

  StreamSubscription? _dummyDataSubscription;

  // Getters
  BleStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == BleStatus.connected;

  double get pelvisPitch => _pelvisPitch;
  double get pelvisRoll => _pelvisRoll;
  double get pelvisYaw => _pelvisYaw;
  double get lumbarPitch => _lumbarPitch;
  double get lumbarRoll => _lumbarRoll;
  double get lumbarYaw => _lumbarYaw;
  double get relativeFlexion => _relativeFlexion;
  PostureState get postureState => _postureState;

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

    _bleService.dataStream.listen((encryptedPacket) {
      if (encryptedPacket.isEmpty || _useDummyData) return;

      final String decryptedData = _cryptoService.decrypt(Uint8List.fromList(encryptedPacket));

      if (decryptedData.isNotEmpty) {
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
      debugPrint("📊 [AppState] Processing packet #$_packetCounter: $dataString");

      final parts = dataString.trim().split(',');

      // ESP32 Format: PelvisPitch,PelvisRoll,PelvisYaw,LumbarPitch,LumbarRoll,LumbarYaw,RelativeFlexion,State
      if (parts.length >= 8) {
        _pelvisPitch = double.tryParse(parts[0]) ?? 0.0;
        _pelvisRoll = double.tryParse(parts[1]) ?? 0.0;
        _pelvisYaw = double.tryParse(parts[2]) ?? 0.0;
        _lumbarPitch = double.tryParse(parts[3]) ?? 0.0;
        _lumbarRoll = double.tryParse(parts[4]) ?? 0.0;
        _lumbarYaw = double.tryParse(parts[5]) ?? 0.0;
        _relativeFlexion = double.tryParse(parts[6]) ?? 0.0;

        // Parse state string
        String stateStr = parts[7].trim().toUpperCase();
        if (stateStr == "GREEN") {
          _postureState = PostureState.safe;
        } else if (stateStr == "YELLOW") {
          _postureState = PostureState.warning;
        } else if (stateStr == "RED") {
          _postureState = PostureState.critical;
        }

        // Create IMU sensor data for compatibility with existing visualizations
        final pelvisIMU = IMUSensorData(
            sensorId: 'pelvis',
            timestamp: DateTime.now(),
            pitch: _pelvisPitch,
            roll: _pelvisRoll,
            yaw: _pelvisYaw,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 9.8
        );

        final lumbarIMU = IMUSensorData(
            sensorId: 'lumbar',
            timestamp: DateTime.now(),
            pitch: _lumbarPitch,
            roll: _lumbarRoll,
            yaw: _lumbarYaw,
            accelX: 0.0,
            accelY: 0.0,
            accelZ: 9.8
        );

        // Calculate full kinematics for visualization
        final kinematics = _biomechanicalAnalyzer.calculateKinematics(pelvisIMU, lumbarIMU);

        // Override with ESP32's calculated flexion (more accurate due to ZUPT)
        final adjustedKinematics = SpineKinematics(
          upperSensor: kinematics.upperSensor,
          lowerSensor: kinematics.lowerSensor,
          timestamp: kinematics.timestamp,
          relativeFlexion: _relativeFlexion.abs(), // Use ESP32's calculation
          relativeExtension: _relativeFlexion < 0 ? _relativeFlexion.abs() : 0,
          relativeLateralBend: kinematics.relativeLateralBend,
          relativeRotation: kinematics.relativeRotation,
          estimatedCompression: kinematics.estimatedCompression,
        );

        _updateRealtimeKinematics(adjustedKinematics);

        debugPrint("✅ [AppState] Updated: Flexion=${_relativeFlexion.toStringAsFixed(1)}° State=$stateStr");
      } else {
        debugPrint("❌ [AppState] Invalid packet format. Expected 8 values, got ${parts.length}");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AppState] Error processing packet #$_packetCounter: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  void updateKinematicsManually(SpineKinematics kinematics) {
    _currentSpineKinematics = kinematics;
    _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);
    notifyListeners();
  }

  Color getMotionSafetyColor() {
    switch (_postureState) {
      case PostureState.safe:
        return Colors.green;
      case PostureState.warning:
        return Colors.orange;
      case PostureState.critical:
        return Colors.red;
    }
  }

  String getMotionSafetyText() {
    switch (_postureState) {
      case PostureState.safe:
        return 'Safe Posture';
      case PostureState.warning:
        return 'Warning - Check Posture';
      case PostureState.critical:
        return 'Dangerous Posture';
    }
  }

  String getPostureStateString() {
    switch (_postureState) {
      case PostureState.safe:
        return 'GREEN';
      case PostureState.warning:
        return 'YELLOW';
      case PostureState.critical:
        return 'RED';
    }
  }
}