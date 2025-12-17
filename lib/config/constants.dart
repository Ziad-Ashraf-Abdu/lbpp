class AppConstants {
  // Nordic UART Service (NUS) UUIDs
  static const String DEVICE_NAME = "ESP32_Smart_Spine";
  static const String NUS_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String RX_CHARACTERISTIC_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write (App -> ESP32)
  static const String TX_CHARACTERISTIC_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify (ESP32 -> App)

  // Safety Thresholds (Degrees) - From ESP32 PostureEstimator.h
  // GREEN: < 20° (Safe)
  // YELLOW: 20-30° (Warning)
  // RED: > 30° (Critical)
  static const double SAFE_LIMIT = 20.0;      // Green zone limit
  static const double WARN_LIMIT = 30.0;      // Yellow zone limit
  static const double CRITICAL_LIMIT = 30.0;  // Red zone starts here

  // Cloud API (Optional - for future ML integration)
  static const String CLOUD_ENDPOINT = "https://huggingface.co/spaces/YOUR_ORG/lumbar-monitor/api/predict";

  // Activation Key (matches ESP32)
  static const String DEFAULT_ACTIVATION_KEY = "LBPP-DEMO-KEY-2024";

  // Data Format (ESP32 sends 8 CSV values)
  // Format: PelvisPitch,PelvisRoll,PelvisYaw,LumbarPitch,LumbarRoll,LumbarYaw,RelativeFlexion,State
  static const int EXPECTED_DATA_FIELDS = 8;

  // ZUPT Threshold (from ESP32)
  static const double ZUPT_THRESHOLD = 50.0;

  // Complementary Filter Beta (from ESP32)
  static const double FILTER_BETA = 0.03;

  // SHOE Detector Window Size (from ESP32)
  static const int SHOE_WINDOW_SIZE = 5;

  // State Strings (from ESP32)
  static const String STATE_GREEN = "GREEN";
  static const String STATE_YELLOW = "YELLOW";
  static const String STATE_RED = "RED";

  // IMU Sensor Names
  static const String SENSOR_PELVIS = "Pelvis (L4/L5)";
  static const String SENSOR_LUMBAR = "Lumbar (T12/L1)";

  // Update Rate
  static const Duration UPDATE_INTERVAL = Duration(milliseconds: 100); // ~10Hz from ESP32

  // History Buffer Size
  static const int MAX_HISTORY_SIZE = 100;

  // Visualization Settings
  static const double SPINE_VISUALIZATION_HEIGHT = 400.0;
  static const double SPINE_VISUALIZATION_WIDTH = 300.0;

  // Color Scheme
  static const int COLOR_SAFE = 0xFF4CAF50;      // Green
  static const int COLOR_WARNING = 0xFFFFA726;   // Orange
  static const int COLOR_CRITICAL = 0xFFEF5350;  // Red
  static const int COLOR_BACKGROUND = 0xFF121212;
  static const int COLOR_CARD = 0xFF1E1E1E;
}