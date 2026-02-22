import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_shrine/data/app_styles.dart';


class SignInWidget extends StatelessWidget {
  const SignInWidget({super.key});

  @override
  Widget build(BuildContext context){
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed:() => googleSignIn(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/google_sign_in_logo.png',
                  width:AppStyles.generalIconImageSize
                ),
                SizedBox(width: AppStyles.inButtonSeparatorWidth),
                Text("Sign In"), 
              ],
            )
          ),
        ]
      )
    );
  }

  Future<void> googleSignIn() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: "806995303188-rilgbp41snb3gmm9tngf4adhr5k8fohh.apps.googleusercontent.com");
    await googleSignIn.authenticate();
  }

}
