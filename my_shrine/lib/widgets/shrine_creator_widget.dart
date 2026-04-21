import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_shrine/data/app_colors.dart';
import 'package:my_shrine/helpers/sqlite_helpers.dart';
import 'package:my_shrine/helpers/sync_helpers.dart';
import 'package:my_shrine/widgets/color_picker_widget.dart';

/// Callback fired when the user successfully creates a new shrine.
typedef ShrineCreatedCallback = void Function(String name, String colorHex);

/// A widget that displays a grey "add" button.
///
/// Tapping the button switches to **create mode**: an empty text field for the
/// shrine name, a colour-swatch button that opens [ColorPickerWidget] in a
/// bottom sheet (with a random default colour), plus confirm (✓) and cancel (✗)
/// buttons.
///
/// Tapping confirm saves the new shrine to local SQLite via [SqliteHelpers] and
/// syncs to Firestore via [SyncHelpers]. Tapping cancel returns to the default
/// state without creating anything.
class ShrineCreatorWidget extends StatefulWidget {
  /// Called with the new shrine name and RRGGBB colour when creation succeeds.
  final ShrineCreatedCallback? onCreated;

  const ShrineCreatorWidget({super.key, this.onCreated});

  @override
  State<ShrineCreatorWidget> createState() => _ShrineCreatorWidgetState();
}

class _ShrineCreatorWidgetState extends State<ShrineCreatorWidget> {
  bool _creating = false;
  late TextEditingController _nameController;
  late String _currentColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _currentColor = _randomColor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Picks a random colour hex from the default palette.
  String _randomColor() {
    final values = appColors.values.toList();
    return values[Random().nextInt(values.length)];
  }

  Color _hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

  Color _foregroundFor(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.light
      ? Colors.black
      : Colors.white;

  void _enterCreateMode() => setState(() {
    _nameController.clear();
    _currentColor = _randomColor();
    _creating = true;
  });

  void _cancel() => setState(() => _creating = false);

  /// Shows a floating [SnackBar] with [message] for 3 seconds.
  void _showAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirm() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showAlert("Can't create a shrine with no name");
      return;
    }

    // Persist the new shrine to local SQLite.
    await SqliteHelpers.addShrine(shrineName: name, shrineColor: _currentColor);

    // Sync local DB to Firestore.
    await SyncHelpers.localToRemote();

    widget.onCreated?.call(name, _currentColor);
    setState(() => _creating = false);
  }

  void _openColorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: ColorPickerWidget(
          initialColor: _currentColor,
          onColorPicked: (hex) {
            setState(() => _currentColor = hex);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_creating) {
      final bgColor = _hexToColor(_currentColor);
      final fgColor = _foregroundFor(bgColor);
      return _buildCreateMode(bgColor, fgColor);
    }
    return _buildDisplayMode();
  }

  /// Default state — grey button with an "add" icon.
  Widget _buildDisplayMode() {
    return ElevatedButton(
      onPressed: _enterCreateMode,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.add_task, size: 28, color: Colors.black)],
      ),
    );
  }

  /// Create mode — text field + colour swatch button + confirm + cancel.
  Widget _buildCreateMode(Color bgColor, Color fgColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Colour swatch button — opens the picker
          GestureDetector(
            onTap: _openColorPicker,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Icon(Icons.palette, size: 18, color: fgColor),
            ),
          ),
          const SizedBox(width: 12),

          // Name text field
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'New shrine name',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Confirm button
          IconButton(
            onPressed: _confirm,
            icon: const Icon(Icons.check_circle),
            color: Theme.of(context).colorScheme.primary,
            iconSize: 28,
          ),

          // Cancel button
          IconButton(
            onPressed: _cancel,
            icon: const Icon(Icons.cancel),
            color: Theme.of(context).colorScheme.error,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}
