import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../services/ble_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_service.dart';
import '../models/biomechanical_data.dart';
import '../services/biomechanical_analyzer.dart';

enum PostureState { safe, warning, critical, unknown }

class AppState extends ChangeNotifier {
  // --- Services ---
  final BleService _bleService = BleService();
  final EncryptionService _cryptoService = EncryptionService();
  final CloudService _cloudService = CloudService();
  final BiomechanicalAnalyzer _biomechanicalAnalyzer = BiomechanicalAnalyzer();

  // --- Profile & Auth State ---
  String _userName = "User";
  String? _activationKey;
  bool _isKeyValidated = false;

  // --- Connection Status ---
  BleStatus _connectionStatus = BleStatus.disconnected;

  // --- Hardware Sensor Fields (8-Part CSV Logic) ---
  double _pelvisPitch = 0.0;
  double _pelvisRoll = 0.0;
  double _pelvisYaw = 0.0;
  double _lumbarPitch = 0.0;
  double _lumbarRoll = 0.0;
  double _lumbarYaw = 0.0;
  double _relativeFlexion = 0.0;
  String _espState = "UNKNOWN";

  // --- Diagnostics & Performance ---
  int _packetCounter = 0;
  int _successfulPackets = 0;
  int _failedPackets = 0;
  DateTime? _lastUpdateTime;

  // --- Biomechanical Analysis State ---
  SpineKinematics? _currentSpineKinematics;
  final List<SpineKinematics> _spineHistory = [];
  Map<String, dynamic> _motionAnalysis = {};
  bool _useDummyData = true;
  bool _isBiomechanicsActive = false;

  // --- Stream Subscriptions ---
  StreamSubscription? _dummyDataSubscription;
  StreamSubscription? _bleStatusSubscription;
  StreamSubscription? _bleDataSubscription;

  // --- Getters ---
  String get userName => _userName;
  String? get activationKey => _activationKey;
  BleStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == BleStatus.connected;
  bool get isKeyValidated => _isKeyValidated;

  double get pelvisPitch => _pelvisPitch;
  double get pelvisRoll => _pelvisRoll;
  double get pelvisYaw => _pelvisYaw;
  double get lumbarPitch => _lumbarPitch;
  double get lumbarRoll => _lumbarRoll;
  double get lumbarYaw => _lumbarYaw;
  double get relativeFlexion => _relativeFlexion;

  PostureState get postureState {
    if (_espState == "RED") return PostureState.critical;
    if (_espState == "YELLOW") return PostureState.warning;
    if (_espState == "GREEN") return PostureState.safe;
    return PostureState.unknown;
  }

  SpineKinematics? get currentSpineKinematics => _currentSpineKinematics;
  List<SpineKinematics> get spineHistory => _spineHistory;
  Map<String, dynamic> get motionAnalysis => _motionAnalysis;
  bool get useDummyData => _useDummyData;
  bool get isBiomechanicsActive => _isBiomechanicsActive;

  int get packetCounter => _packetCounter;
  int get successfulPackets => _successfulPackets;
  int get failedPackets => _failedPackets;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  // --- Constructor ---
  AppState() {
    _listenToBle();
    _initializeBiomechanics();
  }

