import 'package:flutter/material.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';
import 'package:my_shrine/widgets/tracker_toggle_widget.dart';
import 'package:my_shrine/entities/shrine.dart';

class TrackerViewPage extends StatelessWidget {
  const TrackerViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(page: TrackerView());
  }
}

class TrackerView extends StatelessWidget {
  const TrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    final shrines = [
      Shrine(name: "Shrine 1", color: Colors.red),
      Shrine(name: "Shrine 2", color: Colors.green),
      Shrine(name: "Shrine 3", color: Colors.blue),
    ];
    return Scaffold(
      appBar: CommonAppBar(title: "It is a great day!"),
      body: SafeArea(
        child: Center(child: Column(children: [TrackerToggleWidget()])),
      ),
    );
  }
}
