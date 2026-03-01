/// Application-wide constants for BodiLog.
class AppConstants {
  AppConstants._();

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName = 'BodiLog';

  // ── Database ───────────────────────────────────────────────────────────────
  static const String databaseName = 'bodilog.db';
  static const int databaseVersion = 2;

  // ── Storage ────────────────────────────────────────────────────────────────
  /// Sub-directory name inside the app documents directory used for images.
  static const String imageDirectoryName = 'strip_images';

  // ── Bluetooth ──────────────────────────────────────────────────────────────
  /// Duration in seconds to scan for nearby BLE devices.
  static const int bleScanTimeoutSeconds = 10;

  /// Duration in seconds to wait when establishing a BLE connection.
  static const int bleConnectionTimeoutSeconds = 30;

  // ── BLE Service UUIDs ──────────────────────────────────────────────────────
  /// GATT Body Composition service (Smart Scale).
  static const String bleServiceBodyComposition = '0000181b-0000-1000-8000-00805f9b34fb';

  /// GATT Blood Pressure service.
  static const String bleServiceBloodPressure = '00001810-0000-1000-8000-00805f9b34fb';

  /// GATT Health Thermometer service.
  static const String bleServiceThermometer = '00001809-0000-1000-8000-00805f9b34fb';

  /// GATT Pulse Oximeter service.
  static const String bleServicePulseOximeter = '00001822-0000-1000-8000-00805f9b34fb';

  /// Custom wearable sensor service UUID (default for tremor analysis).
  static const String bleServiceWearableSensor = '0000fff0-0000-1000-8000-00805f9b34fb';

  // ── Analysis ───────────────────────────────────────────────────────────────
  /// Minimum confidence score (0–1) to consider a colour-match result valid.
  static const double minimumConfidenceScore = 0.5;

  // ── Urine strip parameters ─────────────────────────────────────────────────
  static const List<String> urineStripParameters = [
    'leukocytes',
    'nitrite',
    'urobilinogen',
    'protein',
    'ph',
    'blood',
    'specificGravity',
    'ketone',
    'bilirubin',
    'glucose',
  ];
}
