import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Only used for fallback, can be removed if strictly hardware
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/constants.dart';
import '../models/biomechanical_data.dart'; // Add this import
import '../services/biomechanical_analyzer.dart'; // Add this import

enum BleStatus { disconnected, scanning, connecting, handshake, connected, error }

class BleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _scanSubscription;

  final _statusController = StreamController<BleStatus>.broadcast();
  Stream<BleStatus> get statusStream => _statusController.stream;

  final _dataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get dataStream => _dataController.stream;

  // --- CONFIGURATION ---
  static const bool isSimulation = false; // Set to FALSE for real hardware connection
  static const String targetDeviceName = "ESP32_Smart_Spine"; // Device name to search for

  /// Starts scanning for the specific ESP32 device by name
  Future<void> scanAndHandshake(String activationKey) async {
    if (isSimulation) {
      print("[BLE] Simulation Mode Active");
      _startMockHandshake(activationKey);
      return;
    }

    print("[BLE] Starting Scan for Device: $targetDeviceName");
    _statusController.add(BleStatus.scanning);

    try {
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        print("[BLE] Bluetooth is NOT ON");
        _statusController.add(BleStatus.error);
        return;
      }

      // Start scan WITHOUT service filter to find device by name
      await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 50));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          // Check if device name matches
          if (r.device.platformName == targetDeviceName) {
            print("[BLE] Found Device: ${r.device.platformName} (${r.device.remoteId})");
            await FlutterBluePlus.stopScan();
            _scanSubscription?.cancel();
            await _attemptConnection(r.device, activationKey);
            return; // Exit after finding the first match
          }
        }
      });

      Future.delayed(const Duration(milliseconds: 10500), () {
        if (_connectedDevice == null) {
          print("[BLE] Scan Timeout: No devices found with name '$targetDeviceName'");
          _statusController.add(BleStatus.error);
        }
      });

    } catch (e) {
      print("[BLE] Scan Error: $e");
      _statusController.add(BleStatus.error);
    }
  }

  Future<void> _attemptConnection(BluetoothDevice device, String key) async {
    _statusController.add(BleStatus.connecting);
    print("[BLE] Connecting to ${device.platformName}...");

    try {
      await device.connect(timeout: const Duration(seconds: 5));
      print("[BLE] Connected. Discovering Services...");

      List<BluetoothService> services = await device.discoverServices();
      var service = services.firstWhere(
            (s) => s.uuid.toString().toUpperCase() == AppConstants.NUS_SERVICE_UUID,
        orElse: () => throw Exception("Nordic UART Service Not Found"),
      );

      _rxCharacteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == AppConstants.RX_CHARACTERISTIC_UUID);
      _txCharacteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == AppConstants.TX_CHARACTERISTIC_UUID);

      // --- HANDSHAKE PROTOCOL (RESTORED) ---
      _statusController.add(BleStatus.handshake);
      print("[BLE] Performing handshake...");

      await _txCharacteristic!.setNotifyValue(true);
      Completer<bool> handshakeCompleter = Completer();

      _notifySubscription = _txCharacteristic!.lastValueStream.listen((value) {
        String response;
        try {
          response = utf8.decode(value);
        } catch(e) {
          _dataController.add(value);
          return;
        }

        if (response.contains("AUTH_SUCCESS")) {
          if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(true);
        } else if (response.contains("AUTH_FAIL")) {
          if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(false);
        } else {
          // Not an AUTH message, must be sensor data
          _dataController.add(value);
        }
      });

      await _rxCharacteristic!.write(utf8.encode(key));
      print("[BLE] Sent Key: $key");

      try {
        bool success = await handshakeCompleter.future.timeout(const Duration(seconds: 5));
        if (success) {
          print("[BLE] Handshake Success! Now streaming data...");
          _connectedDevice = device;
          _statusController.add(BleStatus.connected);
        } else {
          print("[BLE] Handshake Failed (Invalid Key Response).");
          disconnect();
        }
      } catch (e) {
        print("[BLE] Handshake Timed Out! The ESP32 did not reply with 'AUTH_SUCCESS'.");
        disconnect();
      }

    } catch (e) {
      print("[BLE] Connection Failed: $e");
      disconnect();
    }
  }

  // --- MOCK LOGIC (For UI Testing) ---
  void _startMockHandshake(String key) async {
    _statusController.add(BleStatus.connecting);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.handshake);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.connected);

    // The dummy data is now generated inside AppState, not here.
  }

  Stream<SpineKinematics> getMockIMUData() {
    return Stream<SpineKinematics>.periodic(
      const Duration(milliseconds: 100), // Faster update for smoother UI
          (count) {
        final now = DateTime.now();
        final timeFactor = (now.millisecondsSinceEpoch / 1000.0) * 0.7;

        final upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 25.0 * sin(timeFactor * 0.5),
          roll: 25.0 * sin(timeFactor * 0.3),
          yaw: 15.0 * sin(timeFactor * 0.2),
          accelX: 0, accelY: 0, accelZ: 9.8,
        );

        final lowerIMU = IMUSensorData(
          sensorId: 'lower', timestamp: now,
          pitch: 0, roll: 0, yaw: 0,
          accelX: 0, accelY: 0, accelZ: 9.8,
        );

        final biomechanicalAnalyzer = BiomechanicalAnalyzer();
        return biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
      },
    );
  }

  void disconnect() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _statusController.add(BleStatus.disconnected);
    print("[BLE] Disconnected.");
  }

  void dispose() {
    _statusController.close();
    _dataController.close();
    disconnect();
  }
}