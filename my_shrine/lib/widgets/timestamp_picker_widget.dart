import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/utils/color_utils.dart';

/// Full month names for the calendar header.
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Day-of-week short labels (Monday-first).
const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/// Callback fired when the user confirms a timestamp.
typedef TimestampConfirmedCallback = void Function(DateTime selected);

/// A timestamp picker with an inline calendar for date selection
/// and scrollable wheel columns for Hour and Minute.
///
/// Shown **inline** (not in a bottom sheet). Communicates results via
/// [onConfirmed] / [onDismissed] callbacks.
///
/// Auto-confirms after 10 seconds of inactivity. Once the user interacts
/// with any control, the auto-confirm countdown is cancelled permanently.
class TimestampPickerWidget extends StatefulWidget {
  final DateTime initialValue;
  final String title;
  final String confirmLabel;
  final TimestampConfirmedCallback onConfirmed;
  final VoidCallback? onDismissed;

  const TimestampPickerWidget({
    super.key,
    required this.initialValue,
    required this.title,
    required this.confirmLabel,
    required this.onConfirmed,
    this.onDismissed,
  });

  @override
  State<TimestampPickerWidget> createState() => _TimestampPickerWidgetState();
}

class _TimestampPickerWidgetState extends State<TimestampPickerWidget> {
  static const int _autoConfirmSeconds = 10;

  // ── Date (calendar) ──────────────────────────────────────────────────
  late DateTime _selectedDate; // year, month, day only
  late DateTime _displayedMonth; // year, month for calendar navigation

  // ── Time (rollers) ───────────────────────────────────────────────────
  late int _hour;
  late int _minute;
  late int _second;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _secondCtrl;

  // ── Calendar visibility ──────────────────────────────────────────
  bool _calendarExpanded = false;

