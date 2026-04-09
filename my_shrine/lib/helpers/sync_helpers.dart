import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_shrine/data/sqlite_constants.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';

/// Provides full-refresh synchronisation between the local SQLite database and
/// the remote Firestore database.
///
/// **Important:** technical / meta records are never copied in either direction.
/// - SQLite `technical_records` (last_update, last_sync) stays local.
/// - Firestore user-document fields (is_initialized, last_update, last_device_id)
///   stay remote.
///
/// Only the *data* sub-collections are synchronised:
/// - `shrines` ↔ `user_shrines`
/// - `time_ledger` ↔ `user_time_ledger`
///
/// **Methods:**
/// - [localToRemote] — full refresh: local → remote.
/// - [remoteToLocal] — full refresh: remote → local.
class SyncHelpers {
  SyncHelpers._();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the current user's email, used as the Firestore document ID.
  ///
  /// Throws a [StateError] if no user is signed in or the user has no email.
  static String _requireUserId() {
    final user = StateNotifiers.user.value;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user or user has no email');
    }
    return user.email!;
  }

  /// Deletes every document in a Firestore collection.
  static Future<void> _clearCollection(CollectionReference ref) async {
    final snapshot = await ref.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // Local → Remote  (full refresh)
  // ---------------------------------------------------------------------------

  /// Reads all shrines and ledger records from the local SQLite database and
  /// **replaces** the corresponding Firestore sub-collections for the current
  /// user.
  ///
  /// Steps:
  /// 1. Delete all docs in `user_shrines` and `user_time_ledger`.
  /// 2. Read local `shrines` table and write each row to `user_shrines`.
  /// 3. Read local `time_ledger` table and write each row to `user_time_ledger`.
  ///
  /// Technical records (`technical_records` in SQLite, user-doc fields in
  /// Firestore) are **not** touched.
  static Future<void> localToRemote() async {
    final userId = _requireUserId();

    // 1. Clear remote sub-collections.
    await _clearCollection(FirestoreHelpers.shrinesRef(userId));
    await _clearCollection(FirestoreHelpers.ledgerRef(userId));

    // 2. Push local shrines → remote.
    final localShrines = await SqliteHelpers.getUserShrines();
    for (final row in localShrines) {
      await FirestoreHelpers.shrinesRef(userId).add({
        'name': row[SqliteConstants.colShrineName],
        'shrine_color': row[SqliteConstants.colShrineColor],
        'is_deleted': (row[SqliteConstants.colIsDeleted] as int) == 1,
      });
    }

    // 3. Push local ledger → remote.
    final localLedger = await SqliteHelpers.getLedgerRecords();
    for (final row in localLedger) {
      final isoString = row[SqliteConstants.colStartTimestamp] as String;
      await FirestoreHelpers.ledgerRef(userId).add({
        'shrine_name': row[SqliteConstants.colShrineName],
        'seconds_tracked': row[SqliteConstants.colSecondsTracked],
        'start_timestamp': Timestamp.fromDate(DateTime.parse(isoString)),
        'is_deleted': (row[SqliteConstants.colIsDeleted] as int) == 1,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Remote → Local  (full refresh)
  // ---------------------------------------------------------------------------

  /// Reads all shrines and ledger records from Firestore and **replaces** the
  /// corresponding local SQLite tables for the current user.
  ///
  /// Steps:
  /// 1. Delete all rows in the local `shrines` and `time_ledger` tables.
  /// 2. Read `user_shrines` from Firestore and insert each doc into `shrines`.
  /// 3. Read `user_time_ledger` from Firestore and insert each doc into
  ///    `time_ledger`.
  ///
  /// Technical records are **not** touched.
  static Future<void> remoteToLocal() async {
    final userId = _requireUserId();

    // 1. Clear local tables.
    await SqliteHelpers.clearShrines();
    await SqliteHelpers.clearLedger();

    // 2. Pull remote shrines → local.
    final remoteShrines = await FirestoreHelpers.getUserShrines(userId: userId);
    for (final doc in remoteShrines) {
      await SqliteHelpers.insertShrineRaw(
        shrineName: doc['name'] as String,
        shrineColor: doc['shrine_color'] as String,
        isDeleted: (doc['is_deleted'] as bool? ?? false) ? 1 : 0,
      );
    }

    // 3. Pull remote ledger → local.
    final remoteLedger = await FirestoreHelpers.getLedgerRecords(userId: userId);
    for (final doc in remoteLedger) {
      final timestamp = doc['start_timestamp'] as Timestamp;
      await SqliteHelpers.insertLedgerRaw(
        shrineName: doc['shrine_name'] as String,
        secondsTracked: (doc['seconds_tracked'] as num).toInt(),
        startTimestamp: timestamp.toDate(),
        isDeleted: (doc['is_deleted'] as bool? ?? false) ? 1 : 0,
      );
    }
  }
}
