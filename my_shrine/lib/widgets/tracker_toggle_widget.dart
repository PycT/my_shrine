import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/entities/shrine.dart';

class TrackerToggleWidget extends StatefulWidget {
  const TrackerToggleWidget({super.key});

  @override
  State<TrackerToggleWidget> createState() => _TrackerToggleWidgetState();
}

class _TrackerToggleWidgetState extends State<TrackerToggleWidget> {
  bool _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        StateNotifiers.secondsCounted.value++;
      });
    }
    setState(() => _running = !_running);
  }

  static String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

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
              backgroundColor: _running ? Colors.greenAccent : shrine.color,
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
