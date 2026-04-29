import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_shrine/data/sqlite_constants.dart';

/// Granularity for date-based aggregation in [SqliteHelpers.getLedgerSummary].
enum DateGranularity { day, month, year }

/// A utility class providing static methods to read from and write to local
/// SQLite storage.
///
/// **SQLite schema:**
/// ```
/// shrines
///   ├── shrine_name   TEXT PRIMARY KEY
///   ├── shrine_color   TEXT NOT NULL
///   └── is_deleted     INTEGER NOT NULL DEFAULT 0
///
/// time_ledger
///   ├── id               INTEGER PRIMARY KEY AUTOINCREMENT
///   ├── shrine_name      TEXT NOT NULL
///   ├── seconds_tracked  INTEGER NOT NULL
///   ├── start_timestamp  TEXT NOT NULL   (ISO 8601)
///   └── is_deleted       INTEGER NOT NULL DEFAULT 0
///
/// technical_records          (always exactly one row)
///   ├── last_update   TEXT   (ISO 8601, nullable)
///   └── last_sync     TEXT   (ISO 8601, nullable)
/// ```
///
/// **Methods:**
///
/// *Database:*
/// - [localDbInit]          — opens/creates the DB and all tables.
///
/// *Shrines:*
/// - [getUserShrines]       — reads all shrine rows.
/// - [addShrine]            — inserts a shrine row.
/// - [modifyShrine]         — updates shrine name and/or color.
///
/// *Time ledger:*
/// - [getLedgerSummary]     — aggregates seconds by shrine + date granularity.
/// - [addLedgerRecord]      — inserts a time-tracking row.
/// - [hasLedgerRecord]      — checks if a record exists for shrine + timestamp.
/// - [updateLedgerSeconds]  — updates seconds on a matching ledger row.
///
/// *Technical records:*
/// - [getTechnicalRecord]   — reads the single technical-records row.
/// - [updateTechnicalRecord]— updates last_update and/or last_sync.
/// ```
class SqliteHelpers {
  // Private constructor — this class should not be instantiated.
  SqliteHelpers._();

  /// Cached database instance.
  static Database? _db;

  // ---------------------------------------------------------------------------
  // 0. Initialise the local database
  // ---------------------------------------------------------------------------

