import 'package:flutter/material.dart';
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

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: "It is a great day!"),
      body: SafeArea(child: Center(child: Text("Coming soon"))),
      bottomNavigationBar: const CommonNavigationBar(currentIndex: 0),
    );
  }
}
