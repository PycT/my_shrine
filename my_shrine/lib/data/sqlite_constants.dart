/// Constants for local SQLite database table and column names.
class SqliteConstants {
  // Database
  static const String dbName = 'my_shrine.db';

  // Tables
  static const String shrinesTable = 'shrines';
  static const String ledgerTable = 'time_ledger';

  // Columns – shrines
  static const String colShrineName = 'shrine_name';
  static const String colShrineColor = 'shrine_color';

  // Columns – time_ledger
  static const String colId = 'id';
  static const String colSecondsTracked = 'seconds_tracked';
  static const String colStartTimestamp = 'start_timestamp';
}
