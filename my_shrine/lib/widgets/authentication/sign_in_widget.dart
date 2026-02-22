import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_shrine/data/app_styles.dart';

class SignInWidget extends StatelessWidget {
  const SignInWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => googleSignIn(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/google_sign_in_logo.png',
                  width: AppStyles.generalIconImageSize,
                ),
                SizedBox(width: AppStyles.inButtonSeparatorWidth),
                Text("Sign In"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> googleSignIn() async {
    try {
      // Triggers the Google account chooser on Android.
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();

      // Exchange the Google idToken for a Firebase credential.
      // (In google_sign_in v7, accessToken moved to a separate authorizeScopes()
      // flow — for Firebase Auth only the idToken is needed.)
      final GoogleSignInAuthentication googleAuth =
          await account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // This is what actually signs the user into Firebase.
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
    }
  }
}
