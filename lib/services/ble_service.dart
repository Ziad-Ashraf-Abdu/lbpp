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

  // New biomechanical analyzer
  final BiomechanicalAnalyzer _biomechanicalAnalyzer = BiomechanicalAnalyzer();

  final _statusController = StreamController<BleStatus>.broadcast();
  Stream<BleStatus> get statusStream => _statusController.stream;

  final _dataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get dataStream => _dataController.stream;

  // New stream for processed IMU data
  final _imuDataController = StreamController<SpineKinematics>.broadcast();
  Stream<SpineKinematics>? get imuDataStream => _imuDataController.stream.isBroadcast ? _imuDataController.stream : null;

  // --- CONFIGURATION ---
  // SET TO FALSE: This forces the app to use the phone's real Bluetooth radio.
  // If you are on an Emulator without Bluetooth passthrough, SCANNING WILL FAIL (find 0 devices).
  static const bool isSimulation = false;

  /// Starts scanning for the specific ESP32 service
  Future<void> scanAndHandshake(String activationKey) async {
    print("[BLE] scanAndHandshake called with key: $activationKey");
    _statusController.add(BleStatus.scanning);

    if (isSimulation) {
      print("[BLE] Simulation Mode Active");
      _startMockHandshake(activationKey);
      return;
    }

    print("[BLE] Starting WIDE Scan (No UUID Filter) to find device...");

    try {
      // Check if Bluetooth is on
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        print("[BLE] Bluetooth is NOT ON");
        _statusController.add(BleStatus.error);
        return;
      }

      // REMOVED FILTER to find all devices for debugging
      await FlutterBluePlus.startScan(
        // withServices: [Guid(AppConstants.NUS_SERVICE_UUID)], // Filter removed
          timeout: const Duration(seconds: 10));

      // 2. Listen for results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          // LOG EVERYTHING to help debug
          print("[BLE] Scanned: '${r.device.platformName}' (${r.device.remoteId}) Services: ${r.advertisementData.serviceUuids}");

          // Check for match by UUID OR Name (Fallback)
          bool uuidMatch = r.advertisementData.serviceUuids.contains(Guid(AppConstants.NUS_SERVICE_UUID));
          bool nameMatch = r.device.platformName.toLowerCase().contains("esp32") ||
              r.device.platformName.toLowerCase().contains("lbpp") ||
              r.device.platformName.toLowerCase().contains("uart");

          if (uuidMatch || nameMatch) {
            print("[BLE] MATCH FOUND! Connecting to ${r.device.platformName} (${r.device.remoteId})...");

            // Stop scanning immediately when we find a match
            await FlutterBluePlus.stopScan();
            _scanSubscription?.cancel(); // Stop listening
            await _attemptConnection(r.device, activationKey);
            break; // Stop after first match
          }
        }
      });

      // 3. Timeout Logic: If we are still scanning after 10.5 seconds, it means we found nothing.
      Future.delayed(const Duration(milliseconds: 10500), () {
        if (_connectedDevice == null && _statusController.hasListener) {
          // Only report error if we haven't transitioned to connecting/connected
          print("[BLE] Scan Timeout. Devices found were logged above.");
          print("[BLE] CHECK THE LOGS: Did you see your device name in the list above?");
          _statusController.add(BleStatus.error);
        }
      });

    } catch (e) {
      print("[BLE] Scan Error (Are permissions granted?): $e");
      _statusController.add(BleStatus.error);
    }
  }

  Future<void> _attemptConnection(BluetoothDevice device, String key) async {
    _statusController.add(BleStatus.connecting);
    print("[BLE] Connecting to ${device.platformName}...");

    try {
      // 2. Real Connection Attempt
      await device.connect(timeout: const Duration(seconds: 5));
      print("[BLE] Connected. Discovering Services...");

      // 3. Service Discovery
      List<BluetoothService> services = await device.discoverServices();

      // Improved Service Discovery with Debugging
      BluetoothService? service;
      try {
        service = services.firstWhere(
                (s) => s.uuid.toString().toUpperCase() == AppConstants.NUS_SERVICE_UUID
        );
      } catch (e) {
        print("[BLE] Target Service ${AppConstants.NUS_SERVICE_UUID} NOT FOUND.");
        // Fallback: Try to find ANY service with the RX/TX characteristics
        print("[BLE] Attempting to find service by characteristic...");
        for (var s in services) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toUpperCase() == AppConstants.RX_CHARACTERISTIC_UUID) {
              service = s;
              print("[BLE] Found matching service: ${s.uuid}");
              break;
            }
          }
          if (service != null) break;
        }
        if (service == null) throw Exception("Service Mismatch");
      }

      // 4. Characteristic Discovery
      _rxCharacteristic = null;
      _txCharacteristic = null;

      for (BluetoothCharacteristic c in service!.characteristics) {
        String uuid = c.uuid.toString().toUpperCase();
        if (uuid == AppConstants.RX_CHARACTERISTIC_UUID) {
          _rxCharacteristic = c;
        } else if (uuid == AppConstants.TX_CHARACTERISTIC_UUID) {
          _txCharacteristic = c;
        }
      }

      if (_rxCharacteristic != null && _txCharacteristic == null) {
        if (_rxCharacteristic!.properties.notify || _rxCharacteristic!.properties.indicate) {
          _txCharacteristic = _rxCharacteristic;
          print("[BLE] TX missing, using RX for Notify.");
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        throw Exception("Required Characteristics not found.");
      }

      // --- HANDSHAKE PROTOCOL ---
      _statusController.add(BleStatus.handshake);
      print("[BLE] Sending Key: $key");

      // Listen for the REAL reply from the device
      await _txCharacteristic!.setNotifyValue(true);

      // ============================================================
      // HANDSHAKE LOGIC - COMMENTED OUT TO BYPASS FOR TESTING
      // ============================================================
      /*
      Completer<bool> handshakeCompleter = Completer();

      _notifySubscription = _txCharacteristic!.lastValueStream.listen((value) {
        String response = utf8.decode(value);
        print("[BLE] Received Packet: $response");

        // STRICT CHECK: The string MUST contain "AUTH_SUCCESS"
        if (response.contains("AUTH_SUCCESS")) {
          if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(true);
        } else if (response.contains("AUTH_FAIL")) {
          if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(false);
        } else {
          // Sensor data - try to parse as IMU data
          _processIncomingData(value);

          // Also pass to original data stream
          if (_statusController.hasListener) _dataController.add(value);
        }
      });
      */

      // ============================================================
      // TEMPORARY LOGIC - ACCEPT EVERYTHING (BYPASS MODE)
      // ============================================================
      _notifySubscription = _txCharacteristic!.lastValueStream.listen((value) {
        try {
          // Log raw data
          print("[BLE] Raw Data: $value");
          String response = utf8.decode(value);
          print("[BLE] Received String: $response");

          // Always process incoming data
          _processIncomingData(value);
          if (_statusController.hasListener) _dataController.add(value);
        } catch (e) {
          print("[BLE] Data parsing error: $e");
        }
      });

      // Write the key to the device
      try {
        await _rxCharacteristic!.write(utf8.encode(key));
      } catch (e) {
        print("[BLE] Warning: Could not write key: $e");
      }

      // ============================================================
      // HANDSHAKE WAIT - COMMENTED OUT
      // ============================================================
      /*
      // Wait 5 seconds for the dummy device to reply "AUTH_SUCCESS"
      try {
        bool success = await handshakeCompleter.future.timeout(const Duration(seconds: 5));

        if (success) {
          print("[BLE] Handshake Success!");
          _connectedDevice = device;
          _statusController.add(BleStatus.connected);
        } else {
          print("[BLE] Handshake Failed (Invalid Key Response).");
          disconnect();
        }
      } catch (timeout) {
        print("[BLE] Handshake Timed Out! (Did you send 'AUTH_SUCCESS' from nRF Connect?)");
        disconnect();
      }
      */

      // FORCE CONNECTION SUCCESS
      print("[BLE] Handshake Bypassed (Code commented out). Connected!");
      _connectedDevice = device;
      _statusController.add(BleStatus.connected);


    } catch (e) {
      print("[BLE] Connection Failed: $e");
      disconnect();
    }
  }

  /// Process incoming IMU data packets
  void _processIncomingData(List<int> rawData) {
    try {
      // Convert raw data to string
      final dataString = utf8.decode(rawData).trim();
      print("[BLE] Processing IMU Data: $dataString");

      // Parse the data (assuming format: "upper_pitch,upper_roll,upper_yaw,lower_pitch,lower_roll,lower_yaw")
      final parts = dataString.split(',');

      if (parts.length >= 6) {
        // Parse sensor data
        final upperPitch = double.tryParse(parts[0]) ?? 0.0;
        final upperRoll = double.tryParse(parts[1]) ?? 0.0;
        final upperYaw = double.tryParse(parts[2]) ?? 0.0;
        final lowerPitch = double.tryParse(parts[3]) ?? 0.0;
        final lowerRoll = double.tryParse(parts[4]) ?? 0.0;
        final lowerYaw = double.tryParse(parts[5]) ?? 0.0;

        // Create IMU sensor data objects
        final upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: DateTime.now(),
          pitch: upperPitch,
          roll: upperRoll,
          yaw: upperYaw,
          accelX: 0.0, // Add these if your IMU provides them
          accelY: 0.0,
          accelZ: 9.8,
        );

        final lowerIMU = IMUSensorData(
          sensorId: 'lower',
          timestamp: DateTime.now(),
          pitch: lowerPitch,
          roll: lowerRoll,
          yaw: lowerYaw,
          accelX: 0.0,
          accelY: 0.0,
          accelZ: 9.8,
        );

        // Calculate kinematics
        final kinematics = _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);

        // Send to IMU data stream
        if (_imuDataController.hasListener && !_imuDataController.isClosed) {
          _imuDataController.add(kinematics);
        }
      }
    } catch (e) {
      print("[BLE] Error processing IMU data: $e");
    }
  }

  /// Process IMU data from raw sensor values
  SpineKinematics? processIMUData(
      Map<String, dynamic> upperData,
      Map<String, dynamic> lowerData,
      ) {
    try {
      final upperIMU = IMUSensorData(
        sensorId: 'upper',
        timestamp: DateTime.now(),
        pitch: upperData['pitch'] ?? 0.0,
        roll: upperData['roll'] ?? 0.0,
        yaw: upperData['yaw'] ?? 0.0,
        accelX: upperData['accelX'] ?? 0.0,
        accelY: upperData['accelY'] ?? 0.0,
        accelZ: upperData['accelZ'] ?? 0.0,
      );

      final lowerIMU = IMUSensorData(
        sensorId: 'lower',
        timestamp: DateTime.now(),
        pitch: lowerData['pitch'] ?? 0.0,
        roll: lowerData['roll'] ?? 0.0,
        yaw: lowerData['yaw'] ?? 0.0,
        accelX: lowerData['accelX'] ?? 0.0,
        accelY: lowerData['accelY'] ?? 0.0,
        accelZ: lowerData['accelZ'] ?? 0.0,
      );

      return _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
    } catch (e) {
      print('[BLE] Error processing IMU data: $e');
      return null;
    }
  }

  // --- MOCK LOGIC (Disabled by default) ---
  void _startMockHandshake(String key) async {
    _statusController.add(BleStatus.connecting);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.handshake);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.connected);

    // Start fake lumbar angle stream (existing)
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_statusController.hasListener) return;
      double angle = 22.5 + 22.5 * sin(DateTime.now().millisecondsSinceEpoch / 500);
      _dataController.add([angle.toInt()]);
    });

    // Start fake IMU data stream (new)
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_imuDataController.hasListener || _imuDataController.isClosed) return;

      // Generate varying dummy IMU data
      final now = DateTime.now();
      final timeFactor = DateTime.now().millisecondsSinceEpoch / 1000;

      // Simulate natural spine movements
      final baseFlexion = 5.0 + 15.0 * sin(timeFactor * 0.5); // Slow flexion/extension
      final baseLateral = 2.0 + 10.0 * sin(timeFactor * 0.3); // Slower side bending

      final upperIMU = IMUSensorData(
        sensorId: 'upper',
        timestamp: now,
        pitch: baseFlexion, // Vary flexion
        roll: baseLateral,  // Vary lateral bend
        yaw: 1.0 * sin(timeFactor * 0.2), // Small rotation
        accelX: 0.1 * sin(timeFactor * 2.0),
        accelY: 0.05 * sin(timeFactor * 1.5),
        accelZ: 9.8 + 0.2 * sin(timeFactor * 3.0), // Small vertical variations
      );

      final lowerIMU = IMUSensorData(
        sensorId: 'lower',
        timestamp: now,
        pitch: 0.0, // Reference sensor (stable)
        roll: 0.0,
        yaw: 0.0,
        accelX: 0.0,
        accelY: 0.0,
        accelZ: 9.8, // Stable gravity
      );

      final kinematics = _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
      _imuDataController.add(kinematics);
    });
  }

  /// Get mock IMU data stream for testing
  Stream<SpineKinematics> getMockIMUData() {
    return Stream<SpineKinematics>.periodic(
      const Duration(milliseconds: 500),
          (count) {
        // Generate varying dummy data
        final now = DateTime.now();
        final timeFactor = DateTime.now().millisecondsSinceEpoch / 1000;

        // Create more realistic movement patterns
        final upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 5.0 + 15.0 * sin(timeFactor * 0.5), // Flexion/extension cycle every ~12.5 seconds
          roll: 2.0 + 8.0 * sin(timeFactor * 0.3),   // Lateral bending cycle every ~20 seconds
          yaw: 2.0 * sin(timeFactor * 0.2),          // Rotation cycle every ~30 seconds
          accelX: 0.1 * sin(timeFactor * 2.0),
          accelY: 0.05 * cos(timeFactor * 1.8),
          accelZ: 9.8 + 0.1 * sin(timeFactor * 3.0),
        );

        final lowerIMU = IMUSensorData(
          sensorId: 'lower',
          timestamp: now,
          pitch: 0.0, // Reference (stable)
          roll: 0.0,
          yaw: 0.0,
          accelX: 0.0,
          accelY: 0.0,
          accelZ: 9.8, // Gravity
        );

        return _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
      },
    );
  }

  /// Simulate specific spine movements for testing
  SpineKinematics simulateSpineMovement(String movementType) {
    final now = DateTime.now();

    IMUSensorData upperIMU;
    IMUSensorData lowerIMU;

    switch (movementType) {
      case 'flexion':
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 45.0, // Forward bend
          roll: 0.0,
          yaw: 0.0,
          accelX: 0.0,
          accelY: 0.0,
          accelZ: 9.5,
        );
        break;

      case 'extension':
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: -25.0, // Backward bend
          roll: 0.0,
          yaw: 0.0,
          accelX: 0.0,
          accelY: 0.0,
          accelZ: 10.1,
        );
        break;

      case 'lateral_left':
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 0.0,
          roll: -20.0, // Bend to left
          yaw: 0.0,
          accelX: 0.0,
          accelY: 0.2,
          accelZ: 9.8,
        );
        break;

      case 'lateral_right':
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 0.0,
          roll: 20.0, // Bend to right
          yaw: 0.0,
          accelX: 0.0,
          accelY: -0.2,
          accelZ: 9.8,
        );
        break;

      case 'compression':
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 30.0,
          roll: 0.0,
          yaw: 0.0,
          accelX: 0.0,
          accelY: 0.0,
          accelZ: 11.0, // High vertical acceleration = compression
        );
        break;

      default: // neutral
        upperIMU = IMUSensorData(
          sensorId: 'upper',
          timestamp: now,
          pitch: 5.0,
          roll: 2.0,
          yaw: 0.0,
          accelX: 0.1,
          accelY: 0.0,
          accelZ: 9.8,
        );
    }

    lowerIMU = IMUSensorData(
      sensorId: 'lower',
      timestamp: now,
      pitch: 0.0,
      roll: 0.0,
      yaw: 0.0,
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 9.8,
    );

    return _biomechanicalAnalyzer.calculateKinematics(upperIMU, lowerIMU);
  }

  void disconnect() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectedDevice?.disconnect();
    _connectedDevice = null;

    // Close IMU data stream
    if (!_imuDataController.isClosed) {
      _imuDataController.close();
    }

    _statusController.add(BleStatus.disconnected);
    print("[BLE] Disconnected.");
  }

  /// Clean up all resources
  void dispose() {
    _statusController.close();
    _dataController.close();
    _imuDataController.close();
    disconnect();
  }
}