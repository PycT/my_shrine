import 'package:flutter/material.dart';

/// Converts a 6-character RRGGBB hex string to a [Color].
Color hexToColor(String hex) => Color(int.parse('FF$hex', radix: 16));

/// Returns black or white depending on the perceived brightness of [color].
Color foregroundFor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? Colors.black
        : Colors.white;