  @override
  void dispose() {
    _dummyDataSubscription?.cancel();
    _bleStatusSubscription?.cancel();
    _bleDataSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  // --- Initialization & Security ---

  void initializeUser(String name, String key) {
    _userName = name;
    _activationKey = key;
    _cryptoService.init(key);
    _isKeyValidated = false; // Key is not validated until first successful data parse
    debugPrint("[AppState] Initialization Complete: $name");
    notifyListeners();
  }

  void startConnection() {
    if (_activationKey == null) {
      debugPrint("[AppState] Warning: No key found. Using Default Demo Key.");
      _activationKey = "LBPP-DEMO-2025";
      _cryptoService.init(_activationKey!);
    }

    _cryptoService.reset();
    _packetCounter = 0;
    _successfulPackets = 0;
    _failedPackets = 0;

    debugPrint("[AppState] Scanning for hardware with key: $_activationKey");
    _bleService.scanAndHandshake(_activationKey!);
  }

  void disconnect() {
    _bleService.disconnect();
    _isKeyValidated = false;
    notifyListeners();
  }

  // --- Dummy Data Management ---

  void toggleDummyData() {
    _useDummyData = !_useDummyData;
    if (_useDummyData) {
      _startDummyDataStream();
    } else {
      _stopDummyDataStream();
    }
    notifyListeners();
  }

  void _initializeBiomechanics() {
    if (_useDummyData) {
      _currentSpineKinematics = _biomechanicalAnalyzer.generateDummyData();
      _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(_currentSpineKinematics!);
      _startDummyDataStream();
    }
  }

  void _startDummyDataStream() {
    _dummyDataSubscription?.cancel();
    _dummyDataSubscription = _bleService.getMockIMUData().listen((kinematics) {
      if (!_useDummyData) return;
      _updateRealtimeKinematics(kinematics);
      notifyListeners();
    });
  }

  void _stopDummyDataStream() {
    _dummyDataSubscription?.cancel();
    _dummyDataSubscription = null;
  }

  // --- Real-time Processing ---

  void _updateRealtimeKinematics(SpineKinematics kinematics) {
    _currentSpineKinematics = kinematics;
    _motionAnalysis = _biomechanicalAnalyzer.checkThresholds(kinematics);

    _pelvisPitch = kinematics.lowerSensor.pitch;
    _lumbarPitch = kinematics.upperSensor.pitch;
    _relativeFlexion = kinematics.relativeFlexion;

    _spineHistory.add(kinematics);
    if (_spineHistory.length > 100) {
      _spineHistory.removeAt(0);
    }

    if (postureState == PostureState.critical) {
      HapticFeedback.heavyImpact();
    }

    if (kinematics.estimatedCompression > 80.0) {
      _sendBiomechanicalAlert(kinematics);
    }

    notifyListeners();
  }

  void _sendBiomechanicalAlert(SpineKinematics kinematics) {
    final alertData = {
      'user': _userName,
      'compression': kinematics.estimatedCompression,
      'flexion': kinematics.relativeFlexion,
      'time': DateTime.now().toIso8601String(),
    };
    _cloudService.sendBiomechanicalAlert(alertData);
  }

  // --- BLE Communication Engine ---

  void _listenToBle() {
    _bleStatusSubscription = _bleService.statusStream.listen((status) {
      _connectionStatus = status;

      if (status == BleStatus.connected) {
        _useDummyData = false;
        _stopDummyDataStream();
        _isKeyValidated = false; // Wait for correct key verification
        if (_activationKey != null) {
          _cryptoService.reset();
          _cryptoService.init(_activationKey!);
        }
      } else if (status == BleStatus.disconnected) {
        _useDummyData = true;
        _isKeyValidated = false;
        _initializeBiomechanics();
      }

      notifyListeners();
    });

    _bleDataSubscription = _bleService.dataStream.listen((encryptedPacket) {
      if (encryptedPacket.isEmpty || _useDummyData) return;

      _packetCounter++;
      try {
        final String decryptedData = _cryptoService.decrypt(Uint8List.fromList(encryptedPacket));

        // SECURITY CHECK: If the key is wrong, decryptedData will be gibberish.
        // A valid packet must contain commas based on our 8-part CSV format.
        if (decryptedData.isNotEmpty && decryptedData.contains(',')) {
          bool success = _processData(decryptedData);
          if (success) {
            _isKeyValidated = true; // Key verified!
            _successfulPackets++;
            _lastUpdateTime = DateTime.now();
          } else {
            _isKeyValidated = false;
            _failedPackets++;
          }
        } else {
          _isKeyValidated = false;
          _failedPackets++;
          debugPrint("⚠️ Decryption result invalid. Possible wrong activation key.");
        }
      } catch (e) {
        _isKeyValidated = false;
        _failedPackets++;
        debugPrint("❌ Encryption Engine Error: $e");
      }
      notifyListeners();
    });
  }

  /// Parses the 8-part CSV Hardware Format
  bool _processData(String dataString) {
    try {
      final parts = dataString.trim().split(',');

      // Validate format: must have exactly 8 parts (or at least 8)
      if (parts.length >= 8) {
        _pelvisPitch = double.tryParse(parts[0]) ?? 0.0;
        _pelvisRoll = double.tryParse(parts[1]) ?? 0.0;
        _pelvisYaw = double.tryParse(parts[2]) ?? 0.0;
        _lumbarPitch = double.tryParse(parts[3]) ?? 0.0;
        _lumbarRoll = double.tryParse(parts[4]) ?? 0.0;
        _lumbarYaw = double.tryParse(parts[5]) ?? 0.0;
        _relativeFlexion = double.tryParse(parts[6]) ?? 0.0;
        _espState = parts[7].trim().toUpperCase();

        final upperIMU = IMUSensorData(
            sensorId: 'upper',
            timestamp: DateTime.now(),
            pitch: _lumbarPitch,
            roll: _lumbarRoll,
            yaw: _lumbarYaw,
            accelX: 0.0, accelY: 0.0, accelZ: 9.8
        );

        final lowerIMU = IMUSensorData(
            sensorId: 'lower',
            timestamp: DateTime.now(),
            pitch: _pelvisPitch,
            roll: _pelvisRoll,
            yaw: _pelvisYaw,
            accelX: 0.0, accelY: 0.0, accelZ: 9.8
        );

        final kinematics = _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);

        final combinedKinematics = SpineKinematics(
          upperSensor: upperIMU,
          lowerSensor: lowerIMU,
          timestamp: kinematics.timestamp,
          relativeFlexion: _relativeFlexion,
          relativeExtension: kinematics.relativeExtension,
          relativeLateralBend: kinematics.relativeLateralBend,
          relativeRotation: kinematics.relativeRotation,
          estimatedCompression: kinematics.estimatedCompression,
        );

        _updateRealtimeKinematics(combinedKinematics);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("[Parser] CSV parsing error: $e");
      return false;
    }
  }

  // --- UI Styling Helpers ---

  Color getMotionSafetyColor() {
    switch (postureState) {
      case PostureState.critical: return Colors.redAccent;
      case PostureState.warning: return Colors.orangeAccent;
      case PostureState.safe: return Colors.greenAccent;
      default: return Colors.blueGrey;
    }
  }

  String getMotionSafetyText() {
    switch (postureState) {
      case PostureState.critical: return 'CRITICAL COMPRESSION';
      case PostureState.warning: return 'POOR ALIGNMENT';
      case PostureState.safe: return 'HEALTHY POSTURE';
      default: return 'SCANNING HARDWARE...';
    }
  }

  List<Map<String, dynamic>> getSessionSummary() {
    if (_spineHistory.isEmpty) return [];

    final avgFlexion = _spineHistory.map((k) => k.relativeFlexion).reduce((a, b) => a + b) / _spineHistory.length;
    final maxComp = _spineHistory.map((k) => k.estimatedCompression).reduce((a, b) => a > b ? a : b);

    return [
      {'label': 'Session User', 'value': _userName},
      {'label': 'Average Flexion', 'value': '${avgFlexion.toStringAsFixed(1)}°'},
      {'label': 'Peak Compression', 'value': '${maxComp.toStringAsFixed(1)}%'},
      {'label': 'Total Packets', 'value': '$_packetCounter'},
    ];
  }
}