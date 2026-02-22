import 'package:flutter/material.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';

class TrackerViewPage extends StatelessWidget {
  const TrackerViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      page: TrackerView()
    );
  }
}


class TrackerView extends StatelessWidget {
  const TrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Zhopa")
      )
    );
  }
}