  // ── Auto-confirm ─────────────────────────────────────────────────────
  Timer? _countdownTimer;
  int _secondsRemaining = _autoConfirmSeconds;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    final dt = widget.initialValue;
    _selectedDate = DateTime(dt.year, dt.month, dt.day);
    _displayedMonth = DateTime(dt.year, dt.month);
    _hour = dt.hour;
    _minute = dt.minute;
    _second = dt.second;

    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _secondCtrl = FixedExtentScrollController(initialItem: _second);

    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auto-confirm countdown
  // ---------------------------------------------------------------------------

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        _confirm();
      }
    });
  }

  /// Called on any user interaction. Permanently cancels the countdown.
  void _onUserInteraction() {
    if (_userInteracted) return;
    _userInteracted = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Confirm / dismiss
  // ---------------------------------------------------------------------------

  void _confirm() {
    _countdownTimer?.cancel();
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _hour,
      _minute,
      _second,
    );
    widget.onConfirmed(selected);
  }

  void _dismiss() {
    _countdownTimer?.cancel();
    widget.onDismissed?.call();
  }

  // ---------------------------------------------------------------------------
  // Calendar navigation
  // ---------------------------------------------------------------------------

  void _previousMonth() {
    _onUserInteraction();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    _onUserInteraction();
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  void _selectDay(int day) {
    _onUserInteraction();
    setState(() {
      _selectedDate = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        day,
      );
      _calendarExpanded = false;
    });
  }

  // ---------------------------------------------------------------------------
  // "Now" button
  // ---------------------------------------------------------------------------

  void _setNow() {
    _onUserInteraction();
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayedMonth = DateTime(now.year, now.month);
      _hour = now.hour;
      _minute = now.minute;
      _second = now.second;
      _calendarExpanded = false;
    });
    _hourCtrl.animateToItem(
      _hour,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _minuteCtrl.animateToItem(
      _minute,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _secondCtrl.animateToItem(
      _second,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------------------------
  // Time change handlers
  // ---------------------------------------------------------------------------

  void _onHourChanged(int index) {
    _onUserInteraction();
    setState(() => _hour = index);
  }

  void _onMinuteChanged(int index) {
    _onUserInteraction();
    setState(() => _minute = index);
  }

  void _onSecondChanged(int index) {
    _onUserInteraction();
    setState(() => _second = index);
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

  Widget _buildCalendar(Color shrineColor) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // weekday: 1 = Monday … 7 = Sunday → offset for Monday-first grid.
    final firstWeekday = DateTime(year, month, 1).weekday;
    final startOffset = firstWeekday - 1;
    final totalCells = startOffset + daysInMonth;

    final today = DateTime.now();
    final isSelectedInView =
        _selectedDate.year == year && _selectedDate.month == month;
    final isTodayInView =
        today.year == year && today.month == month;

    final weekdayStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Month / year header with navigation arrows ──────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _previousMonth,
              icon: const Icon(Icons.chevron_left, size: 20),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Text(
              '${_monthNames[month - 1]} $year',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: _nextMonth,
              icon: const Icon(Icons.chevron_right, size: 20),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),

        // ── Weekday labels ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: _weekdayLabels
                .map((l) => Expanded(
                      child: Center(child: Text(l, style: weekdayStyle)),
                    ))
                .toList(),
          ),
        ),

        // ── Day grid ────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 36,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();

            final day = index - startOffset + 1;
            final isSelected = isSelectedInView && day == _selectedDate.day;
            final isToday = isTodayInView && day == today.day;

            return GestureDetector(
              onTap: () => _selectDay(day),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? shrineColor
                      : isToday
                          ? shrineColor.withValues(alpha: 0.15)
                          : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? foregroundFor(shrineColor) : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final shrineColor = hexToColor(StateNotifiers.currentShrine.value.color);

    final timeHeaderStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Title ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Date display / Calendar ─────────────────────────────────────
        GestureDetector(
          onTap: () {
            _onUserInteraction();
            setState(() => _calendarExpanded = !_calendarExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')} '
                  '${_monthNames[_selectedDate.month - 1]} '
                  '${_selectedDate.year}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _calendarExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_calendarExpanded) _buildCalendar(shrineColor),

        const SizedBox(height: 8),

        // ── Time column headers ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
                child: Center(child: Text('Hour', style: timeHeaderStyle))),
            Expanded(
                child: Center(child: Text('Min', style: timeHeaderStyle))),
            Expanded(
                child: Center(child: Text('Sec', style: timeHeaderStyle))),
          ],
        ),

        // ── Hour / Minute wheels ─────────────────────────────────────────
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
                    color: shrineColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: shrineColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  // Hour
                  Expanded(
                    child: _buildWheel(
                      itemCount: 24,
                      controller: _hourCtrl,
                      onChanged: _onHourChanged,
                      labelBuilder: (i) => '$i'.padLeft(2, '0'),
                    ),
                  ),
                  // Minute
                  Expanded(
                    child: _buildWheel(
                      itemCount: 60,
                      controller: _minuteCtrl,
                      onChanged: _onMinuteChanged,
                      labelBuilder: (i) => '$i'.padLeft(2, '0'),
                    ),
                  ),
                  // Second
                  Expanded(
                    child: _buildWheel(
                      itemCount: 60,
                      controller: _secondCtrl,
                      onChanged: _onSecondChanged,
                      labelBuilder: (i) => '$i'.padLeft(2, '0'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Now / Cancel row + countdown ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              // "Now" button — yellowish
              ElevatedButton(
                onPressed: _setNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5D060),
                  foregroundColor: const Color(0xFF5A4800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Reset to now',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),

              const Spacer(),

              // Auto-confirm countdown (only while active)
              if (!_userInteracted)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${_secondsRemaining}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),

              // "Cancel" button — reddish
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
            ],
          ),
        ),

        // ── Confirm (full-width, greenish, bottom row) ───────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF6A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                '${widget.confirmLabel} ✓',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
