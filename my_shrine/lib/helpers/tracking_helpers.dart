import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_shrine/data/firestore_constants.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';
import 'package:my_shrine/utils/user_helpers.dart';

/// Shared start/stop tracking logic consumed by both [TrackerToggleWidget]
/// and [ShrineSwitchWidget].
class TrackingHelpers {
  TrackingHelpers._();

  /// Starts a tracking session for the shrine currently set in
  /// [StateNotifiers.currentShrine], using [selectedTimestamp] as the
  /// logical start time.
  ///
  /// [onTimerCreated] receives the new periodic [Timer]; the caller is
  /// responsible for holding a reference and cancelling it when needed.
  static void startTracking({
    required DateTime selectedTimestamp,
    required void Function(Timer) onTimerCreated,
  }) {
    StateNotifiers.secondsCounted.value = 0;
    StateNotifiers.startTimestamp.value = selectedTimestamp;
    StateNotifiers.isTracking.value = true;

    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now()
          .difference(StateNotifiers.startTimestamp.value)
          .inSeconds;
      if (elapsed < 0) {
        StateNotifiers.secondsCounted.value = 0;
        return;
      }
      if (elapsed >= 3600 * 8) {
        StateNotifiers.secondsCounted.value = 3600 * 8;
        return;
      }
      StateNotifiers.secondsCounted.value = elapsed;
    });

    onTimerCreated(timer);

    // Write remote tracking state (fire-and-forget).
    final userId = requireUserId();
    FirestoreHelpers.updateUser(
      userId: userId,
      data: {
        FirestoreConstants.fieldIsTracking: true,
        FirestoreConstants.fieldTrackingStartTimestamp:
            Timestamp.fromDate(selectedTimestamp),
        FirestoreConstants.fieldTrackingShrineName:
            StateNotifiers.currentShrine.value.name,
      },
    );
  }

  /// Stops the currently running tracking session, persisting the record.
  ///
  /// [cancelTimer] should cancel and null out the caller's local [Timer]
  /// reference. [stopTimestamp] defaults to [DateTime.now()].
  static void stopTracking({
    required void Function() cancelTimer,
    DateTime? stopTimestamp,
  }) {
    cancelTimer();

    final effectiveStop = stopTimestamp ?? DateTime.now();
    var secondsTracked = effectiveStop
        .difference(StateNotifiers.startTimestamp.value)
        .inSeconds;
    if (secondsTracked < 0) secondsTracked = 0;
    if (secondsTracked > 3600 * 8) secondsTracked = 3600 * 8;

    StateNotifiers.secondsCounted.value = secondsTracked;
    StateNotifiers.isTracking.value = false;

    SqliteHelpers.addLedgerRecord(
      shrineName: StateNotifiers.currentShrine.value.name,
      secondsTracked: secondsTracked,
      startTimestamp: StateNotifiers.startTimestamp.value,
    ).then((_) => SyncHelpers.localToRemote());

    final userId = requireUserId();
    FirestoreHelpers.updateUser(
      userId: userId,
      data: {FirestoreConstants.fieldIsTracking: false},
    );
  }
}
