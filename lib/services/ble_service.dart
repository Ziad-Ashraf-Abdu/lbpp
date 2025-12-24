import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/constants.dart';
import '../models/biomechanical_data.dart';
import '../services/biomechanical_analyzer.dart';

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

  // Buffer for incomplete data packets
  List<int> _dataBuffer = [];
  bool _isAuthenticated = false;

  static const bool isSimulation = false;
  static const String targetDeviceName = "ESP32_Smart_Spine";

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
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        print("[BLE] Bluetooth is NOT ON");
        _statusController.add(BleStatus.error);
        return;
      }

      // Start scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final deviceName = r.device.platformName;
          print("[BLE] Found device: $deviceName");

          if (deviceName == targetDeviceName) {
            print("[BLE] Target device found: ${r.device.remoteId}");
            await FlutterBluePlus.stopScan();
            _scanSubscription?.cancel();
            await _attemptConnection(r.device, activationKey);
            return;
          }
        }
      });

      // Timeout handler
      Future.delayed(const Duration(seconds: 16), () async {
        if (_connectedDevice == null) {
          print("[BLE] Scan Timeout: No device found");
          await FlutterBluePlus.stopScan();
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
      await device.connect(timeout: const Duration(seconds: 10));
      print("[BLE] Connected. Discovering Services...");

      List<BluetoothService> services = await device.discoverServices();

      var service = services.firstWhere(
            (s) => s.uuid.toString().toUpperCase() == AppConstants.NUS_SERVICE_UUID.toUpperCase(),
        orElse: () => throw Exception("Nordic UART Service Not Found"),
      );

      _rxCharacteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == AppConstants.RX_CHARACTERISTIC_UUID.toUpperCase()
      );

      _txCharacteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == AppConstants.TX_CHARACTERISTIC_UUID.toUpperCase()
      );

      // Setup notifications BEFORE handshake
      await _txCharacteristic!.setNotifyValue(true);

      // HANDSHAKE
      _statusController.add(BleStatus.handshake);
      print("[BLE] Starting handshake with key: $key");

      Completer<bool> handshakeCompleter = Completer();
      bool handshakeInProgress = true;

      _notifySubscription = _txCharacteristic!.lastValueStream.listen((value) {
        if (value.isEmpty) return;

        // During handshake, look for AUTH messages
        if (handshakeInProgress) {
          try {
            String response = utf8.decode(value);
            print("[BLE] Handshake response: $response");

            if (response.contains("AUTH_SUCCESS")) {
              print("[BLE] Authentication successful!");
              _isAuthenticated = true;
              handshakeInProgress = false;
              if (!handshakeCompleter.isCompleted) {
                handshakeCompleter.complete(true);
              }
              return;
            } else if (response.contains("AUTH_FAIL")) {
              print("[BLE] Authentication failed!");
              if (!handshakeCompleter.isCompleted) {
                handshakeCompleter.complete(false);
              }
              return;
            }
          } catch (e) {
            // Not a text message during handshake, ignore
          }
        }

        // After handshake, process encrypted data
        if (_isAuthenticated) {
          print("[BLE] Received encrypted data packet: ${value.length} bytes");
          _dataController.add(value);
        }
      }, onError: (error) {
        print("[BLE] Notification stream error: $error");
      });

      // Send activation key
      await _rxCharacteristic!.write(utf8.encode(key), withoutResponse: false);
      print("[BLE] Activation key sent");

      // Wait for handshake with timeout
      try {
        bool success = await handshakeCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print("[BLE] Handshake timeout!");
            return false;
          },
        );

        if (success) {
          print("[BLE] Handshake complete! Streaming data...");
          _connectedDevice = device;
          _statusController.add(BleStatus.connected);
        } else {
          print("[BLE] Handshake failed");
          await disconnect();
          _statusController.add(BleStatus.error);
        }
      } catch (e) {
        print("[BLE] Handshake error: $e");
        await disconnect();
        _statusController.add(BleStatus.error);
      }

    } catch (e) {
      print("[BLE] Connection error: $e");
      await disconnect();
      _statusController.add(BleStatus.error);
    }
  }

  void _startMockHandshake(String key) async {
    _statusController.add(BleStatus.connecting);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.handshake);
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = true;
    _statusController.add(BleStatus.connected);
  }

  Stream<SpineKinematics> getMockIMUData() {
    return Stream<SpineKinematics>.periodic(
      const Duration(milliseconds: 100),
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
          sensorId: 'lower',
          timestamp: now,
          pitch: 0, roll: 0, yaw: 0,
          accelX: 0, accelY: 0, accelZ: 9.8,
        );

        final biomechanicalAnalyzer = BiomechanicalAnalyzer();
        return biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
      },
    );
  }

  Future<void> disconnect() async {
    print("[BLE] Disconnecting...");
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _isAuthenticated = false;
    _dataBuffer.clear();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        print("[BLE] Disconnect error: $e");
      }
      _connectedDevice = null;
    }

    _statusController.add(BleStatus.disconnected);
    print("[BLE] Disconnected.");
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _dataController.close();
  }
}