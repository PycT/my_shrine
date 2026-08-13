import 'package:flutter/material.dart';

/// Callback fired when the user confirms a new duration.
typedef DurationConfirmedCallback = void Function(int newSeconds);

/// A compact duration editor with three scrollable wheel columns
/// for hours, minutes, and seconds.
///
/// Designed to be used as an overlay banner. Communicates the result
/// via [onConfirmed]; dismissal via [onDismissed].
class DurationEditorWidget extends StatefulWidget {
  final int initialSeconds;
  final String title;
  final DurationConfirmedCallback onConfirmed;
  final VoidCallback? onDismissed;

  const DurationEditorWidget({
    super.key,
    required this.initialSeconds,
    required this.title,
    required this.onConfirmed,
    this.onDismissed,
  });

  @override
  State<DurationEditorWidget> createState() => _DurationEditorWidgetState();
}

class _DurationEditorWidgetState extends State<DurationEditorWidget> {
  late int _hours;
  late int _minutes;
  late int _seconds;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _secondCtrl;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialSeconds ~/ 3600;
    _minutes = (widget.initialSeconds % 3600) ~/ 60;
    _seconds = widget.initialSeconds % 60;

    _hourCtrl = FixedExtentScrollController(initialItem: _hours);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minutes);
    _secondCtrl = FixedExtentScrollController(initialItem: _seconds);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final newSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    widget.onConfirmed(newSeconds);
  }

  void _dismiss() {
    widget.onDismissed?.call();
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildWheel({
    required int itemCount,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
    required String Function(int index) labelBuilder,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      perspective: 0.003,
      diameterRatio: 1.5,
      useMagnifier: true,
      magnification: 1.4,
      physics: const FixedExtentScrollPhysics(),
      overAndUnderCenterOpacity: 0.35,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= itemCount) return null;
          return Center(
            child: Text(
              labelBuilder(index),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        childCount: itemCount,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );

    return Material(
      elevation: 4,
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ────────────────────────────────────────────────────
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // ── Column headers ───────────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: Center(child: Text('Hour', style: headerStyle))),
                Expanded(
                    child: Center(child: Text('Min', style: headerStyle))),
                Expanded(
                    child: Center(child: Text('Sec', style: headerStyle))),
              ],
            ),

            // ── H / M / S wheels ─────────────────────────────────────────
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  // Selection highlight band
                  Center(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Hours
                      Expanded(
                        child: _buildWheel(
                          itemCount: 24,
                          controller: _hourCtrl,
                          onChanged: (i) => setState(() => _hours = i),
                          labelBuilder: (i) => '$i'.padLeft(2, '0'),
                        ),
                      ),
                      // Minutes
                      Expanded(
                        child: _buildWheel(
                          itemCount: 60,
                          controller: _minuteCtrl,
                          onChanged: (i) => setState(() => _minutes = i),
                          labelBuilder: (i) => '$i'.padLeft(2, '0'),
                        ),
                      ),
                      // Seconds
                      Expanded(
                        child: _buildWheel(
                          itemCount: 60,
                          controller: _secondCtrl,
                          onChanged: (i) => setState(() => _seconds = i),
                          labelBuilder: (i) => '$i'.padLeft(2, '0'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Cancel / Save buttons ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _dismiss,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFD05050),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF6A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Save ✓',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
