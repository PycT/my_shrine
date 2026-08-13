import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/firestore_helpers.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/utils/color_utils.dart';
import 'package:my_shrine/utils/time_format_utils.dart';
import 'package:my_shrine/utils/user_helpers.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';
import 'package:my_shrine/widgets/duration_editor_widget.dart';
import 'package:my_shrine/data/app_styles.dart';

class HistoryViewPage extends StatelessWidget {
  const HistoryViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(page: HistoryView());
  }
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<TimeLedger>? _records;
  Map<String, String>? _shrineColors;
  Object? _error;

  /// The record currently being edited, or `null` when the editor is hidden.
  TimeLedger? _editingRecord;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final (records, colors) = await ViewDataHelpers.historyViewPreload();
      if (!mounted) return;
      setState(() {
        _records = records;
        _shrineColors = colors;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _confirmDelete(TimeLedger record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          '${record.shrineName}\n${formatDuration(record.secondsTracked)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFD05050)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userId = requireUserId();
    await SqliteHelpers.softDeleteLedgerRecord(id: record.id);
    await FirestoreHelpers.softDeleteLedgerRecord(
      userId: userId,
      shrineName: record.shrineName,
      startTimestamp: Timestamp.fromDate(record.startTimestamp),
    );

    setState(() {
      _records?.remove(record);
      // Dismiss the editor if the deleted record was being edited.
      if (_editingRecord == record) _editingRecord = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Edit seconds
  // ---------------------------------------------------------------------------

  void _openEditor(TimeLedger record) {
    setState(() => _editingRecord = record);
  }

  void _closeEditor() {
    setState(() => _editingRecord = null);
  }

  Future<void> _saveSeconds(int newSeconds) async {
    final record = _editingRecord;
    if (record == null) return;

    final userId = requireUserId();
    await SqliteHelpers.updateLedgerSeconds(
      shrineName: record.shrineName,
      startTimestamp: record.startTimestamp,
      secondsTracked: newSeconds,
    );
    await FirestoreHelpers.updateLedgerSeconds(
      userId: userId,
      shrineName: record.shrineName,
      startTimestamp: Timestamp.fromDate(record.startTimestamp),
      secondsTracked: newSeconds,
    );

    if (!mounted) return;

    // Replace the record in the list with updated seconds.
    final index = _records?.indexOf(record) ?? -1;
    if (index >= 0) {
      _records![index] = TimeLedger(
        id: record.id,
        shrineName: record.shrineName,
        secondsTracked: newSeconds,
        startTimestamp: record.startTimestamp,
      );
    }

    setState(() => _editingRecord = null);
  }

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Card builder
  // ---------------------------------------------------------------------------

  Widget logEntryCard(TimeLedger ledger) {
    final colorHex = _shrineColors?[ledger.shrineName] ?? 'E0E0E0';
    return Card(
      color: hexToColor(colorHex),
      child: ListTile(
        title: Text(
          "${_formatTime(ledger.startTimestamp)} - ${ledger.shrineName}",
        ),
        subtitle: Center(
          child: Text(
            formatDuration(ledger.secondsTracked),
            style: AppStyles.timeLedgerLogCardSubtitleTextStyle,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit duration',
              onPressed: () => _openEditor(ledger),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete record',
              onPressed: () => _confirmDelete(ledger),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildLogEntries(List<TimeLedger> timeLedger) {
    List<Widget> result = [];
    // Sentinel date that will never match a real entry, ensuring the first
    // record always gets a date header.
    DateTime lastDateShown = DateTime(1970);
    for (final ledger in timeLedger) {
      if (ledger.startTimestamp.day != lastDateShown.day ||
          ledger.startTimestamp.month != lastDateShown.month ||
          ledger.startTimestamp.year != lastDateShown.year) {
        result.add(
          Container(
            padding: EdgeInsets.all(8),
            child: Center(
              child: Text(
                _formatDate(ledger.startTimestamp),
                style: AppStyles.timeLedgerDatecardTextStyle,
              ),
            ),
          ),
        );
        lastDateShown = ledger.startTimestamp;
      }
      result.add(logEntryCard(ledger));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_records == null && _error == null) {
      return Scaffold(
        appBar: CommonAppBar(),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
      );
    }

    // Error state
    if (_error != null) {
      return Scaffold(
        appBar: CommonAppBar(),
        body: Center(child: Text('Error: $_error')),
        bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
      );
    }

    final records = _records ?? <TimeLedger>[];

    return Scaffold(
      appBar: CommonAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            // ── List ───────────────────────────────────────────────────
            ListView(
              padding: EdgeInsets.only(
                top: _editingRecord != null ? 0 : 16,
                bottom: 16,
              ),
              children: buildLogEntries(records),
            ),

            // ── Duration editor overlay ────────────────────────────────
            if (_editingRecord != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DurationEditorWidget(
                  key: ValueKey(_editingRecord!.id),
                  initialSeconds: _editingRecord!.secondsTracked,
                  title: _editingRecord!.shrineName,
                  onConfirmed: _saveSeconds,
                  onDismissed: _closeEditor,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
    );
  }
}
