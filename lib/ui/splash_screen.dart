import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xff090d25),
    body: SizedBox.expand(
      child: Image(
        image: AssetImage('assets/images/splash_screen.png'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    ),
  );
}
