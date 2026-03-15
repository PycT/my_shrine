import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_shrine/data/firestore_constants.dart';

/// A utility class providing static methods to read from and write to Firestore.
///
/// **Firestore structure assumed:**
/// ```
/// time_ledger/                          <-- rootCollection
///   └── {userId}/                       <-- document ID = user_id string
///         ├── is_initialized            <-- false by default
///         ├── user_shrines/             <-- userShrinesCollection
///         │     └── {shrineName}/       <-- document ID = shrine name
///         │           └── shrine_color
///         └── user_time_ledger/         <-- userLedgerCollection
///               └── {docId}/
///                     ├── seconds_tracked
///                     ├── shrine_name
///                     └── start_timestamp
/// ```
/// Granularity for date-based aggregation in [FirestoreUtils.getLedgerSummary].
enum DateGranularity { day, month, year }

class FirestoreUtils {
  // Private constructor — this class should not be instantiated.
  FirestoreUtils._();

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

  // ---------------------------------------------------------------------------
  // 0. Create / read user document
  // ---------------------------------------------------------------------------

  /// Creates the user document under `time_ledger/` with [userId] as the
  /// document ID. Sets `user_id` to the given value and `is_initialized` to
  /// `false`.
  ///
  /// Uses `merge: true` so existing sub-collections are not affected.
  static Future<void> createUser({required String userId}) async {
    await userDocRef(
      userId,
    ).set({'is_initialized': false}, SetOptions(merge: true));
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
  /// `{'is_initialized': true}`).
  ///
  /// Throws a [StateError] if the document does not exist.
  static Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final docRef = userDocRef(userId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('No user document found for "$userId"');
    }
    await docRef.update(data);
  }

  // ---------------------------------------------------------------------------
  // 1. Read all shrines of a user
  // ---------------------------------------------------------------------------

  /// Reads every document from [user_shrines] for the given [userId].
  ///
  /// Returns a list of maps, each containing `shrine_name` (the document ID)
  /// and `shrine_color`.
  static Future<List<Map<String, dynamic>>> getUserShrines({
    required String userId,
  }) async {
    final snapshot = await shrinesRef(userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'shrine_name': doc.id, ...data};
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 2. Add a shrine to user_shrines
  // ---------------------------------------------------------------------------

  /// Adds a new shrine document to [user_shrines] using [shrineName] as the
  /// document ID.
  ///
  /// Returns the shrine name used as the document key.
  static Future<String> addShrine({
    required String userId,
    required String shrineName,
    required String shrineColor,
  }) async {
    await shrinesRef(userId).doc(shrineName).set({'shrine_color': shrineColor});
    return shrineName;
  }

  // ---------------------------------------------------------------------------
  // 3. Modify shrine name and/or color (identified by shrine name doc ID)
  // ---------------------------------------------------------------------------

  /// Updates the shrine document whose ID is [currentName].
  ///
  /// If [newName] is provided the document is re-created under the new name
  /// (Firestore does not support renaming document IDs).
  /// If [newColor] is provided the `shrine_color` field is updated.
  ///
  /// Throws a [StateError] if no shrine with [currentName] exists.
  static Future<void> modifyShrine({
    required String userId,
    required String currentName,
    String? newName,
    String? newColor,
  }) async {
    final docRef = shrinesRef(userId).doc(currentName);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw StateError('No shrine found with name "$currentName"');
    }

    if (newName != null && newName != currentName) {
      // Firestore doc IDs are immutable — copy to new doc, delete old one.
      final oldData = docSnapshot.data() as Map<String, dynamic>;
      final mergedData = <String, dynamic>{
        ...oldData,
        if (newColor != null) 'shrine_color': newColor,
      };
      await shrinesRef(userId).doc(newName).set(mergedData);
      await docRef.delete();
    } else if (newColor != null) {
      await docRef.update({'shrine_color': newColor});
    }
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
        DateGranularity.year =>
          '${date.year}',
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
    });
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
  }
}
