import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';

class ShrineSwitchWidget extends StatelessWidget {
  final Shrine shrine;

  const ShrineSwitchWidget({super.key, required this.shrine});

  void _onTap() {
    final previous = StateNotifiers.currentShrine.value;
    if (previous.name != shrine.name) {
      if (StateNotifiers.secondsCounted.value > 0) {
        SqliteHelpers.addLedgerRecord(
          shrineName: StateNotifiers.currentShrine.value.name,
          secondsTracked: StateNotifiers.secondsCounted.value,
          startTimestamp: StateNotifiers.startTimestamp.value,
        ).then((_) => SyncHelpers.localToRemote());
        StateNotifiers.secondsCounted.value = 0;
        StateNotifiers.startTimestamp.value = DateTime.now();
      }
    }
    StateNotifiers.currentShrine.value = shrine;
  }

  @override
  Widget build(BuildContext context) {
    Color shrineColor = Color(int.parse('FF${shrine.color}', radix: 16));
    return ElevatedButton(
      onPressed: _onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: shrineColor,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(shrineColor) ==
                Brightness.light
            ? Colors.black
            : Colors.white,
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