  /// Opens (or creates) the local SQLite database and creates the `shrines`,
  /// `time_ledger`, and `technical_records` tables if they do not already exist.
  ///
  /// Should be called once at app startup before any other [SqliteHelpers] method.
  static Future<Database> localDbInit() async {
    if (_db != null) return _db!;

    final dbPath = join(await getDatabasesPath(), SqliteConstants.dbName);

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${SqliteConstants.shrinesTable} (
            ${SqliteConstants.colShrineName}  TEXT PRIMARY KEY,
            ${SqliteConstants.colShrineColor} TEXT NOT NULL,
            ${SqliteConstants.colIsDeleted}   INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE ${SqliteConstants.ledgerTable} (
            ${SqliteConstants.colId}              INTEGER PRIMARY KEY AUTOINCREMENT,
            ${SqliteConstants.colShrineName}       TEXT NOT NULL,
            ${SqliteConstants.colSecondsTracked}   INTEGER NOT NULL,
            ${SqliteConstants.colStartTimestamp}   TEXT NOT NULL,
            ${SqliteConstants.colIsDeleted}        INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE ${SqliteConstants.technicalRecordsTable} (
            ${SqliteConstants.colLastUpdate}  TEXT,
            ${SqliteConstants.colLastSync}    TEXT
          )
        ''');

        // Seed the single technical-records row.
        await db.insert(SqliteConstants.technicalRecordsTable, {
          SqliteConstants.colLastUpdate: null,
          SqliteConstants.colLastSync: null,
        });
      },
    );

    return _db!;
  }

  /// Returns the database instance, initialising it if necessary.
  static Future<Database> get _database async {
    return _db ?? await localDbInit();
  }

  /// Stamps `technical_records.last_update` with the current timestamp.
  ///
  /// Called internally by every writing method so the technical record always
  /// reflects the most recent local write.
  static Future<void> _stampLastUpdate() async {
    final db = await _database;
    await db.update(SqliteConstants.technicalRecordsTable, {
      SqliteConstants.colLastUpdate: DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // 1. Read all shrines
  // ---------------------------------------------------------------------------

  /// Reads every row from the `shrines` table.
  ///
  /// Returns a list of maps, each containing `shrine_name` and `shrine_color`.
  static Future<List<Map<String, dynamic>>> getUserShrines() async {
    final db = await _database;
    return db.query(
      SqliteConstants.shrinesTable,
      where: '${SqliteConstants.colIsDeleted} = 0',
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Add a shrine
  // ---------------------------------------------------------------------------

  /// Inserts a new row into the `shrines` table.
  ///
  /// Returns the shrine name used as the primary key.
  static Future<String> addShrine({
    required String shrineName,
    required String shrineColor,
  }) async {
    final db = await _database;

    final existing = await db.query(
      SqliteConstants.shrinesTable,
      where: '${SqliteConstants.colShrineName} = ?',
      whereArgs: [shrineName],
    );
    if (existing.isNotEmpty) {
      final isDeleted = existing.first[SqliteConstants.colIsDeleted] as int;
      if (isDeleted == 1) {
        await db.update(
          SqliteConstants.shrinesTable,
          {SqliteConstants.colIsDeleted: 0},
          where: '${SqliteConstants.colShrineName} = ?',
          whereArgs: [shrineName],
        );
        await _stampLastUpdate();
        return shrineName;
      }
      return '';
    }

    await db.insert(SqliteConstants.shrinesTable, {
      SqliteConstants.colShrineName: shrineName,
      SqliteConstants.colShrineColor: shrineColor,
      SqliteConstants.colIsDeleted: 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _stampLastUpdate();
    return shrineName;
  }

  // ---------------------------------------------------------------------------
  // 3. Modify shrine name and/or color
  // ---------------------------------------------------------------------------

  /// Updates the shrine row identified by [currentName].
  ///
  /// If [newName] is provided the row is re-created under the new name
  /// (SQLite primary keys are immutable in practice).
  /// If [newColor] is provided the `shrine_color` column is updated.
  ///
  /// Throws a [StateError] if no shrine with [currentName] exists.
  static Future<void> modifyShrine({
    required String currentName,
    String? newName,
    String? newColor,
  }) async {
    final db = await _database;

    // Verify the shrine exists.
    final rows = await db.query(
      SqliteConstants.shrinesTable,
      where: '${SqliteConstants.colShrineName} = ?',
      whereArgs: [currentName],
    );

    if (rows.isEmpty) {
      throw StateError('No shrine found with name "$currentName"');
    }

    if (newName != null && newName != currentName) {
      // Re-create under new name (delete old + insert new).
      final oldRow = rows.first;
      await db.delete(
        SqliteConstants.shrinesTable,
        where: '${SqliteConstants.colShrineName} = ?',
        whereArgs: [currentName],
      );
      await db.insert(SqliteConstants.shrinesTable, {
        SqliteConstants.colShrineName: newName,
        SqliteConstants.colShrineColor:
            newColor ?? oldRow[SqliteConstants.colShrineColor],
        SqliteConstants.colIsDeleted: oldRow[SqliteConstants.colIsDeleted] ?? 0,
      });
    } else if (newColor != null) {
      await db.update(
        SqliteConstants.shrinesTable,
        {SqliteConstants.colShrineColor: newColor},
        where: '${SqliteConstants.colShrineName} = ?',
        whereArgs: [currentName],
      );
    }
    await _stampLastUpdate();
  }

  // ---------------------------------------------------------------------------
  // 3b. Soft-delete a shrine
  // ---------------------------------------------------------------------------

  /// Sets `is_deleted = 1` on the shrine identified by [shrineName].
  ///
  /// Throws a [StateError] if no shrine with [shrineName] exists.
  static Future<void> softDeleteShrine({required String shrineName}) async {
    final db = await _database;

    final count = await db.update(
      SqliteConstants.shrinesTable,
      {SqliteConstants.colIsDeleted: 1},
      where:
          '${SqliteConstants.colShrineName} = ? AND ${SqliteConstants.colIsDeleted} = 0',
      whereArgs: [shrineName],
    );

    if (count == 0) {
      throw StateError('No shrine found with name "$shrineName"');
    }

    await _stampLastUpdate();
  }

  // ---------------------------------------------------------------------------
  // 4. Read all ledger records — aggregated summary
  // ---------------------------------------------------------------------------

  /// Reads every row from `time_ledger` and returns cumulative
  /// `seconds_tracked` grouped by `shrine_name` and the date portion of
  /// `start_timestamp`, at the requested [granularity].
  ///
  /// Date key format per granularity:
  /// - [DateGranularity.day]   → `yyyy-MM-dd`
  /// - [DateGranularity.month] → `yyyy-MM`
  /// - [DateGranularity.year]  → `yyyy`
  ///
  /// Example result (day):
  /// ```dart
  /// {
  ///   'shrineName1': { '2026-03-10': 7200, '2026-03-09': 3600 },
  ///   'shrineName2': { '2026-03-10': 1800 },
  /// }
  /// ```
  static Future<Map<String, Map<String, int>>> getLedgerSummary({
    DateGranularity granularity = DateGranularity.day,
  }) async {
    final db = await _database;
    final rows = await db.query(SqliteConstants.ledgerTable);

    final result = <String, Map<String, int>>{};

    for (final row in rows) {
      final shrineName = row[SqliteConstants.colShrineName] as String;
      final seconds = row[SqliteConstants.colSecondsTracked] as int;
      final date = DateTime.parse(
        row[SqliteConstants.colStartTimestamp] as String,
      );

      final dateKey = switch (granularity) {
        DateGranularity.day =>
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        DateGranularity.month =>
          '${date.year}-${date.month.toString().padLeft(2, '0')}',
        DateGranularity.year => '${date.year}',
      };

      result.putIfAbsent(shrineName, () => <String, int>{});
      result[shrineName]![dateKey] =
          (result[shrineName]![dateKey] ?? 0) + seconds;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // 5. Add a record to time_ledger
  // ---------------------------------------------------------------------------

  /// Inserts a new row into the `time_ledger` table.
  ///
  /// [startTimestamp] should be a [DateTime]; it is stored as ISO 8601.
  ///
  /// Returns the auto-generated row ID.
  static Future<int> addLedgerRecord({
    required int secondsTracked,
    required String shrineName,
    required DateTime startTimestamp,
  }) async {
    final db = await _database;
    final id = await db.insert(SqliteConstants.ledgerTable, {
      SqliteConstants.colShrineName: shrineName,
      SqliteConstants.colSecondsTracked: secondsTracked,
      SqliteConstants.colStartTimestamp: startTimestamp.toIso8601String(),
      SqliteConstants.colIsDeleted: 0,
    });
    await _stampLastUpdate();
    return id;
  }

  // ---------------------------------------------------------------------------
  // 6. Check if a ledger record exists
  // ---------------------------------------------------------------------------

  /// Returns `true` if `time_ledger` contains at least one row with the given
  /// [shrineName] **and** [startTimestamp].
  static Future<bool> hasLedgerRecord({
    required String shrineName,
    required DateTime startTimestamp,
  }) async {
    final db = await _database;
    final rows = await db.query(
      SqliteConstants.ledgerTable,
      where:
          '${SqliteConstants.colShrineName} = ? AND ${SqliteConstants.colStartTimestamp} = ?',
      whereArgs: [shrineName, startTimestamp.toIso8601String()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // 7. Modify seconds_tracked for a matching record
  // ---------------------------------------------------------------------------

  /// Updates `seconds_tracked` on the first ledger row whose `shrine_name`
  /// equals [shrineName] and `start_timestamp` equals [startTimestamp].
  ///
  /// Throws a [StateError] if no matching row is found.
  static Future<void> updateLedgerSeconds({
    required String shrineName,
    required DateTime startTimestamp,
    required int secondsTracked,
  }) async {
    final db = await _database;
    final count = await db.update(
      SqliteConstants.ledgerTable,
      {SqliteConstants.colSecondsTracked: secondsTracked},
      where:
          '${SqliteConstants.colShrineName} = ? AND ${SqliteConstants.colStartTimestamp} = ?',
      whereArgs: [shrineName, startTimestamp.toIso8601String()],
    );

    if (count == 0) {
      throw StateError(
        'No ledger record found for shrine "$shrineName" at $startTimestamp',
      );
    }
    await _stampLastUpdate();
  }

  // ---------------------------------------------------------------------------
  // 8. Read the technical record
  // ---------------------------------------------------------------------------

  /// Reads the single row from `technical_records`.
  ///
  /// Returns a map with `last_update` and `last_sync` (ISO 8601 strings or
  /// `null`), or `null` if the row is missing.
  static Future<Map<String, dynamic>?> getTechnicalRecord() async {
    final db = await _database;
    final rows = await db.query(
      SqliteConstants.technicalRecordsTable,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ---------------------------------------------------------------------------
  // 9. Update the technical record
  // ---------------------------------------------------------------------------

  /// Updates `last_update` and/or `last_sync` on the single
  /// `technical_records` row.
  ///
  /// Only the provided (non-null) fields are written. If both are `null` the
  /// method returns without touching the database.
  static Future<void> updateTechnicalRecord({
    DateTime? lastUpdate,
    DateTime? lastSync,
  }) async {
    final updates = <String, dynamic>{
      if (lastUpdate != null)
        SqliteConstants.colLastUpdate: lastUpdate.toIso8601String(),
      if (lastSync != null)
        SqliteConstants.colLastSync: lastSync.toIso8601String(),
    };
    if (updates.isEmpty) return;

    final db = await _database;
    await db.update(SqliteConstants.technicalRecordsTable, updates);
  }

  // ---------------------------------------------------------------------------
  // 10. Sync helpers — raw read / write (no _stampLastUpdate)
  // ---------------------------------------------------------------------------

  /// Returns all rows from the `time_ledger` table without aggregation.
  ///
  /// Used by [SyncHelpers] to read raw ledger data for syncing.
  static Future<List<Map<String, dynamic>>> getLedgerRecords() async {
    final db = await _database;
    return db.query(SqliteConstants.ledgerTable);
  }

  /// Deletes all rows from the `shrines` table.
  static Future<void> clearShrines() async {
    final db = await _database;
    await db.delete(SqliteConstants.shrinesTable);
  }

  /// Deletes all rows from the `time_ledger` table.
  static Future<void> clearLedger() async {
    final db = await _database;
    await db.delete(SqliteConstants.ledgerTable);
  }

  /// Inserts a shrine row with explicit `is_deleted` value.
  ///
  /// Does **not** call [_stampLastUpdate] — intended for sync operations only.
  static Future<void> insertShrineRaw({
    required String shrineName,
    required String shrineColor,
    required int isDeleted,
  }) async {
    final db = await _database;
    await db.insert(SqliteConstants.shrinesTable, {
      SqliteConstants.colShrineName: shrineName,
      SqliteConstants.colShrineColor: shrineColor,
      SqliteConstants.colIsDeleted: isDeleted,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Inserts a ledger row with explicit `is_deleted` value.
  ///
  /// Does **not** call [_stampLastUpdate] — intended for sync operations only.
  static Future<void> insertLedgerRaw({
    required String shrineName,
    required int secondsTracked,
    required DateTime startTimestamp,
    required int isDeleted,
  }) async {
    final db = await _database;
    await db.insert(SqliteConstants.ledgerTable, {
      SqliteConstants.colShrineName: shrineName,
      SqliteConstants.colSecondsTracked: secondsTracked,
      SqliteConstants.colStartTimestamp: startTimestamp.toIso8601String(),
      SqliteConstants.colIsDeleted: isDeleted,
    });
  }
}
