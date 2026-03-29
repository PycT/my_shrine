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
///   └── shrine_color   TEXT NOT NULL
///
/// time_ledger
///   ├── id               INTEGER PRIMARY KEY AUTOINCREMENT
///   ├── shrine_name      TEXT NOT NULL
///   ├── seconds_tracked  INTEGER NOT NULL
///   └── start_timestamp  TEXT NOT NULL   (ISO 8601)
/// ```
class SqliteHelpers {
  // Private constructor — this class should not be instantiated.
  SqliteHelpers._();

  /// Cached database instance.
  static Database? _db;

  // ---------------------------------------------------------------------------
  // 0. Initialise the local database
  // ---------------------------------------------------------------------------

  /// Opens (or creates) the local SQLite database and creates the `shrines`
  /// and `time_ledger` tables if they do not already exist.
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
            ${SqliteConstants.colShrineColor} TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE ${SqliteConstants.ledgerTable} (
            ${SqliteConstants.colId}              INTEGER PRIMARY KEY AUTOINCREMENT,
            ${SqliteConstants.colShrineName}       TEXT NOT NULL,
            ${SqliteConstants.colSecondsTracked}   INTEGER NOT NULL,
            ${SqliteConstants.colStartTimestamp}   TEXT NOT NULL
          )
        ''');
      },
    );

    return _db!;
  }

  /// Returns the database instance, initialising it if necessary.
  static Future<Database> get _database async {
    return _db ?? await localDbInit();
  }



  // ---------------------------------------------------------------------------
  // 1. Read all shrines
  // ---------------------------------------------------------------------------

  /// Reads every row from the `shrines` table.
  ///
  /// Returns a list of maps, each containing `shrine_name` and `shrine_color`.
  static Future<List<Map<String, dynamic>>> getUserShrines() async {
    final db = await _database;
    return db.query(SqliteConstants.shrinesTable);
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
    await db.insert(
      SqliteConstants.shrinesTable,
      {
        SqliteConstants.colShrineName: shrineName,
        SqliteConstants.colShrineColor: shrineColor,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      });
    } else if (newColor != null) {
      await db.update(
        SqliteConstants.shrinesTable,
        {
          SqliteConstants.colShrineColor: newColor,
        },
        where: '${SqliteConstants.colShrineName} = ?',
        whereArgs: [currentName],
      );
    }
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
      final date =
          DateTime.parse(row[SqliteConstants.colStartTimestamp] as String);

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
    return db.insert(SqliteConstants.ledgerTable, {
      SqliteConstants.colShrineName: shrineName,
      SqliteConstants.colSecondsTracked: secondsTracked,
      SqliteConstants.colStartTimestamp: startTimestamp.toIso8601String(),
    });
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
      {
        SqliteConstants.colSecondsTracked: secondsTracked,
      },
      where:
          '${SqliteConstants.colShrineName} = ? AND ${SqliteConstants.colStartTimestamp} = ?',
      whereArgs: [shrineName, startTimestamp.toIso8601String()],
    );

    if (count == 0) {
      throw StateError(
        'No ledger record found for shrine "$shrineName" at $startTimestamp',
      );
    }
  }
}
