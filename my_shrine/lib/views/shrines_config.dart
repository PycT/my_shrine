import 'package:flutter/material.dart';
import 'package:my_shrine/data/default_shrines.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';
import 'package:my_shrine/widgets/shrine_editor_widget.dart';
import 'package:my_shrine/widgets/shrine_creator_widget.dart';
import 'package:my_shrine/data/app_styles.dart';

class ShrinesConfigPage extends StatelessWidget {
  const ShrinesConfigPage({super.key});

  List<Widget> _shrineEditors(List<Shrine> shrines) {
    final sorted = List<Shrine>.from(shrines)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted
        .map(
          (shrine) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ShrineEditorWidget(
              key: ValueKey(shrine.name),
              shrine: shrine,
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Shrine>>(
      future: ViewDataHelpers.trackerViewPreload(context),
      builder: (context, snapshot) {
        final shrines = snapshot.data ?? defaultShrinesList;
        return Scaffold(
          appBar: AppBar(title: const Text('Shrines Config')),
          body: SafeArea(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ShrineCreatorWidget(),
                SizedBox(height: AppStyles.verticalSeparatorHeight),
                ..._shrineEditors(shrines),
              ],
            ),
          ),
          bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
        );
      },
    );
  }
}
