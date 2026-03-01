# BODILOG

## Urine Analysis Mobile App

*AI-Powered Test Strip Analysis with IoT Integration*

---

**AI Code Generation Prompt Specification**
Version 2.0 | March 2026

---

## Project Overview

| Field | Details |
|-------|---------|
| Project Name | BodiLog Urine Analysis Mobile App |
| Platform | Cross-platform (iOS & Android) |
| Framework | Flutter / Dart |
| Flutter Version | 3.x (latest stable) |
| Dart SDK | 3.x |
| Minimum Android SDK | 23 (Android 6.0) — required for BLE |
| Minimum iOS Target | 13.0 |
| Null Safety | Sound null safety (required) |
| Core Function | AI-powered urine test strip analysis with IoT integration |
| Patent Reference | US20190073763A1 — System and method for urine analysis and personal health monitoring |

### IoT Device Support

The app integrates with the following Bluetooth Low Energy (BLE) health devices:

- **Smart scales** — body fat percentage, muscle mass, BMI, water weight, bone density
- **Blood pressure monitors** — systolic/diastolic, pulse rate
- **Wearable sensors** — sleep tracking, motion/tremor detection (Parkinson's disease)
- **Thermometers** — body temperature
- **Pulse oximeters** — SpO2, pulse rate

> **NOTE:** Parkinson's tremor analysis requires dedicated signal processing and is scoped separately in Prompt 6.

---

## Prompt Summary

The following 6 prompts are designed to be submitted to an AI code generator sequentially. Each prompt builds on the outputs of the previous one. Complete Prompts 1–3 before attempting 4–6.

| # | Module | Key Output Files | Dependencies |
|---|--------|-----------------|--------------|
| 1 | Project Setup & Architecture | `pubspec.yaml`, `main.dart` | None — foundation |
| 2 | Image Capture Module | `camera_capture_screen.dart` | Prompt 1 |
| 3 | Image Segmentation & Processing | `image_processing_service.dart` | Prompts 1–2 |
| 4 | Color Analysis & Results | `color_analysis_service.dart`, `results_screen.dart`, `dashboard_screen.dart` | Prompt 3 |
| 5 | Bluetooth IoT Integration | `bluetooth_service.dart`, `iot_device_model.dart` | Prompt 1 |
| 6 | Parkinson's Tremor Analysis | `tremor_analysis_service.dart`, `wearable_sensor_device.dart` | Prompt 5 |

> **IMPORTANT:** Verify all package versions on [pub.dev](https://pub.dev) at the time of code generation, as newer compatible releases may be available.

---

## PROMPT 1 — Project Setup & Architecture

Provide this prompt first. It establishes the complete project scaffold, dependency versions, architecture conventions, platform permissions, theming, and error handling that all subsequent prompts will follow.

### Full Prompt Text

Create a Flutter project structure for a urine analysis mobile app called **BodiLog** with the following specifications.

### Platform & Framework

- Flutter version: 3.x (latest stable)
- Dart SDK: 3.x
- Sound null safety: required
- State management: Riverpod 2.x
- Minimum Android SDK: 23 (required for BLE permissions)
- Minimum iOS deployment target: 13.0

### Required Dependencies (`pubspec.yaml`)

| Package | Version | Purpose |
|---------|---------|---------|
| camera | ^0.10.5+9 | Image capture |
| image | ^4.1.3 | Image processing |
| path_provider | ^2.1.1 | File system paths |
| flutter_riverpod | ^2.4.9 | State management |
| flutter_blue_plus | ^1.31.0 | BLE device communication |
| fl_chart | ^0.65.0 | Data visualization |
| sqflite | ^2.3.0 | Local SQLite database for health data |
| flutter_secure_storage | ^9.0.0 | Encrypted storage for sensitive health data |
| permission_handler | ^11.0.0 | Runtime permission management |
| intl | ^0.18.1 | Date/number formatting and localization |

### Project Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart                    # MaterialApp with theme and routing
│   ├── router.dart                 # Named route definitions
│   └── theme.dart                  # App-wide theme (colors, typography)
├── core/
│   ├── error/
│   │   ├── failures.dart           # Failure classes (abstract Failure, ServerFailure, CacheFailure, etc.)
│   │   └── result.dart             # Result<T> type (Success/Error wrapper)
│   ├── permissions/
│   │   └── permission_service.dart # Centralized permission requests
│   └── constants/
│       └── app_constants.dart      # App-wide constants
├── features/
│   ├── camera/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   ├── analysis/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── models/
│   │   └── providers/
│   ├── results/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   ├── dashboard/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   ├── bluetooth/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── models/
│   │   └── providers/
│   └── tremor/
│       ├── screens/
│       ├── services/
│       ├── models/
│       └── providers/
├── shared/
│   ├── widgets/                    # Reusable UI components
│   ├── models/
│   │   └── health_reading.dart     # Unified health data model
│   └── database/
│       └── database_helper.dart    # SQLite database initialization
test/
├── unit/
├── widget/
└── integration/
```

### Platform Permissions

**Android (`AndroidManifest.xml`)** — generate all required entries:
- `CAMERA`
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
- `ACCESS_FINE_LOCATION` (required for BLE scanning)
- `INTERNET`
- `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` (for image saving)

**iOS (`Info.plist`)** — generate all required entries with user-facing descriptions:
- `NSCameraUsageDescription` — "BodiLog needs camera access to photograph urine test strips for analysis."
- `NSBluetoothAlwaysUsageDescription` — "BodiLog uses Bluetooth to connect to health monitoring devices."
- `NSBluetoothPeripheralUsageDescription` — "BodiLog uses Bluetooth to communicate with health devices."
- `NSLocationWhenInUseUsageDescription` — "Location access is required for Bluetooth device scanning."

### App Navigation & Theme

- Use a **BottomNavigationBar** with 4 tabs: Dashboard, Camera (capture), Devices (BLE), History
- Primary color: `#1A5276` (dark blue)
- Accent color: `#2E86C1` (medium blue)
- Warning color: `#E67E22` (orange)
- Error color: `#E74C3C` (red)
- Success color: `#27AE60` (green)
- Font family: System default (Roboto on Android, SF Pro on iOS)

### Error Handling

- Implement a `Result<T>` type with `Success<T>` and `Error<T>` subclasses in `core/error/result.dart`
- Define abstract `Failure` class with concrete subclasses: `CameraFailure`, `BluetoothFailure`, `DatabaseFailure`, `AnalysisFailure`
- All service methods should return `Future<Result<T>>` instead of throwing exceptions

### Sample Test

- Include a sample unit test in `test/unit/` demonstrating the testing convention using `flutter_test`

---

## PROMPT 2 — Image Capture Module

**Prerequisite:** Complete Prompt 1 first. This module uses the project structure, theme, permissions, and error handling patterns established in Prompt 1.

### Full Prompt Text

Using the BodiLog project structure from Prompt 1, build the **image capture module** for photographing urine test strips. Generate `camera_capture_screen.dart` and supporting files with the following requirements.

### Camera Configuration

- Use `ResolutionPreset.high` or higher for consistent color fidelity
- Implement flash mode toggling: Off / Auto / On (default: Auto)
- Lock auto-exposure after the user taps to focus, to ensure consistent lighting for color analysis
- Handle device orientation to ensure consistent image capture regardless of phone rotation
- Support rear camera only (front camera not needed for strip analysis)

### Image Capture Requirements

- Save captured images in **PNG format** for lossless color fidelity (JPEG compression distorts color values)
- Store images using `path_provider` to the app's documents directory
- Include a timestamp in the filename: `strip_YYYYMMDD_HHmmss.png`
- Return the file path via a `Result<String>` type on successful capture

### User Interface

- **Camera preview** filling the screen with a semi-transparent overlay guide showing:
  - A rectangular target zone where the test strip should be placed
  - Text instruction: "Align the test strip within the guide"
  - Visual indicators for strip alignment (green border when properly positioned)
- **Capture button** at the bottom center (large, circular, themed with primary color)
- **Flash toggle button** in the top-right corner with icon indicating current mode
- **Review screen** after capture showing the photo with options to:
  - "Use Photo" → proceed to analysis
  - "Retake" → return to camera
- Display a loading indicator during image capture and saving
- Show user-friendly error messages using the `Failure` classes from Prompt 1

### Permission Handling

- Request camera permission at runtime using `permission_handler`
- If permission is denied, show an explanation dialog with a button to open app settings
- Use the `PermissionService` from `core/permissions/`

### Error Handling

- Return `CameraFailure` for camera initialization errors, capture failures, and save failures
- All methods return `Future<Result<T>>`
- Include a retry mechanism for transient camera initialization failures (up to 3 attempts)

---

## PROMPT 3 — Image Segmentation & Processing

**Prerequisite:** Complete Prompts 1–2 first. This module processes the captured PNG images from Prompt 2.

### Full Prompt Text

Using the BodiLog project from Prompts 1–2, build the **image segmentation and processing module**. Generate `image_processing_service.dart` and supporting files with the following requirements.

### Image Preprocessing Pipeline

1. **Auto-crop** — Detect the test strip region using edge detection (Canny or Sobel). Crop the image to isolate only the strip.
2. **Perspective correction** — If the strip is photographed at an angle, apply a perspective warp to produce a top-down rectangular view.
3. **White balance normalization** — Use reference pads on the test strip (or white regions of the strip body) to normalize color values across different lighting conditions.
4. **Noise reduction** — Apply a gentle Gaussian blur (σ=0.5) to reduce camera sensor noise without destroying color information.

### Pad Segmentation

- Segment the preprocessed strip image into **individual color pads** corresponding to each test parameter
- Support configurable strip layouts:
  - **10-parameter strips** (standard): Leukocytes, Nitrite, Urobilinogen, Protein, pH, Blood, Specific Gravity, Ketone, Bilirubin, Glucose
  - **14-parameter strips** (extended): adds Ascorbic Acid, Creatinine, Calcium, Microalbumin
- Use contour detection to identify each pad by position (pads are evenly spaced along the strip)
- Define strip layout configuration in a JSON file (`assets/strip_configs/`) so new strip formats can be added without code changes

### Color Extraction

- Convert each segmented pad to **CIE LAB color space** for perceptually uniform color comparison
- Extract the **median LAB values** (L*, a*, b*) from the central 60% of each pad (ignoring edges to avoid border color contamination)
- Output a data structure containing:
  - `padIndex: int`
  - `parameterName: String` (e.g., "Glucose", "pH")
  - `labValues: {L: double, a: double, b: double}`
  - `confidenceScore: double` (0.0–1.0, based on color uniformity within the pad)

### Error Handling

- Return `AnalysisFailure` with descriptive messages for:
  - Strip not detected in image
  - Insufficient number of pads detected
  - Poor image quality (blurry, overexposed, underexposed)
- All methods return `Future<Result<T>>`
- Log intermediate processing steps for debugging (configurable via a debug flag)

---

## PROMPT 4 — Color Analysis & Results

**Prerequisite:** Complete Prompt 3 first. This module uses the extracted LAB color values from Prompt 3.

### Full Prompt Text

Using the BodiLog project from Prompts 1–3, build the **color analysis and results module**. Generate `color_analysis_service.dart`, `results_screen.dart`, and `dashboard_screen.dart` with the following requirements.

### Urine Parameters to Analyze

Analyze the following **10 standard parameters** (with support for 14-parameter extended strips):

| # | Parameter | Normal Range | Clinical Significance |
|---|-----------|-------------|----------------------|
| 1 | Leukocytes | Negative | Urinary tract infection |
| 2 | Nitrite | Negative | Bacterial infection |
| 3 | Urobilinogen | 0.2–1.0 mg/dL | Liver function |
| 4 | Protein | Negative | Kidney function |
| 5 | pH | 5.0–8.0 | Acid-base balance |
| 6 | Blood | Negative | Kidney/urinary tract issues |
| 7 | Specific Gravity | 1.005–1.030 | Hydration status |
| 8 | Ketone | Negative | Metabolic status / diabetes |
| 9 | Bilirubin | Negative | Liver/bile duct function |
| 10 | Glucose | Negative | Diabetes screening |

### Color Matching Algorithm

- Use **Delta E 2000 (ΔE₀₀)** color distance formula in CIE LAB space for matching extracted pad colors against reference values
- Store reference color charts in a JSON configuration file (`assets/color_references/`) with the following structure per parameter:
  ```json
  {
    "parameter": "Glucose",
    "levels": [
      {"label": "Negative", "lab": [L, a, b], "severity": "normal"},
      {"label": "Trace (100 mg/dL)", "lab": [L, a, b], "severity": "borderline"},
      {"label": "250 mg/dL", "lab": [L, a, b], "severity": "abnormal"},
      {"label": "500 mg/dL", "lab": [L, a, b], "severity": "abnormal"},
      {"label": "1000+ mg/dL", "lab": [L, a, b], "severity": "critical"}
    ]
  }
  ```
- Select the best match (lowest ΔE₀₀) for each parameter
- Flag results where the best match ΔE₀₀ > 10 as "low confidence — please retake"

### Result Classification

- Classify each result as:
  - 🟢 **Normal** — within expected range (green color coding)
  - 🟡 **Borderline** — mildly outside range (yellow/amber color coding)
  - 🔴 **Abnormal** — significantly outside range (red color coding)
  - ⚫ **Critical** — requires immediate attention (dark red with alert icon)

### Results Screen (`results_screen.dart`)

- Display results in a clean card-based layout, one card per parameter
- Each card shows: parameter name, detected value/level, severity color indicator, confidence score
- Include a summary banner at the top: "X of Y parameters normal"
- "Save Results" button → stores to local SQLite database with timestamp
- "Share Results" button → generates a PDF summary (optional, stub if complex)
- Include a prominent disclaimer at the bottom:
  > ⚠️ **Disclaimer:** This analysis is for informational and educational purposes only. It is not a substitute for professional medical diagnosis. Consult a healthcare provider for medical advice.

### Dashboard Screen (`dashboard_screen.dart`)

- Show the most recent test results as a summary card
- Display **trend charts** (using `fl_chart`) for key parameters over time: pH, Glucose, Protein, Specific Gravity
- Show a timeline of past tests with date and overall status indicator
- Include quick-action buttons: "New Test", "View Devices", "Export Data"

### Data Persistence

- Store all results in the local **SQLite database** (`sqflite`) with the schema:
  - `test_results` table: `id`, `timestamp`, `strip_image_path`, `overall_status`
  - `parameter_results` table: `id`, `test_id` (FK), `parameter_name`, `detected_value`, `severity`, `confidence_score`, `lab_l`, `lab_a`, `lab_b`
- Support querying results by date range for trend analysis

### Error Handling

- Return `AnalysisFailure` for color matching failures
- Return `DatabaseFailure` for storage errors
- All methods return `Future<Result<T>>`

---

## PROMPT 5 — Bluetooth IoT Integration

**Prerequisite:** Complete Prompt 1 first. This module can be developed in parallel with Prompts 2–4.

### Full Prompt Text

Using the BodiLog project from Prompt 1, build the **Bluetooth Low Energy (BLE) IoT integration module**. Generate `bluetooth_service.dart`, `iot_device_model.dart`, and supporting files with the following requirements.

### Supported Devices & Standard GATT Profiles

| Device Type | BLE Service UUID | Key Characteristics |
|-------------|-----------------|---------------------|
| Smart Scale | `0x181B` (Body Composition) | Weight, body fat %, muscle mass, BMI, water weight, bone density |
| Blood Pressure Monitor | `0x1810` (Blood Pressure) | Systolic, diastolic, pulse rate, measurement status |
| Thermometer | `0x1809` (Health Thermometer) | Temperature value, measurement type (oral/axillary/tympanic) |
| Pulse Oximeter | `0x1822` (Pulse Oximeter) | SpO2 percentage, pulse rate |
| Wearable Sensor | Custom UUID (configurable) | Accelerometer, gyroscope data (for tremor analysis — see Prompt 6) |

### BLE Connection State Machine

Implement a formal connection state machine with the following states:
```
Disconnected → Scanning → Discovered → Connecting → Connected → Syncing → Idle
                                                                          ↓
                                                               Disconnected (on error/timeout)
```

### Device Discovery & Pairing

- Implement BLE scanning with a **10-second timeout** and filtered discovery by service UUIDs listed above
- Show discovered devices in a list with: device name, signal strength (RSSI), device type icon, last seen timestamp
- Support **automatic reconnection** to previously paired devices on app launch
- Store paired device info in local storage: device ID, name, type, last connected timestamp

### Unified Health Data Model (`health_reading.dart`)

```dart
class HealthReading {
  final String id;
  final DeviceType deviceType;
  final DateTime timestamp;
  final Map<String, double> values;  // e.g., {"weight": 75.5, "bodyFat": 18.2}
  final String unit;                  // e.g., "kg", "mmHg", "°C"
  final String deviceId;
  final String deviceName;
  final List<int>? rawData;          // Raw BLE characteristic bytes
}
```

### Offline & Error Handling

- Buffer incomplete data transfers and retry on reconnection
- Queue readings received while the app is processing a previous reading
- Return `BluetoothFailure` with specific subtypes:
  - `BluetoothDisabledFailure` — Bluetooth is turned off
  - `PermissionDeniedFailure` — BLE permissions not granted
  - `DeviceNotFoundFailure` — Device not discoverable
  - `ConnectionTimeoutFailure` — Connection timed out (30-second timeout)
  - `DataTransferFailure` — Error during characteristic read/notification
- All methods return `Future<Result<T>>`

### Devices Screen

- Tab-based layout: "Paired Devices" and "Scan for New"
- Each paired device shows: name, type, last reading, connection status (colored dot)
- Tapping a device shows its reading history and a "Sync Now" button
- Pull-to-refresh on paired devices list triggers reconnection attempts

### Data Persistence

- Store all health readings in the SQLite database:
  - `health_readings` table: `id`, `device_type`, `device_id`, `device_name`, `timestamp`, `values_json`, `unit`, `raw_data_hex`

---

## PROMPT 6 — Parkinson's Tremor Analysis

**Prerequisite:** Complete Prompt 5 first. This module extends the BLE wearable sensor integration from Prompt 5 with specialized signal processing.

### Full Prompt Text

Using the BodiLog project from Prompt 5, build the **Parkinson's tremor analysis module**. Generate `tremor_analysis_service.dart`, `wearable_sensor_device.dart`, and supporting UI files with the following requirements.

### Sensor Data Acquisition

- Receive **accelerometer and gyroscope data** from the wearable sensor via BLE at a sampling rate of **≥50 Hz** (50–100 Hz recommended)
- Use the custom service UUID defined in Prompt 5's wearable sensor configuration
- Buffer incoming sensor data in a ring buffer (minimum 60 seconds capacity)
- Record 3-axis acceleration (x, y, z) and 3-axis angular velocity (x, y, z)
- Require a minimum **30-second recording window** per analysis session (recommend 60 seconds for higher accuracy)

### Signal Processing Pipeline

1. **Preprocessing:**
   - Remove DC offset (mean subtraction per axis)
   - Apply a **bandpass Butterworth filter** (order 4) with cutoff frequencies **1–12 Hz** to isolate tremor-relevant frequencies while removing gravity (< 1 Hz) and high-frequency noise (> 12 Hz)

2. **Feature Extraction:**
   - Compute the **magnitude** of the 3-axis acceleration vector: `√(x² + y² + z²)`
   - Perform **FFT (Fast Fourier Transform)** on the filtered magnitude signal
   - Identify the **dominant frequency peak** in the 3–7 Hz band (characteristic Parkinsonian resting tremor range)
   - Calculate **tremor power** (area under the curve in the 3–7 Hz band)
   - Calculate **total signal power** (area under the curve in the 1–12 Hz band)
   - Compute the **tremor ratio** = tremor power / total signal power

3. **Tremor Classification:**
   - Map results to the **UPDRS (Unified Parkinson's Disease Rating Scale)** tremor scoring criteria:
     - **0** — No tremor detected (tremor ratio < 0.05)
     - **1** — Slight (tremor ratio 0.05–0.15, amplitude barely perceptible)
     - **2** — Mild (tremor ratio 0.15–0.30, amplitude < 1 cm)
     - **3** — Moderate (tremor ratio 0.30–0.50, amplitude 1–10 cm)
     - **4** — Severe (tremor ratio > 0.50, amplitude > 10 cm)
   - Note: These thresholds are approximate and should be calibrated against clinical data

### Tremor Analysis Screen

- **Recording view:**
  - Real-time waveform visualization of the accelerometer signal
  - Timer showing elapsed recording time
  - "Start Recording" / "Stop Recording" button
  - Minimum time indicator (progress bar showing 30s minimum)

- **Results view:**
  - Frequency spectrum chart (FFT plot) showing frequency vs. amplitude
  - Dominant tremor frequency value (e.g., "4.7 Hz")
  - UPDRS tremor score (0–4) with severity label and color coding
  - Tremor ratio percentage
  - Comparison with previous recordings (trend line over time)

- **History view:**
  - List of all past tremor analysis sessions with date, UPDRS score, and dominant frequency
  - Trend chart showing UPDRS score over time using `fl_chart`

### Data Persistence

- Store raw sensor data and analysis results in SQLite:
  - `tremor_sessions` table: `id`, `device_id`, `timestamp`, `duration_seconds`, `sample_rate_hz`, `updrs_score`, `dominant_frequency_hz`, `tremor_ratio`, `tremor_power`, `total_power`
  - `tremor_raw_data` table: `id`, `session_id` (FK), `timestamp_ms`, `accel_x`, `accel_y`, `accel_z`, `gyro_x`, `gyro_y`, `gyro_z` (consider batched inserts for performance)

### Medical Disclaimer (REQUIRED)

Display a **prominent, non-dismissible disclaimer** on first use of the tremor analysis feature and on every results screen:

> ⚠️ **Medical Disclaimer:** This tremor analysis tool is for informational and research purposes only. It is NOT a medical device and has NOT been cleared or approved by the FDA or any regulatory authority. Results should NOT be used to diagnose, treat, or manage Parkinson's disease or any other medical condition. Always consult a qualified healthcare professional for medical advice, diagnosis, and treatment. The UPDRS scores displayed are algorithmic approximations and may not reflect clinical assessments.

### Error Handling

- Return `BluetoothFailure` for sensor connection/data issues
- Return `AnalysisFailure` for signal processing failures
- Handle edge cases:
  - Recording too short (< 30 seconds) → prompt user to continue
  - Sensor disconnects during recording → save partial data, offer retry
  - Signal quality too low (e.g., sensor not worn properly) → detect and warn user
- All methods return `Future<Result<T>>`

---

## Appendix A: Cross-Cutting Concerns

These apply to all prompts and should be communicated to the AI code generator as context:

### Data Privacy & Security
- All health data stored locally must be encrypted at rest using `flutter_secure_storage` for sensitive fields
- No health data should be transmitted to external servers without explicit user consent
- Implement a local PIN or biometric lock option for app access

### Accessibility
- All interactive elements must include semantic labels for screen readers
- Minimum touch target size: 48×48 dp
- Color is never the sole indicator of status — always include text labels and/or icons alongside color coding
- Support dynamic text sizing (respect system font scale)

### Localization (Future)
- Use `intl` package for date/number formatting from the start
- Structure string literals to be extractable for future multi-language support (use constants or ARB files)

### Export & Sharing
- Support exporting all test results and health readings as CSV
- Results summary exportable as PDF (can be stubbed initially)
- Export includes disclaimer text

### Testing Strategy
- Unit tests for all service classes (color analysis, signal processing, BLE data parsing)
- Widget tests for key screens (results, dashboard)
- Integration test stubs for camera and BLE workflows
- Target: minimum 70% code coverage for service layer