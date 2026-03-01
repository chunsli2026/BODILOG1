import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/constants/app_constants.dart';
import '../models/health_reading.dart';

/// Singleton helper that manages the SQLite database lifecycle.
///
/// Call [DatabaseHelper.instance] to obtain the shared instance, then use
/// [database] to get an open [Database] handle.
class DatabaseHelper {
  DatabaseHelper._internal();

  /// The single shared instance.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  /// Returns an open [Database], initialising it on first access.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE test_results (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp       TEXT    NOT NULL,
        strip_image_path TEXT,
        overall_status  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE parameter_results (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        test_id          INTEGER NOT NULL REFERENCES test_results(id),
        parameter_name   TEXT    NOT NULL,
        detected_value   TEXT,
        severity         TEXT,
        confidence_score REAL,
        lab_l            REAL,
        lab_a            REAL,
        lab_b            REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE health_readings (
        id           TEXT PRIMARY KEY,
        device_type  TEXT NOT NULL,
        device_id    TEXT NOT NULL,
        device_name  TEXT NOT NULL,
        timestamp    TEXT NOT NULL,
        values_json  TEXT NOT NULL,
        unit         TEXT NOT NULL,
        raw_data_hex TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tremor_sessions (
        id                     TEXT PRIMARY KEY,
        device_id              TEXT NOT NULL,
        timestamp              TEXT NOT NULL,
        duration_seconds       INTEGER,
        sample_rate_hz         REAL,
        updrs_score            INTEGER,
        dominant_frequency_hz  REAL,
        tremor_ratio           REAL,
        tremor_power           REAL,
        total_power            REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE tremor_raw_data (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id   TEXT NOT NULL REFERENCES tremor_sessions(id),
        timestamp_ms INTEGER NOT NULL,
        accel_x      REAL,
        accel_y      REAL,
        accel_z      REAL,
        gyro_x       REAL,
        gyro_y       REAL,
        gyro_z       REAL
      )
    ''');

    await _createPairedDevicesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPairedDevicesTable(db);
    }
  }

  Future<void> _createPairedDevicesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paired_devices (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        type            TEXT NOT NULL,
        service_uuid    TEXT NOT NULL,
        last_connected  TEXT,
        last_reading    TEXT
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // HealthReading CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a [HealthReading] into the `health_readings` table.
  ///
  /// Replaces an existing row with the same [HealthReading.id].
  Future<void> insertHealthReading(HealthReading reading) async {
    final db = await database;
    await db.insert(
      'health_readings',
      reading.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns [HealthReading]s for a specific [deviceId], optionally filtered
  /// by date range.
  Future<List<HealthReading>> getReadingsByDeviceId(
    String deviceId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final where = StringBuffer('device_id = ?');
    final args = <dynamic>[deviceId];

    if (startDate != null) {
      where.write(' AND timestamp >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.write(' AND timestamp <= ?');
      args.add(endDate.toIso8601String());
    }

    final rows = await db.query(
      'health_readings',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'timestamp DESC',
    );
    return rows.map(HealthReading.fromMap).toList();
  }

  /// Returns all [HealthReading]s, optionally filtered by date range.
  Future<List<HealthReading>> getAllReadings({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String? where;
    final args = <dynamic>[];

    if (startDate != null && endDate != null) {
      where = 'timestamp >= ? AND timestamp <= ?';
      args.addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
    } else if (startDate != null) {
      where = 'timestamp >= ?';
      args.add(startDate.toIso8601String());
    } else if (endDate != null) {
      where = 'timestamp <= ?';
      args.add(endDate.toIso8601String());
    }

    final rows = await db.query(
      'health_readings',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
    );
    return rows.map(HealthReading.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Paired device CRUD
  // ---------------------------------------------------------------------------

  /// Inserts or replaces a paired device row.
  ///
  /// [deviceMap] must contain the keys: `id`, `name`, `type`, `service_uuid`,
  /// and optionally `last_connected`, `last_reading`.
  Future<void> insertPairedDevice(Map<String, dynamic> deviceMap) async {
    final db = await database;
    await db.insert(
      'paired_devices',
      deviceMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all paired devices as raw row maps.
  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    final db = await database;
    return db.query('paired_devices', orderBy: 'name ASC');
  }

  /// Deletes the paired device with [deviceId].
  Future<void> deletePairedDevice(String deviceId) async {
    final db = await database;
    await db.delete(
      'paired_devices',
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  /// Updates the `last_connected` timestamp for the paired device with
  /// [deviceId].
  Future<void> updatePairedDeviceTimestamp(
    String deviceId,
    DateTime lastConnected,
  ) async {
    final db = await database;
    await db.update(
      'paired_devices',
      {'last_connected': lastConnected.toIso8601String()},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }
}
