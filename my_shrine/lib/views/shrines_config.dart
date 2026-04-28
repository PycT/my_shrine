import 'package:flutter/material.dart';
import 'package:my_shrine/data/default_shrines.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/helpers/view_data_helpers.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';
import 'package:my_shrine/widgets/shrine_creator_widget.dart';
import 'package:my_shrine/widgets/shrine_editor_widget.dart';
import 'package:my_shrine/data/app_styles.dart';

class ShrinesConfigPage extends StatefulWidget {
  const ShrinesConfigPage({super.key});

  @override
  State<ShrinesConfigPage> createState() => _ShrinesConfigPageState();
}

class _ShrinesConfigPageState extends State<ShrinesConfigPage> {
  late final ValueNotifier<List<Shrine>> _shrineEditors;

  @override
  void initState() {
    super.initState();
    _shrineEditors = ValueNotifier<List<Shrine>>(
      List<Shrine>.from(defaultShrinesList),
    );
    _loadShrines();
  }

  Future<void> _loadShrines() async {
    final shrines = await ViewDataHelpers.trackerViewPreload(context);
    _shrineEditors.value = List<Shrine>.from(shrines);
  }

  @override
  void dispose() {
    _shrineEditors.dispose();
    super.dispose();
  }

  void addShrine(Shrine shrine) {
    _shrineEditors.value = [shrine, ..._shrineEditors.value];
  }

  List<Widget> _buildShrineEditors(List<Shrine> shrines) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Shrines Config')),
      body: SafeArea(
        child: Column(
          children: [
            ShrineCreatorWidget(
              onCreated: (name, colorHex) {
                addShrine(Shrine(name: name, color: colorHex));
              },
            ),
            SizedBox(height: AppStyles.verticalSeparatorHeight),
            Expanded(
              child: ValueListenableBuilder<List<Shrine>>(
                valueListenable: _shrineEditors,
                builder: (context, shrines, _) {
                  return ListView(children: [..._buildShrineEditors(shrines)]);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
    );
  }
}
