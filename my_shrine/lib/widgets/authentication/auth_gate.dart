import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/views/authentication/sign_in_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInPage();
        } else {
          // Only update the notifier when the value actually changes to avoid
          // triggering unnecessary rebuilds.
          final user = snapshot.data!;
          if (StateNotifiers.user.value?.uid != user.uid) {
            // Schedule the state mutation for after the current build frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              StateNotifiers.user.value = user;
            });
          }
          return page;
        }
      },
    );
  }
}
