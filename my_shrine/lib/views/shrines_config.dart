import 'package:flutter/material.dart';
import 'package:my_shrine/widgets/common_nav_bar.dart';
import 'package:my_shrine/widgets/color_picker_widget.dart';
import 'package:my_shrine/widgets/shrine_editor_widget.dart';
import 'package:my_shrine/data/state_notifiers.dart';

class ShrinesConfigPage extends StatelessWidget {
  const ShrinesConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shrines Config')),
      body: SafeArea(
        child: ShrineEditorWidget(
          shrine: StateNotifiers.currentShrine.value,
        ), //Column(children: [Center(child: Text('Shrines Config'))]),
      ),
      bottomNavigationBar: const CommonNavigationBar(currentIndex: 2),
    );
  }
}
