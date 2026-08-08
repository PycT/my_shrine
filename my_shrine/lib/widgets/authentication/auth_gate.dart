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
          // Set the user synchronously so that helpers calling
          // requireUserId() have the value available immediately —
          // before the child page kicks off its preload futures.
          final user = snapshot.data!;
          if (StateNotifiers.user.value?.uid != user.uid) {
            StateNotifiers.user.value = user;
          }
          return page;
        }
      },
    );
  }
}
