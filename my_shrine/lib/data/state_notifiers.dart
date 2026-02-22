import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

class StateNotifiers {
  static ValueNotifier<bool> isLightMode = ValueNotifier(true);

  static ValueNotifier<User?> user = ValueNotifier(null);

  static ValueNotifier<Locale> appLocale = ValueNotifier(Locale('en'));

  static ValueNotifier<int> seccondsCounted = ValueNotifier(0);
}
