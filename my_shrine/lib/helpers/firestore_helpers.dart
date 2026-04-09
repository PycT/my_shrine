import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:my_shrine/data/firestore_constants.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/data/default_shrines.dart';

/// A utility class providing static methods to read from and write to Firestore.
///
/// **Firestore structure assumed:**
/// ```
/// time_ledger/                          <-- rootCollection
///   └── {userId}/                       <-- document ID = user_id string
///         ├── is_initialized            <-- false by default
///         ├── last_update               <-- server timestamp, set on every write
///         ├── last_device_id            <-- last device that wrote to this doc
///         ├── user_shrines/             <-- userShrinesCollection
///         │     └── {autoId}/           <-- auto-generated document ID
///         │           ├── name          <-- unique across collection
///         │           ├── shrine_color
///         │           └── is_deleted    <-- false by default
///         └── user_time_ledger/         <-- userLedgerCollection
///               └── {docId}/
///                     ├── seconds_tracked
///                     ├── shrine_name
///                     ├── start_timestamp
///                     └── is_deleted    <-- false by default
/// ```
///
/// **Methods:**
///
/// *Initialisation:*
/// - [init]                — bootstraps the full Firestore structure for the
///                           current user (user doc + default shrines).
///
/// *Technical data:*
/// - [technicalDataWrite]  — writes `last_update` and `last_device_id` to the
///                           user doc. Called automatically by every write method.
///
/// *User document:*
/// - [createUser]          — creates the user doc with `is_initialized` = false.
/// - [getUser]             — reads the user doc; returns `null` if missing.
/// - [updateUser]          — updates specified fields on the user doc.
/// - [updateLastDeviceId]  — sets `last_device_id` on the user doc.
/// - [getLastUpdateInfo]   — reads `last_update` and `last_device_id`.
///
/// *Shrines (user_shrines):*
/// - [getUserShrines]      — reads all shrine docs for a user.
/// - [addShrine]           — adds a shrine (auto-ID); enforces name uniqueness.
/// - [modifyShrine]        — updates name and/or color by current shrine name.
///
/// *Time ledger (user_time_ledger):*
/// - [getLedgerSummary]    — aggregates seconds by shrine + date granularity.
/// - [addLedgerRecord]     — adds a new time-tracking entry (auto-ID).
/// - [hasLedgerRecord]     — checks if a record exists for shrine + timestamp.
/// - [updateLedgerSeconds] — updates seconds on a matching ledger record.
/// Granularity for date-based aggregation in [FirestoreHelpers.getLedgerSummary].
enum DateGranularity { day, month, year }

class FirestoreHelpers {
  // Private constructor — this class should not be instantiated.
  FirestoreHelpers._();

  /// Reference to the Firestore instance.
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Helper: collection references
  // ---------------------------------------------------------------------------

  /// Returns a reference to the `user_shrines` sub-collection for [userId].
  static CollectionReference shrinesRef(String userId) => _db
      .collection(FirestoreConstants.rootCollection)
      .doc(userId)
      .collection(FirestoreConstants.userShrinesCollection);

  /// Returns a reference to the `user_time_ledger` sub-collection for [userId].
  static CollectionReference ledgerRef(String userId) => _db
      .collection(FirestoreConstants.rootCollection)
      .doc(userId)
      .collection(FirestoreConstants.userLedgerCollection);

  /// Returns a reference to the user document under `time_ledger/` for [userId].
  static DocumentReference userDocRef(String userId) =>
      _db.collection(FirestoreConstants.rootCollection).doc(userId);

