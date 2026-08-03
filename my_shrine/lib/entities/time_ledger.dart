import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_shrine/data/sqlite_constants.dart';

/// Represents a single time-tracking record.
class TimeLedger {
  final int id;
  final String shrineName;
  final int secondsTracked;
  final DateTime startTimestamp;

  const TimeLedger({
    required this.id,
    required this.shrineName,
    required this.secondsTracked,
    required this.startTimestamp,
  });

  /// Creates a [TimeLedger] from a SQLite row map.
  factory TimeLedger.fromSqliteRow(Map<String, dynamic> row) => TimeLedger(
        id: row[SqliteConstants.colId] as int,
        shrineName: row[SqliteConstants.colShrineName] as String,
        secondsTracked: row[SqliteConstants.colSecondsTracked] as int,
        startTimestamp: DateTime.parse(
          row[SqliteConstants.colStartTimestamp] as String,
        ),
      );

  /// Creates a [TimeLedger] from a Firestore document map.
  /// Firestore records don't have a local integer ID, so [id] defaults to -1.
  factory TimeLedger.fromFirestoreDoc(Map<String, dynamic> doc) => TimeLedger(
        id: -1,
        shrineName: doc['shrine_name'] as String,
        secondsTracked: (doc['seconds_tracked'] as num).toInt(),
        startTimestamp: (doc['start_timestamp'] as Timestamp).toDate(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeLedger &&
          other.id == id &&
          other.shrineName == shrineName &&
          other.secondsTracked == secondsTracked &&
          other.startTimestamp == startTimestamp;

  @override
  int get hashCode =>
      Object.hash(id, shrineName, secondsTracked, startTimestamp);

  @override
  String toString() =>
      'TimeLedger(id: $id, shrineName: $shrineName, '
      'secondsTracked: $secondsTracked, startTimestamp: $startTimestamp)';
}
