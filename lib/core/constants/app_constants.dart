/// Application-wide constants for BodiLog.
class AppConstants {
  AppConstants._();

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName = 'BodiLog';

  // ── Database ───────────────────────────────────────────────────────────────
  static const String databaseName = 'bodilog.db';
  static const int databaseVersion = 1;

  // ── Storage ────────────────────────────────────────────────────────────────
  /// Sub-directory name inside the app documents directory used for images.
  static const String imageDirectoryName = 'strip_images';

  // ── Bluetooth ──────────────────────────────────────────────────────────────
  /// Duration in seconds to scan for nearby BLE devices.
  static const int bleScanTimeoutSeconds = 10;

  /// Duration in seconds to wait when establishing a BLE connection.
  static const int bleConnectionTimeoutSeconds = 30;

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
