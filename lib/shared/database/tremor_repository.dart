import 'package:sqflite/sqflite.dart';

import '../../core/error/failures.dart';
import '../../core/error/result.dart';
import '../../features/tremor/models/sensor_data.dart';
import '../../features/tremor/models/tremor_session.dart';
import 'database_helper.dart';

/// Repository for persisting and querying tremor session data.
class TremorRepository {
  TremorRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  // ── Write ───────────────────────────────────────────────────────────────

  /// Insert a [TremorSession] and its optional raw sensor data.
  ///
  /// Raw data is inserted in batches of 250 rows per transaction for
  /// performance.
  Future<Result<void>> insertTremorSession(TremorSession session) async {
    try {
      final db = await _helper.database;
      await db.transaction((txn) async {
        final row = session.toMap();
        // Map field names to DB column names.
        await txn.insert(
          'tremor_sessions',
          {
            'id': row['id'],
            'device_id': row['device_id'],
            'timestamp': row['timestamp'],
            'duration_seconds': row['duration_seconds'],
            'sample_rate_hz': row['sampling_rate'],
            'updrs_score': row['updrs_score'],
            'dominant_frequency_hz': row['dominant_frequency'],
            'tremor_ratio': row['tremor_ratio'],
            'tremor_power': row['tremor_power'],
            'total_power': row['total_power'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Batched raw-data inserts.
        final rawData = session.rawData;
        if (rawData != null && rawData.isNotEmpty) {
          const batchSize = 250;
          for (var offset = 0; offset < rawData.length; offset += batchSize) {
            final end = (offset + batchSize).clamp(0, rawData.length);
            final batch = txn.batch();
            for (final s in rawData.sublist(offset, end)) {
              batch.insert('tremor_raw_data', {
                'session_id': session.id,
                'timestamp_ms': s.timestampMs,
                'accel_x': s.accelX,
                'accel_y': s.accelY,
                'accel_z': s.accelZ,
                'gyro_x': s.gyroX,
                'gyro_y': s.gyroY,
                'gyro_z': s.gyroZ,
              });
            }
            await batch.commit(noResult: true);
          }
        }
      });
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to insert tremor session: $e'));
    }
  }

  // ── Read ────────────────────────────────────────────────────────────────

  /// Return up to [limit] sessions ordered by timestamp descending.
  Future<Result<List<TremorSession>>> getTremorSessions({
    int limit = 50,
  }) async {
    try {
      final db = await _helper.database;
      final rows = await db.query(
        'tremor_sessions',
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return Success(rows.map(_rowToSession).toList());
    } catch (e) {
      return AppError(DatabaseFailure('Failed to load tremor sessions: $e'));
    }
  }

  /// Return a single session by [id], optionally including raw sensor data.
  Future<Result<TremorSession?>> getTremorSessionById(
    String id, {
    bool includeRawData = false,
  }) async {
    try {
      final db = await _helper.database;
      final rows = await db.query(
        'tremor_sessions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      TremorSession session = _rowToSession(rows.first);

      if (includeRawData) {
        final rawRows = await db.query(
          'tremor_raw_data',
          where: 'session_id = ?',
          whereArgs: [id],
          orderBy: 'timestamp_ms ASC',
        );
        final rawData = rawRows.map(_rowToSensorData).toList();
        session = TremorSession(
          id: session.id,
          deviceId: session.deviceId,
          timestamp: session.timestamp,
          durationSeconds: session.durationSeconds,
          samplingRate: session.samplingRate,
          updrsScore: session.updrsScore,
          dominantFrequency: session.dominantFrequency,
          tremorRatio: session.tremorRatio,
          tremorPower: session.tremorPower,
          totalPower: session.totalPower,
          rawData: rawData,
        );
      }

      return Success(session);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to load tremor session: $e'));
    }
  }

  /// Return all sessions recorded by [deviceId].
  Future<Result<List<TremorSession>>> getTremorSessionsByDeviceId(
    String deviceId,
  ) async {
    try {
      final db = await _helper.database;
      final rows = await db.query(
        'tremor_sessions',
        where: 'device_id = ?',
        whereArgs: [deviceId],
        orderBy: 'timestamp DESC',
      );
      return Success(rows.map(_rowToSession).toList());
    } catch (e) {
      return AppError(
        DatabaseFailure('Failed to load sessions for device: $e'),
      );
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  /// Delete a session and all associated raw data rows.
  Future<Result<void>> deleteTremorSession(String id) async {
    try {
      final db = await _helper.database;
      await db.transaction((txn) async {
        await txn.delete(
          'tremor_raw_data',
          where: 'session_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'tremor_sessions',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return const Success(null);
    } catch (e) {
      return AppError(DatabaseFailure('Failed to delete tremor session: $e'));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  TremorSession _rowToSession(Map<String, dynamic> row) => TremorSession.fromMap({
        'id': row['id'],
        'device_id': row['device_id'],
        'timestamp': row['timestamp'],
        'duration_seconds': row['duration_seconds'],
        'sampling_rate': row['sample_rate_hz'],
        'updrs_score': row['updrs_score'],
        'dominant_frequency': row['dominant_frequency_hz'],
        'tremor_ratio': row['tremor_ratio'],
        'tremor_power': row['tremor_power'],
        'total_power': row['total_power'],
      });

  SensorData _rowToSensorData(Map<String, dynamic> row) =>
      SensorData.fromMap(row);
}
