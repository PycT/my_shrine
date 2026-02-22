import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:my_shrine/data/state_notifiers.dart';
import 'package:my_shrine/views/authentication/sign_in_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.page
  });

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInPage();
        } else {
            StateNotifiers.user.value = snapshot.data!;
            return page;
        }
      },
    );
  }
}
