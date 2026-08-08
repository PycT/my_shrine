import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_shrine/data/firestore_constants.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';
import 'package:my_shrine/utils/color_utils.dart';
import 'package:my_shrine/utils/time_format_utils.dart';
import 'package:my_shrine/utils/user_helpers.dart';

class TrackerToggleWidget extends StatefulWidget {
  const TrackerToggleWidget({super.key});

  @override
  State<TrackerToggleWidget> createState() => _TrackerToggleWidgetState();
}

class _TrackerToggleWidgetState extends State<TrackerToggleWidget> {
  bool _running = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // trackerViewPreload runs in a FutureBuilder and may set
    // isTrackingRestored *after* this initState has already executed.
    // Listen for the flag so we catch it regardless of timing.
    StateNotifiers.isTrackingRestored.addListener(_onTrackingRestored);
    // Also handle the case where the flag was already set before we
    // registered the listener (e.g. hot-reload or very fast preload).
    if (StateNotifiers.isTrackingRestored.value) {
      _onTrackingRestored();
    }
  }

  @override
  void dispose() {
    StateNotifiers.isTrackingRestored.removeListener(_onTrackingRestored);
    _timer?.cancel();
    super.dispose();
  }

  /// Called when [StateNotifiers.isTrackingRestored] becomes `true`.
  /// Starts the periodic timer using the already-restored state values
  /// (secondsCounted, startTimestamp, currentShrine).
  void _onTrackingRestored() {
    if (!StateNotifiers.isTrackingRestored.value) return;
    StateNotifiers.isTrackingRestored.value = false; // consume the flag

    _timer?.cancel();
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now()
          .difference(StateNotifiers.startTimestamp.value)
          .inSeconds;
      if (elapsed >= 3600 * 8) {
        StateNotifiers.secondsCounted.value = 3600 * 8;
        _stopTracking();
        return;
      }
      StateNotifiers.secondsCounted.value = elapsed;
    });
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_running) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  void _startTracking() {
    StateNotifiers.secondsCounted.value = 0;
    StateNotifiers.startTimestamp.value = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      StateNotifiers.secondsCounted.value++;
    });

    // Write remote tracking state (fire-and-forget).
    final userId = requireUserId();
    FirestoreHelpers.updateUser(
      userId: userId,
      data: {
        FirestoreConstants.fieldIsTracking: true,
        FirestoreConstants.fieldTrackingStartTimestamp:
            Timestamp.fromDate(StateNotifiers.startTimestamp.value),
        FirestoreConstants.fieldTrackingShrineName:
            StateNotifiers.currentShrine.value.name,
      },
    );

    setState(() => _running = true);
  }

  void _stopTracking() {
    _timer?.cancel();
    _timer = null;

    // Persist the tracked session locally, then sync to remote.
    SqliteHelpers.addLedgerRecord(
      shrineName: StateNotifiers.currentShrine.value.name,
      secondsTracked: StateNotifiers.secondsCounted.value,
      startTimestamp: StateNotifiers.startTimestamp.value,
    ).then((_) => SyncHelpers.localToRemote());

    // Clear remote tracking flag (fire-and-forget).
    final userId = requireUserId();
    FirestoreHelpers.updateUser(
      userId: userId,
      data: {FirestoreConstants.fieldIsTracking: false},
    );

    setState(() => _running = false);
  }

  // Delegates to shared utility.
  static String _format(int seconds) => formatDuration(seconds);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Shrine>(
      valueListenable: StateNotifiers.currentShrine,
      builder: (context, shrine, _) {
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: ElevatedButton(
            onPressed: _toggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: _running
                  ? hexToColor(shrine.color)
                  : Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: StateNotifiers.secondsCounted,
              builder: (context, seconds, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shrine.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _format(seconds),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
