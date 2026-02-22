import 'package:flutter/material.dart';

class AppStyles {
  static const double preferredAppBarHeight = 56;
  static const double preferredVideoPlayerPlayButtonSize = 48;
  static const double horizontalSeparatorWidth = 32;
  static const double verticalSeparatorHeight = 32;
  static const double inButtonSeparatorWidth = 8;
  static const double generalIconImageSize = 32;
  static const Color preferredVideoPlayerPlayButtonColor = Colors.white;


  static const TextStyle landingMainTitleMobile = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.white,
    fontSize: 28,
    shadows: <Shadow>[
      Shadow(
        offset: Offset(2.0, 2.0),
        blurRadius: 3.0,
        color: Colors.black,
      ),
    ],
  );

  static const TextStyle landingOfferTextStyle = TextStyle(
    color: Colors.blue,
    fontSize: 24,
  );

  static const TextStyle generalTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 48,
  );

  static const TextStyle mobileLandingTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 24,
  );


  static const TextStyle generalTextStyle = TextStyle(
    fontSize: 16,
  );


  static final ButtonStyle landingCTAButtonStyleMobile = ElevatedButton.styleFrom(
    backgroundColor: Colors.blueAccent,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: verticalSeparatorHeight, vertical: verticalSeparatorHeight / 3),
    textStyle: const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
  );

  static const TextStyle landingMainTitleDesktop = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.white,
    fontSize: 64,
    shadows: <Shadow>[
      Shadow(
        offset: Offset(2.0, 2.0),
        blurRadius: 3.0,
        color: Colors.black,
      ),
    ],
  );


  static final ButtonStyle landingCTAButtonStyleDesktop = ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: verticalSeparatorHeight, vertical: verticalSeparatorHeight / 2),
    textStyle: const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
  );


  static const TextStyle aiUserTextStyle = TextStyle(
    fontWeight: FontWeight.bold
  );
  static const TextStyle aiAssistantTextStyle = TextStyle(
    fontWeight: FontWeight.normal
  );

  static const TextStyle gremlinMessageTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16 
  );

  static const TextStyle errorMessageTextStyle = TextStyle(
    fontWeight: FontWeight.normal,
    color: Colors.red
  );

  static const TextStyle successMessageTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16
  );

  static const TextStyle systemInfoTextStyle = TextStyle(
    fontSize: 6,
    color: Colors.white30
  );
  
  static const TextStyle subtleTextStyle = TextStyle(
    fontSize: 10,
  );

  static const InputDecoration generalInputStyle = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8))
    )
  );

}