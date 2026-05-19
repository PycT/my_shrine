import 'package:flutter/material.dart';
import 'package:my_shrine/views/tracker_view.dart';
import 'package:my_shrine/views/shrines_config.dart';
import 'package:my_shrine/views/stats_view.dart';
import 'package:my_shrine/views/history_view.dart';

class CommonNavigationBar extends StatelessWidget {
  final int currentIndex;

  const CommonNavigationBar({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return; // already on this page

    Widget destination;
    switch (index) {
      case 0:
        destination = const StatsViewPage();
        break;
      case 1:
        destination = const TrackerViewPage();
        break;
      case 2:
        destination = const HistoryViewPage();
        break;
      case 3:
        destination = const ShrinesConfigPage();
        break;
      default:
        destination = const TrackerViewPage();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      selectedItemColor: Theme.of(context).disabledColor,
      unselectedItemColor: Theme.of(context).colorScheme.primary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
      ],
    );
  }
}
