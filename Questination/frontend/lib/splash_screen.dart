import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const oceanBlue = Color(0xFF1684A7);
    const tealGreen = Color(0xFF0EA391);
    const sunnyYellow = Color(0xFFFAF179);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
         Image.asset(
  'assets/logo.png',
  width: 120,
  height: 120,
  fit: BoxFit.contain,
),
            const SizedBox(height: 10),
            Text(
              'EXPLORE INDIA IN PIXELS',
              style: GoogleFonts.pressStart2p(fontSize: 8, color: tealGreen),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: tealGreen,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
