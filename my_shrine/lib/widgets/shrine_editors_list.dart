import 'package:flutter/material.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/widgets/shrine_editor_widget.dart';

/// A scrollable list of [ShrineEditorWidget] items backed by a
/// [ValueNotifier] so the list can be updated reactively.
class ShrineEditorsWidget extends StatefulWidget {
  /// The initial list of shrines to display.
  final List<Shrine> initialShrines;

  const ShrineEditorsWidget({super.key, required this.initialShrines});

  @override
  State<ShrineEditorsWidget> createState() => ShrineEditorsWidgetState();
}

class ShrineEditorsWidgetState extends State<ShrineEditorsWidget> {
  late final ValueNotifier<List<Shrine>> _shrineEditors;

  @override
  void initState() {
    super.initState();
    _shrineEditors = ValueNotifier<List<Shrine>>(
      List<Shrine>.from(widget.initialShrines),
    );
  }

  @override
  void dispose() {
    _shrineEditors.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShrineEditorsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialShrines != oldWidget.initialShrines) {
      _shrineEditors.value = List<Shrine>.from(widget.initialShrines);
    }
  }

  /// Adds a [Shrine] to the list and triggers a rebuild.
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
    return ValueListenableBuilder<List<Shrine>>(
      valueListenable: _shrineEditors,
      builder: (context, shrines, _) {
        return ListView(children: [..._buildShrineEditors(shrines)]);
      },
    );
  }
}
