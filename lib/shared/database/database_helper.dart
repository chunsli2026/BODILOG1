import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../core/constants/app_constants.dart';

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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE test_results (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp         TEXT    NOT NULL,
        strip_image_path  TEXT,
        strip_layout_name TEXT,
        overall_status    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE parameter_results (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        test_id              INTEGER NOT NULL REFERENCES test_results(id),
        parameter_name       TEXT    NOT NULL,
        detected_value       TEXT,
        severity             TEXT,
        confidence_score     REAL,
        lab_l                REAL,
        lab_a                REAL,
        lab_b                REAL,
        delta_e              REAL,
        ref_lab_l            REAL,
        ref_lab_a            REAL,
        ref_lab_b            REAL,
        normal_range         TEXT,
        clinical_significance TEXT
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add strip_layout_name to test_results
      await db.execute(
          'ALTER TABLE test_results ADD COLUMN strip_layout_name TEXT');

      // Add new columns to parameter_results
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN delta_e REAL');
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN ref_lab_l REAL');
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN ref_lab_a REAL');
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN ref_lab_b REAL');
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN normal_range TEXT');
      await db.execute(
          'ALTER TABLE parameter_results ADD COLUMN clinical_significance TEXT');
    }
  }
}
