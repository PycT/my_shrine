/// Constants for Firestore collection and field names.
class FirestoreConstants {
  // Collections
  static const String rootCollection = "time_ledger";
  static const String userShrinesCollection = "user_shrines";
  static const String userLedgerCollection = "user_time_ledger";

  // User document fields
  static const String fieldIsInitialized = 'is_initialized';
  static const String fieldLastUpdate = 'last_update';
  static const String fieldLastDeviceId = 'last_device_id';

  // Shrine document fields
  static const String fieldShrineName = 'name';
  static const String fieldShrineColor = 'shrine_color';

  // Ledger document fields
  static const String fieldLedgerShrineName = 'shrine_name';
  static const String fieldSecondsTracked = 'seconds_tracked';
  static const String fieldStartTimestamp = 'start_timestamp';

  // Tracking state fields (on the user document)
  static const String fieldIsTracking = 'is_tracking';
  static const String fieldTrackingStartTimestamp = 'tracking_start_timestamp';
  static const String fieldTrackingShrineName = 'tracking_shrine_name';

  // Shared fields
  static const String fieldIsDeleted = 'is_deleted';
}
