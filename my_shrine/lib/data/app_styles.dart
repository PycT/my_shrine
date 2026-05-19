import 'package:flutter/material.dart';

class AppStyles {
  static const double preferredAppBarHeight = 56;
  static const double preferredVideoPlayerPlayButtonSize = 48;
  static const double horizontalSeparatorWidth = 32;
  static const double verticalSeparatorHeight = 32;
  static const double inButtonSeparatorWidth = 8;
  static const double generalIconImageSize = 32;

  static const TextStyle timeLedgerDatecardTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 24,
    shadows: <Shadow>[
      Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Colors.grey),
    ],
  );

  static const TextStyle timeLedgerLogCardSubtitleTextStyle = TextStyle(
    fontWeight: FontWeight.normal,
    fontSize: 24,
  );
}
