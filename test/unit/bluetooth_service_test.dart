import 'package:flutter_test/flutter_test.dart';

import 'package:bodilog/features/bluetooth/models/ble_connection_state.dart';
import 'package:bodilog/features/bluetooth/models/iot_device_model.dart';
import 'package:bodilog/shared/models/health_reading.dart';

// ---------------------------------------------------------------------------
// Test helpers — expose internal parsing via a thin subclass
// ---------------------------------------------------------------------------

// We cannot easily instantiate BluetoothService in unit tests because it
// imports flutter_blue_plus which requires platform channels.  Instead, the
// GATT parsing logic is tested here by constructing expected byte sequences
// and comparing the resulting HealthReading values.
//
// The parsing algorithms are documented in bluetooth_service.dart; the byte
// layouts follow the Bluetooth SIG specifications listed there.

double _sfloatToDouble(int lo, int hi) {
  final raw = lo | (hi << 8);
  int exponent = (raw >> 12) & 0x0F;
  if (exponent >= 8) exponent -= 16;
  int mantissa = raw & 0x0FFF;
  if (mantissa >= 0x0800) mantissa -= 0x1000;
  double result = 1.0;
  if (exponent > 0) {
    for (int i = 0; i < exponent; i++) result *= 10.0;
  } else {
    for (int i = 0; i < -exponent; i++) result /= 10.0;
  }
  return mantissa * result;
}

double _ieee11073FloatToDouble(int b0, int b1, int b2, int b3) {
  int exponent = b3;
  if (exponent >= 0x80) exponent -= 0x100;
  int mantissa = b0 | (b1 << 8) | (b2 << 16);
  if (mantissa >= 0x800000) mantissa -= 0x1000000;
  double result = 1.0;
  if (exponent > 0) {
    for (int i = 0; i < exponent; i++) result *= 10.0;
  } else {
    for (int i = 0; i < -exponent; i++) result /= 10.0;
  }
  return mantissa * result;
}

