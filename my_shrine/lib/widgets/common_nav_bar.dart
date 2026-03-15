import 'package:flutter/material.dart';
import 'package:my_shrine/views/tracker_view.dart';
import 'package:my_shrine/views/shrines_config.dart';

/// A reusable bottom navigation bar with three tabs:
/// Home (TrackerView), Stats, and Config.
///
/// [currentIndex] indicates which tab is currently active (0 = Home,
/// 1 = Stats, 2 = Config). The active tab's icon appears muted to convey
/// "you are already here".
class CommonNavigationBar extends StatelessWidget {
  /// Index of the currently active page (0 = Home, 1 = Stats, 2 = Config).
  final int currentIndex;

  const CommonNavigationBar({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return; // already on this page

    Widget destination;
    switch (index) {
      case 0:
        // TODO: replace with StatsView
        destination = const Scaffold(
          body: Center(child: Text('Stats — coming soon')),
        );
        break;
      case 1:
        destination = const TrackerViewPage();
        break;
      case 2:
        destination = const ShrinesConfigPage();
        break;
      default:
        return;
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
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
      ],
    );
  }
}
