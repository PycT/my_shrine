/// Represents a single time-tracking record from the `time_ledger` table.
class TimeLedger {
  final int id;
  final String shrineName;
  final int secondsTracked;
  final DateTime startTimestamp;

  TimeLedger({
    required this.id,
    required this.shrineName,
    required this.secondsTracked,
    required this.startTimestamp,
  });
}
