class AppConstants {
  // Nordic UART Service (NUS) UUIDs [cite: 195]
  static const String DEVICE_NAME = "ESP32_Smart_Spine";
  static const String NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String RX_CHARACTERISTIC_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write (App -> ESP32)
  static const String TX_CHARACTERISTIC_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify (ESP32 -> App)

  // Safety Thresholds (Degrees) [cite: 200]
  static const double SAFE_LIMIT = 10.0;
  static const double WARN_LIMIT = 15.0;

  // Cloud API
  static const String CLOUD_ENDPOINT = "https://huggingface.co/spaces/YOUR_ORG/lumbar-monitor/api/predict";
}