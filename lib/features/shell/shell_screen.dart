import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../insights/insights_screen.dart';
import '../chat/chat_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../exercise/exercise_screen.dart';
import '../settings/settings_screen.dart';
import '../../app/theme.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => ShellScreenState();
}

// Public state class — DashboardScreen can access it via context
class ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  // NutritionScreen ve SettingsScreen'e erişim için GlobalKey
  final _nutritionKey = GlobalKey<NutritionScreenState>();
  final _settingsKey = GlobalKey<SettingsScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const InsightsScreen(),
      const ChatScreen(),
      NutritionScreen(key: _nutritionKey),
      const ExerciseScreen(),
      SettingsScreen(key: _settingsKey),
    ];
  }

  /// Dışarıdan çağrılabilir sekme değiştirici
  void switchToTab(int index) {
    setState(() => _index = index);
    if (index == 3) {
      _nutritionKey.currentState?.refreshTargets();
    }
    if (index == 5) {
      _settingsKey.currentState?.refreshProfile();
    }
  }

  void _onTabChanged(int newIndex) => switchToTab(newIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AksaColors.surfaceElevated, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AksaColors.surface,
          height: 65,
          selectedIndex: _index,
          onDestinationSelected: _onTabChanged,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Özet',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Risk',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'AI Asistan',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant_rounded),
              label: 'Beslenme',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center_rounded),
              label: 'Egzersiz',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}