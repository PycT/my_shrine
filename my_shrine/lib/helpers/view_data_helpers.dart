import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:my_shrine/data/default_shrines.dart';
import 'package:my_shrine/data/firestore_constants.dart';
import 'package:my_shrine/data/sqlite_constants.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/utils/user_helpers.dart';

/// Provides static methods that populate the data structures used by the main
/// application views.
///
/// **Methods:**
/// - [trackerViewPreload] — returns the list of [Shrine]s for the TrackerView
///   after performing the necessary local/remote DB initialisation and sync.
/// - [historyViewPreload] — returns the list of [TimeLedger] records from the
///   local DB, sorted by [TimeLedger.startTimestamp] in descending order.
class ViewDataHelpers {
  ViewDataHelpers._();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts SQLite shrine rows to [Shrine] objects, filtering out rows
  /// where `is_deleted == 1`.
  static List<Shrine> _sqliteRowsToShrines(List<Map<String, dynamic>> rows) {
    return rows
        .where((r) => (r[SqliteConstants.colIsDeleted] as int?) != 1)
        .map((r) => Shrine.fromSqliteRow(r))
        .toList();
  }

  /// Converts Firestore shrine docs to [Shrine] objects, filtering out docs
  /// where `is_deleted == true`.
  static List<Shrine> _firestoreDocsToShrines(List<Map<String, dynamic>> docs) {
    return docs
        .where((d) => d[FirestoreConstants.fieldIsDeleted] != true)
        .map((d) => Shrine.fromFirestoreDoc(d))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // trackerViewPreload
  // ---------------------------------------------------------------------------

  /// Sorts [shrines] by the number of non-deleted ledger records that fall in
  /// the one-month window ending at [referenceTime] (the timestamp of the
  /// latest record in the DB), descending.  Shrines with equal counts keep
  /// their relative order (stable sort).  Shrines absent from the ledger are
  /// placed last.
  ///
  /// [ledgerRows] must be the full, unfiltered result of
  /// [SqliteHelpers.getLedgerRecords].
  static List<Shrine> _sortShrinesByFrequency(
    List<Shrine> shrines,
    List<Map<String, dynamic>> ledgerRows,
  ) {
    // Find the latest start_timestamp across non-deleted records.
    DateTime? latest;
    for (final row in ledgerRows) {
      if ((row[SqliteConstants.colIsDeleted] as int?) == 1) continue;
      final raw = row[SqliteConstants.colStartTimestamp];
      if (raw == null) continue;
      final ts = DateTime.parse(raw as String);
      if (latest == null || ts.isAfter(latest)) latest = ts;
    }

    // Nothing to sort by — return as-is.
    if (latest == null) return shrines;

    final windowStart = latest.subtract(const Duration(days: 30));

    // Count records per shrine name within the window.
    final counts = <String, int>{};
    for (final row in ledgerRows) {
      if ((row[SqliteConstants.colIsDeleted] as int?) == 1) continue;
      final raw = row[SqliteConstants.colStartTimestamp];
      if (raw == null) continue;
      final ts = DateTime.parse(raw as String);
      if (ts.isBefore(windowStart)) continue;
      final name = row[SqliteConstants.colShrineName] as String?;
      if (name == null) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    // Stable sort: higher count first; 0 for shrines not in the window.
    final sorted = List<Shrine>.from(shrines);
    sorted.sort((a, b) {
      final ca = counts[a.name] ?? 0;
      final cb = counts[b.name] ?? 0;
      return cb.compareTo(ca); // descending
    });
    return sorted;
  }

  /// Preloads the list of [Shrine]s to be displayed in the TrackerView.
  ///
  /// Orchestrates local/remote database initialisation and synchronisation
  /// according to the following logic:
  ///
  /// **1a – Local DB does not exist:**
  ///  1. Initialise the local DB and seed default shrines.
  ///  2. Try to read the remote user collection:
  ///     - *Error* → call [onError], return default shrines.
  ///     - *Not found* → initialise remote, stamp `last_sync`, return defaults.
  ///     - *Found* → remote→local sync, stamp `last_sync`, return remote shrines.
  ///
  /// **1b – Local DB exists:**
  ///  1. Read `last_sync` from `technical_records`.
  ///  2. Try to read the remote user collection:
  ///     - *Error* → call [onError], return local shrines.
  ///     - *Not found* → initialise remote, local→remote sync, stamp
  ///       `last_sync`, return local shrines.
  ///     - *Found* → compare `last_sync` with remote `last_update`:
  ///       - `last_sync >= last_update` → return local shrines.
  ///       - Otherwise → remote→local sync, stamp `last_sync`, return updated
  ///         shrines.
  ///
  /// The returned list is sorted by the frequency of tracking records in the
  /// one-month window ending at the latest record timestamp (descending).
  static Future<List<Shrine>> trackerViewPreload({
    void Function(String message)? onError,
  }) async {
    final userId = requireUserId();

    final dbPath = join(await getDatabasesPath(), SqliteConstants.dbName);
    final dbExists = await databaseExists(dbPath);

    if (!dbExists) {
      // -----------------------------------------------------------------
      // 1a – Local database does NOT exist
      // -----------------------------------------------------------------

      // Initialise local DB and seed default shrines.
      await SqliteHelpers.localDbInit();
      for (final shrine in defaultShrinesList) {
        await SqliteHelpers.addShrine(
          shrineName: shrine.name,
          shrineColor: shrine.color,
        );
      }

      // 1a.1 – Try to read the remote user collection.
      Map<String, dynamic>? remoteUser;
      try {
        remoteUser = await FirestoreHelpers.getUser(userId: userId);
      } catch (e) {
        // 1a.1a – Error accessing remote DB.
        onError?.call(e.toString());
        return List<Shrine>.from(defaultShrinesList);
      }

      if (remoteUser == null) {
        // 1a.1b – No remote collection for this user.
        await FirestoreHelpers.init(); // creates user doc + seeds + is_initialized = true
        await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());
        return List<Shrine>.from(defaultShrinesList);
      }

      // 1a.1c – Remote user collection found.
      await SyncHelpers.remoteToLocal();
      await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());

      // Restore remote tracking state if a session was in progress.
      await _restoreTrackingState(remoteUser);

      final remoteShrines = await FirestoreHelpers.getUserShrines(
        userId: userId,
      );
      final shrines = _firestoreDocsToShrines(remoteShrines);
      final ledgerRows = await SqliteHelpers.getLedgerRecords();
      return _sortShrinesByFrequency(shrines, ledgerRows);
    }

    // -------------------------------------------------------------------
    // 1b – Local database EXISTS
    // -------------------------------------------------------------------

    // Make sure the cached DB handle is open.
    await SqliteHelpers.localDbInit();

    // Read last_sync from technical_records.
    final techRecord = await SqliteHelpers.getTechnicalRecord();
    final lastSyncStr = techRecord?[SqliteConstants.colLastSync] as String?;
    final lastSync = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

    // Read local shrines (for potential early return).
    final localShrineRows = await SqliteHelpers.getUserShrines();
    final localShrines = _sqliteRowsToShrines(localShrineRows);

    // 1b.1 – Try to read the remote user collection.
    Map<String, dynamic>? remoteUser;
    try {
      remoteUser = await FirestoreHelpers.getUser(userId: userId);
    } catch (e) {
      // 1b.1a – Error accessing remote DB.
      onError?.call(e.toString());
      final ledgerRows = await SqliteHelpers.getLedgerRecords();
      return _sortShrinesByFrequency(localShrines, ledgerRows);
    }

    if (remoteUser == null) {
      // 1b.1b – No remote collection for this user.
      await FirestoreHelpers.init(); // creates user doc + seeds + is_initialized = true
      await SyncHelpers.localToRemote();
      await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());
      final ledgerRows = await SqliteHelpers.getLedgerRecords();
      return _sortShrinesByFrequency(localShrines, ledgerRows);
    }