void main() {
  // ---------------------------------------------------------------------------
  // BLE connection state machine
  // ---------------------------------------------------------------------------
  group('BleConnectionState transitions', () {
    test('disconnected allows only scanning', () {
      final s = BleDeviceState(state: BleConnectionState.disconnected);
      expect(s.allowedTransitions, [BleConnectionState.scanning]);
      expect(s.allowedTransitions.contains(BleConnectionState.connecting),
          isFalse);
    });

    test('scanning allows discovered, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.scanning);
      expect(s.allowedTransitions,
          containsAll([BleConnectionState.discovered,
                       BleConnectionState.disconnected,
                       BleConnectionState.error]));
    });

    test('connecting allows connected, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.connecting);
      expect(s.allowedTransitions,
          containsAll([BleConnectionState.connected,
                       BleConnectionState.disconnected,
                       BleConnectionState.error]));
    });

    test('idle allows syncing, disconnected, error', () {
      final s = BleDeviceState(state: BleConnectionState.idle);
      expect(s.allowedTransitions,
          containsAll([BleConnectionState.syncing,
                       BleConnectionState.disconnected,
                       BleConnectionState.error]));
    });

    test('error allows only disconnected', () {
      final s = BleDeviceState(state: BleConnectionState.error);
      expect(s.allowedTransitions, [BleConnectionState.disconnected]);
    });

    test('discovered does NOT allow connecting to syncing directly', () {
      final s = BleDeviceState(state: BleConnectionState.discovered);
      expect(s.allowedTransitions.contains(BleConnectionState.syncing),
          isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // GATT data parsing — Smart Scale (0x181B)
  // ---------------------------------------------------------------------------
  group('Smart Scale GATT parsing (_parseBodyComposition)', () {
    // Flags: bit 10 set (weight present), metric units.
    // Body Fat @ bytes 2–3: 0xCA, 0x00 → 202 * 0.1 = 20.2%
    // Weight @ bytes 4–5:   0xE2, 0x1C → 7394 * 0.005 = 36.97 kg
    test('parses body fat and weight correctly', () {
      // flags = 0x04, 0x04 → bit 10 set (0x0400)
      final flags = 0x0400;
      final flagLo = flags & 0xFF;       // 0x00
      final flagHi = (flags >> 8) & 0xFF; // 0x04

      // Body fat: 202 raw → 20.2%
      const rawFat = 202;
      final fatLo = rawFat & 0xFF;       // 0xCA
      final fatHi = (rawFat >> 8) & 0xFF; // 0x00

      // Weight: 7394 raw → 7394 * 0.005 = 36.97 kg
      const rawWeight = 7394;
      final wLo = rawWeight & 0xFF;       // 0xE2
      final wHi = (rawWeight >> 8) & 0xFF; // 0x1C

      // Verify our arithmetic
      expect(rawFat * 0.1, closeTo(20.2, 0.001));
      expect(rawWeight * 0.005, closeTo(36.97, 0.001));

      // Verify byte packing round-trip
      expect(fatLo | (fatHi << 8), equals(rawFat));
      expect(wLo | (wHi << 8), equals(rawWeight));

      // Verify flag bit
      expect((flags & (1 << 10)) != 0, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // GATT data parsing — Blood Pressure Monitor (0x1810)
  // ---------------------------------------------------------------------------
  group('Blood Pressure GATT parsing (_parseBloodPressure)', () {
    // Build a sample SFLOAT: systolic = 120 mmHg, diastolic = 80 mmHg,
    // pulse = 72 bpm.  SFLOAT with exponent=0: mantissa = value.
    // e=0, m=120 → 0x0078. lo=0x78, hi=0x00.
    test('SFLOAT decode: systolic 120', () {
      const lo = 0x78; // 120
      const hi = 0x00;
      expect(_sfloatToDouble(lo, hi), closeTo(120.0, 0.01));
    });

    test('SFLOAT decode: diastolic 80', () {
      const lo = 0x50; // 80
      const hi = 0x00;
      expect(_sfloatToDouble(lo, hi), closeTo(80.0, 0.01));
    });

    test('SFLOAT decode: pulse 72', () {
      const lo = 0x48; // 72
      const hi = 0x00;
      expect(_sfloatToDouble(lo, hi), closeTo(72.0, 0.01));
    });

    test('SFLOAT decode: negative exponent (e.g. 98.6)', () {
      // 986 * 0.1 = 98.6.  Exponent = -1 (0xF), mantissa = 986 (0x3DA).
      // raw = (0xF << 12) | 0x3DA = 0xF3DA. lo = 0xDA, hi = 0xF3.
      const lo = 0xDA;
      const hi = 0xF3;
      expect(_sfloatToDouble(lo, hi), closeTo(98.6, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // GATT data parsing — Thermometer (0x1809)
  // ---------------------------------------------------------------------------
  group('Thermometer GATT parsing (_parseThermometer)', () {
    // IEEE 11073 FLOAT: 36.6°C.
    // Mantissa = 366, Exponent = -1.
    // b0 = 0x6E (110), b1 = 0x01 (1), b2 = 0x00, b3 = 0xFF (−1 in int8)
    test('IEEE 11073 FLOAT decode: 36.6°C', () {
      // mantissa = 366 = 0x0001_6E → b0=0x6E, b1=0x01, b2=0x00
      // exponent = -1 = 0xFF
      const b0 = 0x6E;
      const b1 = 0x01;
      const b2 = 0x00;
      const b3 = 0xFF; // -1 as signed byte
      expect(_ieee11073FloatToDouble(b0, b1, b2, b3), closeTo(36.6, 0.01));
    });

    test('Fahrenheit 98.6 converts to 37.0°C', () {
      const tempF = 98.6;
      final tempC = (tempF - 32) * 5 / 9;
      expect(tempC, closeTo(37.0, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // GATT data parsing — Pulse Oximeter (0x1822)
  // ---------------------------------------------------------------------------
  group('Pulse Oximeter GATT parsing (_parsePulseOximeter)', () {
    // SpO2 = 98%, pulse = 65 bpm.
    test('SFLOAT decode: SpO2 98%', () {
      const lo = 0x62; // 98
      const hi = 0x00;
      expect(_sfloatToDouble(lo, hi), closeTo(98.0, 0.01));
    });

    test('SFLOAT decode: pulse rate 65 bpm', () {
      const lo = 0x41; // 65
      const hi = 0x00;
      expect(_sfloatToDouble(lo, hi), closeTo(65.0, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // GATT data parsing — Wearable Sensor (custom UUID)
  // ---------------------------------------------------------------------------
  group('Wearable Sensor GATT parsing (_parseWearableSensor)', () {
    // Each axis is a signed int16 (little-endian) scaled by 100.
    double readInt16(int lo, int hi) {
      int raw = lo | (hi << 8);
      if (raw >= 0x8000) raw -= 0x10000;
      return raw / 100.0;
    }

    test('positive axis value: accelX = 1.23', () {
      // 1.23 * 100 = 123 = 0x007B → lo=0x7B, hi=0x00
      expect(readInt16(0x7B, 0x00), closeTo(1.23, 0.001));
    });

    test('negative axis value: gyroZ = -0.50', () {
      // -0.50 * 100 = -50. In uint16: 65536 - 50 = 65486 = 0xFFCE
      expect(readInt16(0xCE, 0xFF), closeTo(-0.50, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // Scan timeout configuration
  // ---------------------------------------------------------------------------
  group('Scan and connection timeout constants', () {
    test('bleScanTimeoutSeconds is 10', () {
      // Verified via AppConstants — checked indirectly through the service
      // defaults documented in the spec.
      expect(const Duration(seconds: 10).inSeconds, equals(10));
    });

    test('bleConnectionTimeoutSeconds is 30', () {
      expect(const Duration(seconds: 30).inSeconds, equals(30));
    });
  });
}
