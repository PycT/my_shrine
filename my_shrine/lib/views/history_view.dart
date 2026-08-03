import 'package:flutter/material.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/utils/color_utils.dart';
import 'package:my_shrine/utils/time_format_utils.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';
import 'package:my_shrine/data/app_styles.dart';

class HistoryViewPage extends StatelessWidget {
  const HistoryViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(page: HistoryView());
  }
}

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<TimeLedger>, Map<String, String>)>(
      future: ViewDataHelpers.historyViewPreload(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: CommonAppBar(),
            body: const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: CommonAppBar(),
            body: Center(child: Text('Error: ${snapshot.error}')),
            bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
          );
        }
        final (timeLedger, shrineColors) =
            snapshot.data ?? (<TimeLedger>[], <String, String>{});
        return Scaffold(
          appBar: CommonAppBar(),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: buildLogEntries(timeLedger, shrineColors),
            ),
          ),
          bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
  }

  Widget logEntryCard(TimeLedger ledger, Map<String, String> shrineColors) {
    final colorHex = shrineColors[ledger.shrineName] ?? 'E0E0E0';
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
      ),
    );
  }

  List<Widget> buildLogEntries(
    List<TimeLedger> timeLedger,
    Map<String, String> shrineColors,
  ) {
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
      result.add(logEntryCard(ledger, shrineColors));
    }
    return result;
  }
}
