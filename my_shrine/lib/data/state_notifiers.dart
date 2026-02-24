import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:my_shrine/entities/shrine.dart';

class StateNotifiers {
  static ValueNotifier<bool> isLightMode = ValueNotifier(true);

  static ValueNotifier<User?> user = ValueNotifier(null);

  static ValueNotifier<Locale> appLocale = ValueNotifier(Locale('en'));

  static ValueNotifier<int> secondsCounted = ValueNotifier(0);

  static ValueNotifier<Shrine> currentShrine = ValueNotifier(defaultShrine);
}
