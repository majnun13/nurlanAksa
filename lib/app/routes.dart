import 'package:flutter/material.dart';
import '../features/shell/shell_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/exercise/exercise_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  static const String home = "/";
  static const String dashboard = "/dashboard";
  static const String insights = "/insights";
  static const String nutrition = "/nutrition";
  static const String exercise = "/exercise";
  static const String settings = "/settings";

  static Map<String, WidgetBuilder> routes = {
    home: (context) => const ShellScreen(),
    dashboard: (context) => const DashboardScreen(),
    insights: (context) => const InsightsScreen(),
    nutrition: (context) => const NutritionScreen(),
    exercise: (context) => const ExerciseScreen(),
    settings: (context) => const SettingsScreen(),
  };
}