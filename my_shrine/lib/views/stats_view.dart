import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';

class StatsViewPage extends StatelessWidget {
  const StatsViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(page: StatsView());
  }
}

/// Aggregation mode for the stats view.
enum StatsMode { year, month, sevenDays, allTime }

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  StatsMode _mode = StatsMode.month;
  late int _yearToShow;
  late int _monthToShow;
  late DateTime _dateOfWeekToShow;
  int _touchedIndex = -1;

  // Preloaded data
  List<TimeLedger>? _allRecords;
  Map<String, String>? _shrineColors;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _yearToShow = now.year;
    _monthToShow = now.month;
    _dateOfWeekToShow = now.subtract(const Duration(days: 7));
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final (records, colors) = await ViewDataHelpers.historyViewPreload();
      if (mounted) {
        setState(() {
          _allRecords = records;
          _shrineColors = colors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<TimeLedger> _filteredRecords() {
    if (_allRecords == null) return [];
    switch (_mode) {
      case StatsMode.year:
        return _allRecords!
            .where((r) => r.startTimestamp.year == _yearToShow)
            .toList();
      case StatsMode.month:
        return _allRecords!
            .where(
              (r) =>
                  r.startTimestamp.year == _yearToShow &&
                  r.startTimestamp.month == _monthToShow,
            )
            .toList();
      case StatsMode.sevenDays:
        final start = _dateOfWeekToShow;
        final end = start.add(const Duration(days: 7));
        return _allRecords!
            .where(
              (r) =>
                  !r.startTimestamp.isBefore(start) &&
                  r.startTimestamp.isBefore(end),
            )
            .toList();
      case StatsMode.allTime:
        return List.from(_allRecords!);
    }
  }

  // ---------------------------------------------------------------------------
  // Aggregation
  // ---------------------------------------------------------------------------

  /// Returns a list of (shrineName, totalSeconds) sorted descending, excluding
  /// shrines with 0 seconds.
  List<({String name, int seconds})> _aggregate(List<TimeLedger> records) {
    final map = <String, int>{};
    for (final r in records) {
      map[r.shrineName] = (map[r.shrineName] ?? 0) + r.secondsTracked;
    }
    final entries =
        map.entries
            .where((e) => e.value > 0)
            .map((e) => (name: e.key, seconds: e.value))
            .toList();
    entries.sort((a, b) => b.seconds.compareTo(a.seconds));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Arrow boundary logic
  // ---------------------------------------------------------------------------

  bool _canGoBack() {
    if (_allRecords == null || _allRecords!.isEmpty) return false;
    switch (_mode) {
      case StatsMode.allTime:
        return false;
      case StatsMode.year:
        return _allRecords!.any(
          (r) => r.startTimestamp.year < _yearToShow,
        );
      case StatsMode.month:
        final prevMonth =
            _monthToShow == 1
                ? DateTime(_yearToShow - 1, 12)
                : DateTime(_yearToShow, _monthToShow - 1);
        return _allRecords!.any(
          (r) =>
              r.startTimestamp.year == prevMonth.year &&
              r.startTimestamp.month == prevMonth.month,
        );
      case StatsMode.sevenDays:
        final prevStart = _dateOfWeekToShow.subtract(const Duration(days: 7));
        final prevEnd = _dateOfWeekToShow;
        return _allRecords!.any(
          (r) =>
              !r.startTimestamp.isBefore(prevStart) &&
              r.startTimestamp.isBefore(prevEnd),
        );
    }
  }

  bool _canGoForward() {
    if (_allRecords == null || _allRecords!.isEmpty) return false;
    switch (_mode) {
      case StatsMode.allTime:
        return false;
      case StatsMode.year:
        return _allRecords!.any(
          (r) => r.startTimestamp.year > _yearToShow,
        );
      case StatsMode.month:
        final nextMonth =
            _monthToShow == 12
                ? DateTime(_yearToShow + 1, 1)
                : DateTime(_yearToShow, _monthToShow + 1);
        return _allRecords!.any(
          (r) =>
              r.startTimestamp.year == nextMonth.year &&
              r.startTimestamp.month == nextMonth.month,
        );
      case StatsMode.sevenDays:
        final nextStart = _dateOfWeekToShow.add(const Duration(days: 7));
        final nextEnd = nextStart.add(const Duration(days: 7));
        return _allRecords!.any(
          (r) =>
              !r.startTimestamp.isBefore(nextStart) &&
              r.startTimestamp.isBefore(nextEnd),
        );
    }
  }

  void _goBack() {
    setState(() {
      _touchedIndex = -1;
      switch (_mode) {
        case StatsMode.year:
          _yearToShow--;
          break;
        case StatsMode.month:
          if (_monthToShow == 1) {
            _monthToShow = 12;
            _yearToShow--;
          } else {
            _monthToShow--;
          }
          break;
        case StatsMode.sevenDays:
          _dateOfWeekToShow = _dateOfWeekToShow.subtract(
            const Duration(days: 7),
          );
          break;
        case StatsMode.allTime:
          break;
      }
    });
  }

  void _goForward() {
    setState(() {
      _touchedIndex = -1;
      switch (_mode) {
        case StatsMode.year:
          _yearToShow++;
          break;
        case StatsMode.month:
          if (_monthToShow == 12) {
            _monthToShow = 1;
            _yearToShow++;
          } else {
            _monthToShow++;
          }
          break;
        case StatsMode.sevenDays:
          _dateOfWeekToShow = _dateOfWeekToShow.add(
            const Duration(days: 7),
          );
          break;
        case StatsMode.allTime:
          break;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatSeconds(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _periodLabel() {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const monthAbbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    switch (_mode) {
      case StatsMode.year:
        return '$_yearToShow';
      case StatsMode.month:
        return '${monthNames[_monthToShow]} $_yearToShow';
      case StatsMode.sevenDays:
        final start = _dateOfWeekToShow;
        final end = start.add(const Duration(days: 6));
        return '${monthAbbr[start.month]} ${start.day} – '
            '${monthAbbr[end.month]} ${end.day}';
      case StatsMode.allTime:
        return 'All time';
    }
  }

  Color _shrineColor(String shrineName) {
    final hex = _shrineColors?[shrineName];
    if (hex != null && hex.length == 6) {
      return Color(int.parse('0xFF$hex'));
    }
    return Colors.grey;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: CommonAppBar(title: "It is a great day!"),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const CommonNavigationBar(currentIndex: 0),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: CommonAppBar(title: "It is a great day!"),
        body: Center(child: Text('Error: $_error')),
        bottomNavigationBar: const CommonNavigationBar(currentIndex: 0),
      );
    }

    final filtered = _filteredRecords();
    final aggregated = _aggregate(filtered);
    final totalSeconds = aggregated.fold<int>(0, (sum, e) => sum + e.seconds);

    return Scaffold(
      appBar: CommonAppBar(title: "It is a great day!"),
      body: SafeArea(
        child: Column(
          children: [
            _buildControlPane(context),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (aggregated.isNotEmpty)
                    _buildPieChart(aggregated, totalSeconds),
                  if (aggregated.isNotEmpty) const SizedBox(height: 24),
                  if (aggregated.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: Center(
                        child: Text(
                          'No data for this period',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ...aggregated.map(
                    (entry) => _buildShrineCard(entry, totalSeconds),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CommonNavigationBar(currentIndex: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Control pane
  // ---------------------------------------------------------------------------

  Widget _buildControlPane(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeSelector(theme),
          const SizedBox(height: 8),
          _buildArrowRow(theme),
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    const labels = {
      StatsMode.year: 'Year',
      StatsMode.month: 'Month',
      StatsMode.sevenDays: '7 days',
      StatsMode.allTime: 'All time',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          StatsMode.values.map((mode) {
            final selected = mode == _mode;
            return ChoiceChip(
              label: Text(labels[mode]!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _mode = mode;
                  _touchedIndex = -1;
                });
              },
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color:
                    selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            );
          }).toList(),
    );
  }

  Widget _buildArrowRow(ThemeData theme) {
    final canBack = _canGoBack();
    final canFwd = _canGoForward();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: canBack ? _goBack : null,
          tooltip: 'Previous period',
        ),
        Text(
          _periodLabel(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canFwd ? _goForward : null,
          tooltip: 'Next period',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pie chart
  // ---------------------------------------------------------------------------

  Widget _buildPieChart(
    List<({String name, int seconds})> data,
    int totalSeconds,
  ) {
    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sections: _buildPieSections(data, totalSeconds),
          centerSpaceRadius: 48,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<({String name, int seconds})> data,
    int totalSeconds,
  ) {
    return List.generate(data.length, (i) {
      final entry = data[i];
      final isTouched = i == _touchedIndex;
      final pct =
          totalSeconds > 0 ? (entry.seconds / totalSeconds * 100) : 0.0;
      final radius = isTouched ? 64.0 : 52.0;
      final fontSize = isTouched ? 14.0 : 12.0;

      return PieChartSectionData(
        color: _shrineColor(entry.name),
        value: entry.seconds.toDouble(),
        title: isTouched ? '${entry.name}\n${_formatSeconds(entry.seconds)}\n${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54),
          ],
        ),
        titlePositionPercentageOffset: isTouched ? 0.55 : 0.5,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Shrine cards
  // ---------------------------------------------------------------------------

  Widget _buildShrineCard(
    ({String name, int seconds}) entry,
    int totalSeconds,
  ) {
    final pct =
        totalSeconds > 0 ? (entry.seconds / totalSeconds * 100) : 0.0;
    final color = _shrineColor(entry.name);

    return Card(
      color: color,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          entry.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Colors.black38,
              ),
            ],
          ),
        ),
        trailing: Text(
          '${_formatSeconds(entry.seconds)}  (${pct.toStringAsFixed(1)}%)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