  /// Stamps the user document with `last_update` and `last_device_id`.
  ///
  /// Called internally by every writing method so the user document always
  /// reflects the most recent write. The device name is read from the
  /// Android system via `device_info_plus`.
  static Future<void> _stampUserDoc(String userId) async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final deviceName = androidInfo.model;
    await userDocRef(userId).set({
      'last_update': FieldValue.serverTimestamp(),
      'last_device_id': deviceName,
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // 0. Initialise the Firestore structure for the current user
  // ---------------------------------------------------------------------------

  /// Bootstraps the full Firestore structure for the currently signed-in user.
  ///
  /// Uses the email from [StateNotifiers.user] as the document ID under
  /// `time_ledger/`. If the user is already initialised (`is_initialized` is
  /// `true`) the method returns immediately.
  ///
  /// Steps performed:
  /// 1. Reads (or creates) the user document.
  /// 2. Seeds every entry from [defaultShrinesList] into `user_shrines`.
  /// 3. Sets `is_initialized` to `true`.
  ///
  /// Throws a [StateError] if no user is currently signed in or the user has
  /// no email.
  static Future<void> init() async {
    final user = StateNotifiers.user.value;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user or user has no email');
    }
    final userId = user.email!;

    // Check if the user document already exists and is initialised.
    final existing = await getUser(userId: userId);
    if (existing != null && existing['is_initialized'] == true) return;

    // Create the user document (merge-safe).
    await createUser(userId: userId);

    // Seed default shrines.
    for (final shrine in defaultShrinesList) {
      await addShrine(
        userId: userId,
        shrineName: shrine.name,
        shrineColor: shrine.color,
      );
    }

    // Mark the user as initialised.
    await updateUser(
      userId: userId,
      data: {'is_initialized': true},
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Create / read user document
  // ---------------------------------------------------------------------------

  /// Creates the user document under `time_ledger/` with [userId] as the
  /// document ID. Sets `is_initialized` to `false` and stamps the document
  /// with `last_update` and `last_device_id`.
  ///
  /// Uses `merge: true` so existing sub-collections are not affected.
  static Future<void> createUser({required String userId}) async {
    await userDocRef(userId).set({
      'is_initialized': false,
    }, SetOptions(merge: true));
    await _stampUserDoc(userId);
  }

  /// Reads the user document for [userId].
  ///
  /// Returns a map with `user_id` and `is_initialized`, or `null` if the
  /// document does not exist.
  static Future<Map<String, dynamic>?> getUser({required String userId}) async {
    final snapshot = await userDocRef(userId).get();
    if (!snapshot.exists) return null;
    return snapshot.data() as Map<String, dynamic>?;
  }

  /// Updates fields on the user document for [userId].
  ///
  /// [data] is a map of field names to new values (e.g.
  /// `{'is_initialized': true}`). `last_update` and `last_device_id` are
  /// always stamped automatically via [_stampUserDoc].
  ///
  /// Throws a [StateError] if the document does not exist.
  static Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    if (data.isEmpty) return;

    final docRef = userDocRef(userId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('No user document found for "$userId"');
    }
    await docRef.update(data);
    await _stampUserDoc(userId);
  }

  /// Updates `last_device_id` and `last_update` on the user document for
  /// [userId].
  ///
  /// Delegates to [_stampUserDoc] which reads the device name from the
  /// Android system.
  ///
  /// Throws a [StateError] if the document does not exist.
  static Future<void> updateLastDeviceId({
    required String userId,
  }) async {
    final docRef = userDocRef(userId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('No user document found for "$userId"');
    }
    await _stampUserDoc(userId);
  }

  /// Returns the `last_update` and `last_device_id` fields from the user
  /// document for [userId].
  ///
  /// Returns a map with keys `last_update` ([Timestamp] or `null`) and
  /// `last_device_id` ([String] or `null`), or `null` if the document does
  /// not exist.
  static Future<Map<String, dynamic>?> getLastUpdateInfo({
    required String userId,
  }) async {
    final snapshot = await userDocRef(userId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return null;
    return {
      'last_update': data['last_update'],
      'last_device_id': data['last_device_id'],
    };
  }

  // ---------------------------------------------------------------------------
  // 1. Read all shrines of a user
  // ---------------------------------------------------------------------------

  /// Reads every document from [user_shrines] for the given [userId].
  ///
  /// Returns a list of maps, each containing `name` and `shrine_color`.
  static Future<List<Map<String, dynamic>>> getUserShrines({
    required String userId,
  }) async {
    final snapshot = await shrinesRef(userId).get();
    return snapshot.docs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Add a shrine to user_shrines
  // ---------------------------------------------------------------------------

  /// Adds a new shrine document to [user_shrines] with an auto-generated ID.
  ///
  /// Throws a [StateError] if a shrine with the same [shrineName] already
  /// exists in the collection (names must be unique).
  ///
  /// Returns the auto-generated document ID.
  static Future<String> addShrine({
    required String userId,
    required String shrineName,
    required String shrineColor,
  }) async {
    // Enforce uniqueness on the `name` field.
    final existing = await shrinesRef(
      userId,
    ).where('name', isEqualTo: shrineName).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw StateError('A shrine named "$shrineName" already exists');
    }

    final docRef = await shrinesRef(userId).add({
      'name': shrineName,
      'shrine_color': shrineColor,
      'is_deleted': false,
    });
    await _stampUserDoc(userId);
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // 3. Modify shrine name and/or color (looked up by current name)
  // ---------------------------------------------------------------------------

  /// Updates fields on the shrine document whose `name` equals [currentName].
  ///
  /// Only the provided parameters are written. If neither [newName] nor
  /// [newColor] is specified, the method returns without touching Firestore.
  ///
  /// If [newName] is provided, uniqueness is enforced — a [StateError] is
  /// thrown if another shrine already has that name.
  ///
  /// Throws a [StateError] if no shrine with [currentName] exists.
  static Future<void> modifyShrine({
    required String userId,
    required String currentName,
    String? newName,
    String? newColor,
  }) async {
    final updates = <String, dynamic>{
      if (newName != null) 'name': newName,
      if (newColor != null) 'shrine_color': newColor,
    };
    if (updates.isEmpty) return;

    // Find the document by its `name` field.
    final snapshot = await shrinesRef(
      userId,
    ).where('name', isEqualTo: currentName).limit(1).get();

    if (snapshot.docs.isEmpty) {
      throw StateError('No shrine found with name "$currentName"');
    }

    // If renaming, check that the new name is not already taken.
    if (newName != null && newName != currentName) {
      final conflict = await shrinesRef(
        userId,
      ).where('name', isEqualTo: newName).limit(1).get();
      if (conflict.docs.isNotEmpty) {
        throw StateError('A shrine named "$newName" already exists');
      }
    }

    await snapshot.docs.first.reference.update(updates);
    await _stampUserDoc(userId);
  }

  // ---------------------------------------------------------------------------
  // 4. Read all ledger records and sum seconds_tracked grouped by
  //    shrine_name + date(start_timestamp)
  // ---------------------------------------------------------------------------

  /// Reads every document from [user_time_ledger] and returns cumulative
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
    required String userId,
    DateGranularity granularity = DateGranularity.day,
  }) async {
    final snapshot = await ledgerRef(userId).get();

    final result = <String, Map<String, int>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      final shrineName = data['shrine_name'] as String;
      final seconds = (data['seconds_tracked'] as num).toInt();
      final timestamp = data['start_timestamp'] as Timestamp;
      final date = timestamp.toDate();

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
  // 5. Add a record to user_time_ledger
  // ---------------------------------------------------------------------------

  /// Adds a new ledger entry to [user_time_ledger].
  ///
  /// Returns the auto-generated document ID.
  static Future<String> addLedgerRecord({
    required String userId,
    required int secondsTracked,
    required String shrineName,
    required Timestamp startTimestamp,
  }) async {
    final docRef = await ledgerRef(userId).add({
      'seconds_tracked': secondsTracked,
      'shrine_name': shrineName,
      'start_timestamp': startTimestamp,
      'is_deleted': false,
    });
    await _stampUserDoc(userId);
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // 6. Check if a ledger record exists for a given shrine_name + start_timestamp
  // ---------------------------------------------------------------------------

  /// Returns `true` if [user_time_ledger] contains at least one document with
  /// the given [shrineName] **and** [startTimestamp].
  static Future<bool> hasLedgerRecord({
    required String userId,
    required String shrineName,
    required Timestamp startTimestamp,
  }) async {
    final snapshot = await ledgerRef(userId)
        .where('shrine_name', isEqualTo: shrineName)
        .where('start_timestamp', isEqualTo: startTimestamp)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // 7. Modify seconds_tracked for a record matching shrine_name + start_timestamp
  // ---------------------------------------------------------------------------

  /// Updates `seconds_tracked` on the first ledger document whose `shrine_name`
  /// equals [shrineName] and `start_timestamp` equals [startTimestamp].
  ///
  /// Throws a [StateError] if no matching document is found.
  static Future<void> updateLedgerSeconds({
    required String userId,
    required String shrineName,
    required Timestamp startTimestamp,
    required int secondsTracked,
  }) async {
    final snapshot = await ledgerRef(userId)
        .where('shrine_name', isEqualTo: shrineName)
        .where('start_timestamp', isEqualTo: startTimestamp)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError(
        'No ledger record found for shrine "$shrineName" at $startTimestamp',
      );
    }

    await snapshot.docs.first.reference.update({
      'seconds_tracked': secondsTracked,
    });
    await _stampUserDoc(userId);
  }

  // ---------------------------------------------------------------------------
  // 8. Read all raw ledger records (for sync)
  // ---------------------------------------------------------------------------

  /// Reads every document from [user_time_ledger] for the given [userId]
  /// without aggregation.
  ///
  /// Returns a list of maps, each containing `shrine_name`, `seconds_tracked`,
  /// `start_timestamp`, and `is_deleted`.
  static Future<List<Map<String, dynamic>>> getLedgerRecords({
    required String userId,
  }) async {
    final snapshot = await ledgerRef(userId).get();
    return snapshot.docs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();
  }
}
