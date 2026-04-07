import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/theme.dart';
import '../features/onboarding/splash_screen.dart';

class AksaApp extends StatelessWidget {
  const AksaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AksaColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'AKSA',
        debugShowCheckedModeBanner: false,
        theme: buildAksaTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}