    // 1b.1c – Remote user collection found.
    final remoteLastUpdate =
        remoteUser[FirestoreConstants.fieldLastUpdate];

    // Convert Firestore Timestamp to DateTime for comparison.
    DateTime? remoteUpdateTime;
    if (remoteLastUpdate is Timestamp) {
      remoteUpdateTime = remoteLastUpdate.toDate();
    }

    // If local last_sync >= remote last_update → local is up-to-date.
    if (lastSync != null &&
        remoteUpdateTime != null &&
        (lastSync.isAfter(remoteUpdateTime) ||
            lastSync.isAtSameMomentAs(remoteUpdateTime))) {
      // Restore remote tracking state even when shrine data is up-to-date.
      await _restoreTrackingState(remoteUser);
      final ledgerRows = await SqliteHelpers.getLedgerRecords();
      return _sortShrinesByFrequency(localShrines, ledgerRows);
    }

    // Remote has newer data — pull it down.
    await SyncHelpers.remoteToLocal();
    await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());

    // Restore remote tracking state if a session was in progress.
    await _restoreTrackingState(remoteUser);

    // Re-read shrines from local DB after sync.
    final updatedRows = await SqliteHelpers.getUserShrines();
    final ledgerRows = await SqliteHelpers.getLedgerRecords();
    return _sortShrinesByFrequency(_sqliteRowsToShrines(updatedRows), ledgerRows);
  }

  // ---------------------------------------------------------------------------
  // _restoreTrackingState
  // ---------------------------------------------------------------------------

  /// Reads the remote tracking fields from [userData] and restores the local
  /// timer state if the user was mid-session.
  ///
  /// If elapsed time ≥ 8 h, the session is capped and auto-stopped:
  ///   - A ledger record is saved locally and synced to remote.
  ///   - The remote `is_tracking` flag is set to `false`.
  ///
  /// Otherwise, populates [StateNotifiers] so that [TrackerToggleWidget] can
  /// resume the periodic timer via [StateNotifiers.isTrackingRestored].
  static Future<void> _restoreTrackingState(
    Map<String, dynamic>? userData,
  ) async {
    if (userData == null) return;

    final isTracking =
        userData[FirestoreConstants.fieldIsTracking] as bool? ?? false;
    if (!isTracking) return;

    final rawTimestamp =
        userData[FirestoreConstants.fieldTrackingStartTimestamp];
    if (rawTimestamp == null) return;

    final remoteStart = (rawTimestamp as Timestamp).toDate();
    final shrineName =
        userData[FirestoreConstants.fieldTrackingShrineName] as String?;

    var elapsed = DateTime.now().difference(remoteStart).inSeconds;
    if (elapsed < 0) elapsed = 0; // guard against clock skew

    if (elapsed >= 3600 * 8) {
      // Cap at 8 hours, save the record, and clear remote tracking flag.
      elapsed = 3600 * 8;
      StateNotifiers.secondsCounted.value = elapsed;
      StateNotifiers.startTimestamp.value = remoteStart;

      // Persist the capped session locally.
      final effectiveShrineName =
          shrineName ?? StateNotifiers.currentShrine.value.name;
      await SqliteHelpers.addLedgerRecord(
        shrineName: effectiveShrineName,
        secondsTracked: elapsed,
        startTimestamp: remoteStart,
      );
      await SyncHelpers.localToRemote();

      // Clear remote tracking flag (fire-and-forget).
      final userId = requireUserId();
      FirestoreHelpers.updateUser(
        userId: userId,
        data: {FirestoreConstants.fieldIsTracking: false},
      );
    } else {
      // Session is still active — restore state for TrackerToggleWidget.
      StateNotifiers.secondsCounted.value = elapsed;
      StateNotifiers.startTimestamp.value = remoteStart;

      // Update currentShrine to match the remotely tracked shrine.
      if (shrineName != null) {
        final localShrineRows = await SqliteHelpers.getUserShrines();
        final shrines = _sqliteRowsToShrines(localShrineRows);
        final match = shrines.where((s) => s.name == shrineName);
        if (match.isNotEmpty) {
          StateNotifiers.currentShrine.value = match.first;
        }
      }

      // Signal to TrackerToggleWidget that it should start its Timer.
      StateNotifiers.isTrackingRestored.value = true;
    }
  }

  // ---------------------------------------------------------------------------
  // historyViewPreload
  // ---------------------------------------------------------------------------

  /// Reads all `time_ledger` records and all shrines from the local SQLite
  /// database. Returns a record containing:
  /// - a list of [TimeLedger] objects sorted by [TimeLedger.startTimestamp]
  ///   in descending order (newest first);
  /// - a [Map] keyed by shrine name with the corresponding shrine color value.
  ///
  /// No remote synchronisation is performed — all data comes from the local DB.
  /// Rows where `is_deleted == 1` are excluded from both collections.
  static Future<(List<TimeLedger> records, Map<String, String> shrineColors)>
  historyViewPreload() async {
    final ledgerRows = await SqliteHelpers.getLedgerRecords();
    final shrineRows = await SqliteHelpers.getUserShrines();

    final records = ledgerRows
        .where((r) => (r[SqliteConstants.colIsDeleted] as int?) != 1)
        .map((r) => TimeLedger.fromSqliteRow(r))
        .toList();

    records.sort((a, b) => b.startTimestamp.compareTo(a.startTimestamp));

    final shrineColors = <String, String>{};
    for (final row in shrineRows) {
      if ((row[SqliteConstants.colIsDeleted] as int?) != 1) {
        final name = row[SqliteConstants.colShrineName] as String;
        final color = row[SqliteConstants.colShrineColor] as String;
        shrineColors[name] = color;
      }
    }

    return (records, shrineColors);
  }
}
