import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:my_shrine/data/default_shrines.dart';
import 'package:my_shrine/data/sqlite_constants.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';

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

  /// Returns the current user's email (used as the Firestore document ID).
  ///
  /// Throws a [StateError] if no user is signed in or the user has no email.
  static String _requireUserId() {
    final user = StateNotifiers.user.value;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user or user has no email');
    }
    return user.email!;
  }

  /// Shows a floating [SnackBar] with [message] for 3 seconds.
  static void _showAlert(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Converts SQLite shrine rows to [Shrine] objects, filtering out rows
  /// where `is_deleted == 1`.
  static List<Shrine> _sqliteRowsToShrines(List<Map<String, dynamic>> rows) {
    return rows
        .where((r) => (r[SqliteConstants.colIsDeleted] as int?) != 1)
        .map(
          (r) => Shrine(
            name: r[SqliteConstants.colShrineName] as String,
            color: r[SqliteConstants.colShrineColor] as String,
          ),
        )
        .toList();
  }

  /// Converts Firestore shrine docs to [Shrine] objects, filtering out docs
  /// where `is_deleted == true`.
  static List<Shrine> _firestoreDocsToShrines(List<Map<String, dynamic>> docs) {
    return docs
        .where((d) => d['is_deleted'] != true)
        .map(
          (d) => Shrine(
            name: d['name'] as String,
            color: d['shrine_color'] as String,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // trackerViewPreload
  // ---------------------------------------------------------------------------

  /// Preloads the list of [Shrine]s to be displayed in the TrackerView.
  ///
  /// Orchestrates local/remote database initialisation and synchronisation
  /// according to the following logic:
  ///
  /// **1a – Local DB does not exist:**
  ///  1. Initialise the local DB and seed default shrines.
  ///  2. Try to read the remote user collection:
  ///     - *Error* → show alert, return default shrines.
  ///     - *Not found* → initialise remote, stamp `last_sync`, return defaults.
  ///     - *Found* → remote→local sync, stamp `last_sync`, return remote shrines.
  ///
  /// **1b – Local DB exists:**
  ///  1. Read `last_sync` from `technical_records`.
  ///  2. Try to read the remote user collection:
  ///     - *Error* → show alert, return local shrines.
  ///     - *Not found* → initialise remote, local→remote sync, stamp
  ///       `last_sync`, return local shrines.
  ///     - *Found* → compare `last_sync` with remote `last_update`:
  ///       - `last_sync >= last_update` → return local shrines.
  ///       - Otherwise → remote→local sync, stamp `last_sync`, return updated
  ///         shrines.
  static Future<List<Shrine>> trackerViewPreload(BuildContext context) async {
    final userId = _requireUserId();

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
        if (context.mounted) _showAlert(context, e.toString());
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

      final remoteShrines = await FirestoreHelpers.getUserShrines(
        userId: userId,
      );
      return _firestoreDocsToShrines(remoteShrines);
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
      if (context.mounted) _showAlert(context, e.toString());
      return localShrines;
    }

    if (remoteUser == null) {
      // 1b.1b – No remote collection for this user.
      await FirestoreHelpers.init(); // creates user doc + seeds + is_initialized = true
      await SyncHelpers.localToRemote();
      await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());
      return localShrines;
    }

    // 1b.1c – Remote user collection found.
    final remoteLastUpdate = remoteUser['last_update'];

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
      return localShrines;
    }

    // Remote has newer data — pull it down.
    await SyncHelpers.remoteToLocal();
    await SqliteHelpers.updateTechnicalRecord(lastSync: DateTime.now());

    // Re-read shrines from local DB after sync.
    final updatedRows = await SqliteHelpers.getUserShrines();
    return _sqliteRowsToShrines(updatedRows);
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
        .map(
          (r) => TimeLedger(
            id: r[SqliteConstants.colId] as int,
            shrineName: r[SqliteConstants.colShrineName] as String,
            secondsTracked: r[SqliteConstants.colSecondsTracked] as int,
            startTimestamp: DateTime.parse(
              r[SqliteConstants.colStartTimestamp] as String,
            ),
          ),
        )
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
