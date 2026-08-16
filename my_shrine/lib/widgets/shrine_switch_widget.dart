import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/tracking_helpers.dart';
import 'package:my_shrine/utils/color_utils.dart';

class ShrineSwitchWidget extends StatelessWidget {
  final Shrine shrine;

  const ShrineSwitchWidget({super.key, required this.shrine});

  void _onTap() {
    final previous = StateNotifiers.currentShrine.value;
    if (previous.name == shrine.name) return;

    final wasTracking = StateNotifiers.isTracking.value;

    if (wasTracking) {
      // Stop the previous shrine's session using the shared helper.
      // We pass a no-op cancelTimer because TrackerToggleWidget owns the
      // actual Timer object; it will receive the isTracking change via its
      // listener and cancel its own timer there. We must not cancel a timer
      // we don't own, so TrackingHelpers.stopTracking only needs to persist
      // the record and flip the flags.
      TrackingHelpers.stopTracking(cancelTimer: () {});
    }

    // Switch the active shrine, then start a fresh session if we were tracking.
    StateNotifiers.currentShrine.value = shrine;

    if (wasTracking) {
      // Start tracking the new shrine immediately from now, with a no-op
      // timer creator — TrackerToggleWidget's _onIsTrackingChanged listener
      // will flip _running and its own timer tick keeps counting. Here we
      // only need TrackingHelpers to reset secondsCounted, set startTimestamp,
      // flip isTracking back to true, and write the remote state.
      TrackingHelpers.startTracking(
        selectedTimestamp: DateTime.now(),
        onTimerCreated: (timer) => timer.cancel(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color shrineColor = hexToColor(shrine.color);
    return ElevatedButton(
      onPressed: _onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: shrineColor,
        foregroundColor: foregroundFor(shrineColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Text(
        shrine.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
