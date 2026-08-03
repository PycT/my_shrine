import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_shrine/data/firestore_constants.dart';
import 'package:my_shrine/data/sqlite_constants.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/utils/user_helpers.dart';

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

  /// Deletes every document in a Firestore collection using batched writes.
  static Future<void> _clearCollection(CollectionReference ref) async {
    final snapshot = await ref.get();
    if (snapshot.docs.isEmpty) return;

    // Firestore supports up to 500 operations per batch.
    const batchLimit = 500;
    var batch = FirebaseFirestore.instance.batch();
    var count = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= batchLimit) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
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
    final userId = requireUserId();

    // 1. Clear remote sub-collections.
    await _clearCollection(FirestoreHelpers.shrinesRef(userId));
    await _clearCollection(FirestoreHelpers.ledgerRef(userId));

    // 2. Push local shrines → remote (batched).
    final localShrines = await SqliteHelpers.getUserShrines();
    var batch = FirebaseFirestore.instance.batch();
    var count = 0;
    const batchLimit = 500;

    for (final row in localShrines) {
      batch.set(FirestoreHelpers.shrinesRef(userId).doc(), {
        FirestoreConstants.fieldShrineName: row[SqliteConstants.colShrineName],
        FirestoreConstants.fieldShrineColor: row[SqliteConstants.colShrineColor],
        FirestoreConstants.fieldIsDeleted:
            (row[SqliteConstants.colIsDeleted] as int) == 1,
      });
      count++;
      if (count >= batchLimit) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      count = 0;
    }

    // 3. Push local ledger → remote (batched).
    final localLedger = await SqliteHelpers.getLedgerRecords();
    for (final row in localLedger) {
      final isoString = row[SqliteConstants.colStartTimestamp] as String;
      batch.set(FirestoreHelpers.ledgerRef(userId).doc(), {
        FirestoreConstants.fieldLedgerShrineName: row[SqliteConstants.colShrineName],
        FirestoreConstants.fieldSecondsTracked: row[SqliteConstants.colSecondsTracked],
        FirestoreConstants.fieldStartTimestamp:
            Timestamp.fromDate(DateTime.parse(isoString)),
        FirestoreConstants.fieldIsDeleted:
            (row[SqliteConstants.colIsDeleted] as int) == 1,
      });
      count++;
      if (count >= batchLimit) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
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
    final userId = requireUserId();

    // 1. Clear local tables.
    await SqliteHelpers.clearShrines();
    await SqliteHelpers.clearLedger();

    // 2. Pull remote shrines → local.
    final remoteShrines = await FirestoreHelpers.getUserShrines(userId: userId);
    for (final doc in remoteShrines) {
      await SqliteHelpers.insertShrineRaw(
        shrineName: doc[FirestoreConstants.fieldShrineName] as String,
        shrineColor: doc[FirestoreConstants.fieldShrineColor] as String,
        isDeleted:
            (doc[FirestoreConstants.fieldIsDeleted] as bool? ?? false) ? 1 : 0,
      );
    }

    // 3. Pull remote ledger → local.
    final remoteLedger =
        await FirestoreHelpers.getLedgerRecords(userId: userId);
    for (final doc in remoteLedger) {
      final timestamp =
          doc[FirestoreConstants.fieldStartTimestamp] as Timestamp;
      await SqliteHelpers.insertLedgerRaw(
        shrineName: doc[FirestoreConstants.fieldLedgerShrineName] as String,
        secondsTracked:
            (doc[FirestoreConstants.fieldSecondsTracked] as num).toInt(),
        startTimestamp: timestamp.toDate(),
        isDeleted:
            (doc[FirestoreConstants.fieldIsDeleted] as bool? ?? false) ? 1 : 0,
      );
    }
  }
}
