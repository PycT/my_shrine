import 'package:flutter/material.dart';
import 'package:my_shrine/widgets/authentication/sign_in_widget.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SignInWidget()),
    );
  }
}
