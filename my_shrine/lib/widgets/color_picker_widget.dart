import 'package:flutter/material.dart';
import 'package:my_shrine/data/app_colors.dart';

/// A map of 32 curated colour names → RRGGBB hex strings.
/// Every colour is a mid-tone that reads well on both light and dark
/// backgrounds.
const Map<String, String> _palette = appColors;

/// Callback fired every time the user picks a colour.
typedef ColorPickedCallback = void Function(String hexColor);

/// A colour-picker widget.
///
/// Displays a preview square at the top showing the currently chosen colour and
/// its name, followed by a scrollable list of 32 colour buttons.
///
/// [initialColor] (optional) sets the starting RRGGBB hex value.
/// [onColorPicked] is called whenever the selection changes.
class ColorPickerWidget extends StatefulWidget {
  /// Optional initial colour in RRGGBB format (e.g. `'E07070'`).
  final String? initialColor;

  /// Called with the RRGGBB hex string each time the user picks a colour.
  final ColorPickedCallback? onColorPicked;

  const ColorPickerWidget({super.key, this.initialColor, this.onColorPicked});

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  late String colorPicked;

  @override
  void initState() {
    super.initState();
    colorPicked = widget.initialColor ?? _palette.values.first;
  }

  /// Resolve the display name for the current [colorPicked].
  String get _colorName {
    for (final entry in _palette.entries) {
      if (entry.value.toUpperCase() == colorPicked.toUpperCase()) {
        return entry.key;
      }
    }
    return colorPicked; // fallback: show the raw hex
  }

  Color _hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

  void _select(String hex) {
    setState(() => colorPicked = hex);
    widget.onColorPicked?.call(hex);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pickedColor = _hexToColor(colorPicked);
    final textColor =
        ThemeData.estimateBrightnessForColor(pickedColor) == Brightness.light
        ? Colors.black
        : Colors.white;

    return Column(
      children: [
        // ── Preview square ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 72,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pickedColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            _colorName,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Scrollable colour list ──────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _palette.length,
            itemBuilder: (context, index) {
              final name = _palette.keys.elementAt(index);
              final hex = _palette.values.elementAt(index);
              final color = _hexToColor(hex);
              final isSelected = hex.toUpperCase() == colorPicked.toUpperCase();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () => _select(hex),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    elevation: isSelected ? 0 : 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? BorderSide(color: color, width: 2)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      // round colour indicator
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // colour name
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
