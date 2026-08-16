import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/tracking_helpers.dart';
import 'package:my_shrine/utils/color_utils.dart';
import 'package:my_shrine/utils/time_format_utils.dart';
import 'package:my_shrine/widgets/timestamp_picker_widget.dart';

class TrackerToggleWidget extends StatefulWidget {
  const TrackerToggleWidget({super.key});

  @override
  State<TrackerToggleWidget> createState() => _TrackerToggleWidgetState();
}

class _TrackerToggleWidgetState extends State<TrackerToggleWidget> {
  bool _running = false;
  bool _showingPicker = false;
  Timer? _timer;

  /// Remembers whether the toggle was in running state when picker opened,
  /// so we know whether to start or stop on confirmation.
  bool _wasRunningOnPickerOpen = false;

  @override
  void initState() {
    super.initState();
    // trackerViewPreload runs in a FutureBuilder and may set
    // isTrackingRestored *after* this initState has already executed.
    // Listen for the flag so we catch it regardless of timing.
    StateNotifiers.isTrackingRestored.addListener(_onTrackingRestored);
    // Mirror external isTracking changes (e.g. from ShrineSwitchWidget).
    StateNotifiers.isTracking.addListener(_onIsTrackingChanged);
    // Also handle the case where the flag was already set before we
    // registered the listener (e.g. hot-reload or very fast preload).
    if (StateNotifiers.isTrackingRestored.value) {
      _onTrackingRestored();
    }
  }

  @override
  void dispose() {
    StateNotifiers.isTrackingRestored.removeListener(_onTrackingRestored);
    StateNotifiers.isTracking.removeListener(_onIsTrackingChanged);
    _timer?.cancel();
    super.dispose();
  }

  /// Keeps [_running] in sync when [StateNotifiers.isTracking] is changed
  /// externally (e.g. by [ShrineSwitchWidget] starting a new session).
  void _onIsTrackingChanged() {
    final nowTracking = StateNotifiers.isTracking.value;
    if (_running != nowTracking && mounted) {
      setState(() => _running = nowTracking);
    }
  }

  /// Called when [StateNotifiers.isTrackingRestored] becomes `true`.
  /// Starts the periodic timer using the already-restored state values
  /// (secondsCounted, startTimestamp, currentShrine).
  void _onTrackingRestored() {
    if (!StateNotifiers.isTrackingRestored.value) return;
    StateNotifiers.isTrackingRestored.value = false; // consume the flag

    _timer?.cancel();
    _running = true;
    StateNotifiers.isTracking.value = true;
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

  // ---------------------------------------------------------------------------
  // Picker flow
  // ---------------------------------------------------------------------------

  void _openPicker() {
    _wasRunningOnPickerOpen = _running;
    setState(() => _showingPicker = true);
  }

  void _onTimestampConfirmed(DateTime selected) {
    if (!mounted) return;
    setState(() => _showingPicker = false);

    if (_wasRunningOnPickerOpen) {
      _stopTracking(selected);
    } else {
      _startTracking(selected);
    }
  }

  void _onTimestampDismissed() {
    if (!mounted) return;
    setState(() => _showingPicker = false);
  }

  // ---------------------------------------------------------------------------
  // Start / stop tracking
  // ---------------------------------------------------------------------------

  void _startTracking(DateTime selectedTimestamp) {
    TrackingHelpers.startTracking(
      selectedTimestamp: selectedTimestamp,
      onTimerCreated: (timer) {
        // Wrap the timer so the 8-hour auto-stop calls our local _stopTracking.
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          final elapsed = DateTime.now()
              .difference(StateNotifiers.startTimestamp.value)
              .inSeconds;
          if (elapsed < 0) {
            StateNotifiers.secondsCounted.value = 0;
            return;
          }
          if (elapsed >= 3600 * 8) {
            StateNotifiers.secondsCounted.value = 3600 * 8;
            _stopTracking();
            return;
          }
          StateNotifiers.secondsCounted.value = elapsed;
        });
        // Cancel the timer created by TrackingHelpers (we run our own above
        // so that the 8-hour ceiling still routes through _stopTracking here).
        timer.cancel();
      },
    );
    setState(() => _running = true);
  }

  void _stopTracking([DateTime? stopTimestamp]) {
    TrackingHelpers.stopTracking(
      cancelTimer: () {
        _timer?.cancel();
        _timer = null;
      },
      stopTimestamp: stopTimestamp,
    );
    setState(() => _running = false);
  }


  // Delegates to shared utility.
  static String _format(int seconds) => formatDuration(seconds);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Shrine>(
      valueListenable: StateNotifiers.currentShrine,
      builder: (context, shrine, _) {
        final width = MediaQuery.of(context).size.width * 0.8;

        // ── Picker mode: replaces the button ─────────────────────────────
        if (_showingPicker) {
          return SizedBox(
            width: width,
            child: TimestampPickerWidget(
              initialValue: DateTime.now(),
              title: _wasRunningOnPickerOpen
                  ? 'Stopping at'
                  : 'Starting at',
              confirmLabel: _wasRunningOnPickerOpen
                  ? 'Stop tracking'
                  : 'Start tracking',
              onConfirmed: _onTimestampConfirmed,
              onDismissed: _onTimestampDismissed,
            ),
          );
        }

        // ── Normal toggle button ─────────────────────────────────────────
        return SizedBox(
          width: width,
          child: ElevatedButton(
            onPressed: _openPicker,
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
