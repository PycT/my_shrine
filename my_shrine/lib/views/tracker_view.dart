import 'package:flutter/material.dart';
import 'package:my_shrine/data/app_styles.dart';
import 'package:my_shrine/widgets/authentication/auth_gate.dart';
import 'package:my_shrine/widgets/common_app_bar.dart';
import 'package:my_shrine/widgets/shrine_switch_widget.dart';
import 'package:my_shrine/widgets/tracker_toggle_widget.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/data/default_shrines.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';

class TrackerViewPage extends StatelessWidget {
  const TrackerViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(page: TrackerView());
  }
}

class TrackerView extends StatelessWidget {
  const TrackerView({super.key});

  List<Widget> _shrineSwitches(List<Shrine> shrines) {
    return shrines.map((shrine) => ShrineSwitchWidget(shrine: shrine)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Shrine>>(
      future: ViewDataHelpers.trackerViewPreload(
        onError: (msg) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      builder: (context, snapshot) {
        final shrines = snapshot.data ?? defaultShrinesList;
        return Scaffold(
          appBar: CommonAppBar(),
          body: SafeArea(
            child: Center(
              child: Column(
                children: [
                  TrackerToggleWidget(),
                  SizedBox(height: AppStyles.verticalSeparatorHeight * 2),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: Wrap(
                          spacing: AppStyles.verticalSeparatorHeight,
                          runSpacing: AppStyles.verticalSeparatorHeight,
                          children: _shrineSwitches(shrines),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const CommonNavigationBar(currentIndex: 1),
        );
      },
    );
  }
}
