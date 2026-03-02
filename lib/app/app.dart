import 'package:flutter/material.dart';
import 'theme.dart';
import '../features/shell/shell_screen.dart';

class AksaApp extends StatelessWidget {
  const AksaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AKSA',
      debugShowCheckedModeBanner: false,
      theme: buildAksaTheme(),
      home: const ShellScreen(),
    );
  }
}