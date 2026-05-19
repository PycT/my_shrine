import 'package:flutter/material.dart';
import 'package:my_shrine/entities/time_ledger.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
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
            appBar: CommonAppBar(title: "It is a great day!"),
            body: const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: CommonAppBar(title: "It is a great day!"),
            body: Center(child: Text('Error: ${snapshot.error}')),
            bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
          );
        }
        final (timeLedger, shrineColors) =
            snapshot.data ?? (<TimeLedger>[], <String, String>{});
        return Scaffold(
          appBar: CommonAppBar(title: "It is a great day!"),
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

  String timeBuilder(int secondsTracked) {
    final hours = secondsTracked ~/ 3600;
    final minutes = (secondsTracked % 3600) ~/ 60;
    final seconds = secondsTracked % 60;
    return "$hours:$minutes:$seconds";
  }

  String hourBuilder(DateTime startTimestamp) {
    return startTimestamp.toString().substring(10, 19);
  }

  Widget logEntryCard(TimeLedger ledger, Map<String, String> shrineColors) {
    return Card(
      color: Color(int.parse("0xFF${shrineColors[ledger.shrineName] ?? 0}")),
      child: ListTile(
        title: Text(
          "${hourBuilder(ledger.startTimestamp)} - ${ledger.shrineName}",
        ),
        subtitle: Center(
          child: Text(
            timeBuilder(ledger.secondsTracked),
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
    DateTime now = DateTime(2000, 1, 1); //DateTime.now();
    for (final ledger in timeLedger) {
      if (ledger.startTimestamp.day != now.day) {
        result.add(
          Container(
            padding: EdgeInsets.all(8),
            child: Center(
              child: Text(
                ledger.startTimestamp.toString().substring(0, 10),
                style: AppStyles.timeLedgerDatecardTextStyle,
              ),
            ),
          ),
        );
        now = ledger.startTimestamp;
      }
      result.add(logEntryCard(ledger, shrineColors));
    }
    return result;
  }
}
