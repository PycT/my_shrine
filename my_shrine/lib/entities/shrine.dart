import 'package:my_shrine/data/sqlite_constants.dart';

/// Represents a category or topic for tracking time.
class Shrine {
  final String name;
  final String color;

  const Shrine({required this.name, required this.color});

  Shrine copyWith({String? name, String? color}) =>
      Shrine(name: name ?? this.name, color: color ?? this.color);

  /// Creates a [Shrine] from a SQLite row map.
  factory Shrine.fromSqliteRow(Map<String, dynamic> row) => Shrine(
        name: row[SqliteConstants.colShrineName] as String,
        color: row[SqliteConstants.colShrineColor] as String,
      );

  /// Creates a [Shrine] from a Firestore document map.
  factory Shrine.fromFirestoreDoc(Map<String, dynamic> doc) => Shrine(
        name: doc['name'] as String,
        color: doc['shrine_color'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shrine && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'Shrine(name: $name, color: $color)';
}
