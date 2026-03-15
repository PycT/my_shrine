import 'package:flutter/material.dart';
import 'package:my_shrine/entities/shrine.dart';
import 'package:my_shrine/widgets/color_picker_widget.dart';

/// Callback fired when the user finishes editing the shrine.
typedef ShrineEditedCallback = void Function(String name, String colorHex);

/// A widget that displays a [Shrine] as a coloured button with a pencil icon.
///
/// Tapping the button switches to **edit mode**: a text field pre-filled with
/// the shrine name, plus a colour-swatch button that opens the
/// [ColorPickerWidget] in a bottom sheet.
///
/// Tapping the confirm (✓) button in edit mode fires [onEdited] and returns
/// to the display state.
class ShrineEditorWidget extends StatefulWidget {
  final Shrine shrine;

  /// Called with the updated name and RRGGBB colour when the user confirms.
  final ShrineEditedCallback? onEdited;

  const ShrineEditorWidget({
    super.key,
    required this.shrine,
    this.onEdited,
  });

  @override
  State<ShrineEditorWidget> createState() => _ShrineEditorWidgetState();
}

class _ShrineEditorWidgetState extends State<ShrineEditorWidget> {
  bool _editing = false;
  late TextEditingController _nameController;
  late String _currentColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shrine.name);
    _currentColor = widget.shrine.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

  Color _foregroundFor(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.light
          ? Colors.black
          : Colors.white;

  void _enterEditMode() => setState(() => _editing = true);

  void _confirm() {
    widget.onEdited?.call(_nameController.text, _currentColor);
    setState(() => _editing = false);
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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bgColor = _hexToColor(_currentColor);
    final fgColor = _foregroundFor(bgColor);

    if (_editing) {
      return _buildEditMode(bgColor, fgColor);
    }
    return _buildDisplayMode(bgColor, fgColor);
  }

  /// Normal state — coloured button with pencil icon + shrine name.
  Widget _buildDisplayMode(Color bgColor, Color fgColor) {
    return ElevatedButton(
      onPressed: _enterEditMode,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 18, color: fgColor),
          const SizedBox(width: 10),
          Text(
            widget.shrine.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Edit state — text field + colour swatch button + confirm button.
  Widget _buildEditMode(Color bgColor, Color fgColor) {
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        ],
      ),
    );
  }
}
