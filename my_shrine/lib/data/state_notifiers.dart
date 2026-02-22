import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;

class StateNotifiers {
  static ValueNotifier<bool> isLightMode = ValueNotifier(true);
  static ValueNotifier<int> commonNavigationIndex = ValueNotifier(0);

  static ValueNotifier<User?> user = ValueNotifier(null);

  static ValueNotifier<Locale> appLocale = ValueNotifier(Locale('en'));

  static ValueNotifier<String> currentPage = ValueNotifier('/');

  static ValueNotifier<bool> showHACredentialsBanner = ValueNotifier(true);

}