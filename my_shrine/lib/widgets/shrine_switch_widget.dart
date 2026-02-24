import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';

class ShrineSwitchWidget extends StatelessWidget {
  final Shrine shrine;

  const ShrineSwitchWidget({super.key, required this.shrine});

  void _onTap() {
    final previous = StateNotifiers.currentShrine.value;
    if (previous.name != shrine.name) {
      StateNotifiers.secondsCounted.value = 0;
    }
    StateNotifiers.currentShrine.value = shrine;
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: shrine.color,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(shrine.color) ==
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
