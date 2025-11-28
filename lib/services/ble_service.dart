import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Only used for fallback, can be removed if strictly hardware
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/constants.dart';

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
  // SET TO FALSE: This forces the app to use the phone's real Bluetooth radio.
  // If you are on an Emulator without Bluetooth passthrough, SCANNING WILL FAIL (find 0 devices).
  static const bool isSimulation = false;

  /// Starts scanning for the specific ESP32 service
  Future<void> scanAndHandshake(String activationKey) async {
    _statusController.add(BleStatus.scanning);

    if (isSimulation) {
      _startMockHandshake(activationKey);
      return;
    }

    print("[BLE] Starting REAL Scan for Service: ${AppConstants.NUS_SERVICE_UUID}");

    // 1. Strict Scan: filtering by UUID.
    // If the dummy device is OFF, this list will remain empty.
    try {
      // Start the scan (stops automatically after 10 seconds)
      await FlutterBluePlus.startScan(
          withServices: [Guid(AppConstants.NUS_SERVICE_UUID)],
          timeout: const Duration(seconds: 10));

      // 2. Listen for results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          print("[BLE] Found Real Device: ${r.device.platformName} (${r.device.remoteId})");

          // Stop scanning immediately when we find a match
          await FlutterBluePlus.stopScan();
          _scanSubscription?.cancel(); // Stop listening
          await _attemptConnection(r.device, activationKey);
          break; // Stop after first match
        }
      });

      // 3. Timeout Logic: If we are still scanning after 10.5 seconds, it means we found nothing.
      Future.delayed(const Duration(milliseconds: 10500), () {
        if (_connectedDevice == null && _statusController.hasListener) {
          // Only report error if we haven't transitioned to connecting/connected
          print("[BLE] Scan Timeout: No devices found with UUID ${AppConstants.NUS_SERVICE_UUID}");
          print("[BLE] Tip: Android Emulators cannot scan for real Bluetooth devices. Use a physical phone.");
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
      // Android Emulators often hang here if they don't support BLE.
      await device.connect(timeout: const Duration(seconds: 5));
      print("[BLE] Connected. Discovering Services...");

      // 3. Service Discovery
      List<BluetoothService> services = await device.discoverServices();
      var service = services.firstWhere(
            (s) => s.uuid.toString().toUpperCase() == AppConstants.NUS_SERVICE_UUID,
        orElse: () => throw Exception("Service Not Found on Device"),
      );

      // 4. Characteristic Discovery
      _rxCharacteristic = null;
      _txCharacteristic = null;

      for (BluetoothCharacteristic c in service.characteristics) {
        String uuid = c.uuid.toString().toUpperCase();
        if (uuid == AppConstants.RX_CHARACTERISTIC_UUID) {
          _rxCharacteristic = c;
        } else if (uuid == AppConstants.TX_CHARACTERISTIC_UUID) {
          _txCharacteristic = c;
        }
      }

      // Fallback: Use RX for notifications if TX is missing (common in some simulator configs)
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
          // Sensor data
          if (_statusController.hasListener) _dataController.add(value);
        }
      });

      // Write the key to the device
      await _rxCharacteristic!.write(utf8.encode(key));

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

    } catch (e) {
      print("[BLE] Connection Failed: $e");
      disconnect();
    }
  }

  // --- MOCK LOGIC (Disabled by default) ---
  void _startMockHandshake(String key) async {
    // ... (Existing mock logic kept only for backup, not used when isSimulation = false)
    _statusController.add(BleStatus.connecting);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.handshake);
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(BleStatus.connected);
    // Start fake stream...
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_statusController.hasListener) return;
      double angle = 22.5 + 22.5 * sin(DateTime.now().millisecondsSinceEpoch / 500);
      _dataController.add([angle.toInt()]);
    });
  }

  void disconnect() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _statusController.add(BleStatus.disconnected);
    print("[BLE] Disconnected.");
  }
}