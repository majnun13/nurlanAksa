import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../insights/insights_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../exercise/exercise_screen.dart';
import '../settings/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    InsightsScreen(),
    NutritionScreen(),
    ExerciseScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Özet'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), label: 'Detay'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'Beslenme'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), label: 'Egzersiz'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ayarlar'),
        ],
      ),
    );
  }
}