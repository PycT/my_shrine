import 'package:flutter/material.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';

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
    return Scaffold(
      appBar: CommonAppBar(title: "My Shrine"),
      body: Center(child: Text("Zhopa")),
    );
  }
}
