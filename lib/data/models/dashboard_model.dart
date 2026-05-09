class AnomalyData {
  final bool hasAnomaly;
  final String level;
  final String message;

  AnomalyData({
    required this.hasAnomaly,
    required this.level,
    required this.message,
  });

  factory AnomalyData.fromJson(Map<String, dynamic> json) {
    return AnomalyData(
      hasAnomaly: json['has_anomaly'] ?? false,
      level: json['level'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class RiskFactor {
  final String icon;
  final String name;

  RiskFactor({required this.icon, required this.name});

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      icon: json['icon'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class RiskData {
  final int score;
  final int trend;
  final String label;
  final List<RiskFactor> topFactors;

  RiskData({
    required this.score,
    required this.trend,
    required this.label,
    required this.topFactors,
  });

  factory RiskData.fromJson(Map<String, dynamic> json) {
    var factorsList = json['top_factors'] as List? ?? [];
    List<RiskFactor> factors =
        factorsList.map((i) => RiskFactor.fromJson(i)).toList();
    return RiskData(
      score: json['score'] ?? 0,
      trend: json['trend'] ?? 0,
      label: json['label'] ?? '',
      topFactors: factors,
    );
  }
}

class ActivityData {
  final int stepsToday;
  final int stepsGoal;
  final int caloriesBurned;
  final int caloriesGoal;
  final int activeMinutes;
  final int activeMinutesGoal;
  final double distanceKm;

  ActivityData({
    required this.stepsToday,
    required this.stepsGoal,
    required this.caloriesBurned,
    required this.caloriesGoal,
    required this.activeMinutes,
    required this.activeMinutesGoal,
    required this.distanceKm,
  });

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    return ActivityData(
      stepsToday: json['steps_today'] ?? 0,
      stepsGoal: json['steps_goal'] ?? 10000,
      caloriesBurned: json['calories_burned'] ?? 0,
      caloriesGoal: json['calories_goal'] ?? 500,
      activeMinutes: json['active_minutes'] ?? 0,
      activeMinutesGoal: json['active_minutes_goal'] ?? 30,
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
    );
  }
}

class SleepHeartData {
  final double sleepHours;
  final double sleepQuality;
  final int restingHr;
  final int avgHr;
  final String restingHrLabel;
  final String restingHrSeverity; // "good" | "warning" | "danger"

  SleepHeartData({
    required this.sleepHours,
    required this.sleepQuality,
    required this.restingHr,
    required this.avgHr,
    this.restingHrLabel = 'Normal',
    this.restingHrSeverity = 'good',
  });

  factory SleepHeartData.fromJson(Map<String, dynamic> json) {
    return SleepHeartData(
      sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
      sleepQuality: (json['sleep_quality'] ?? 0).toDouble(),
      restingHr: json['resting_hr'] ?? 0,
      avgHr: json['avg_hr'] ?? 0,
      restingHrLabel: json['resting_hr_label'] ?? 'Normal',
      restingHrSeverity: json['resting_hr_severity'] ?? 'good',
    );
  }
}

class WeeklyChartData {
  final List<String> days;
  final List<int> steps;

  WeeklyChartData({required this.days, required this.steps});

  factory WeeklyChartData.fromJson(Map<String, dynamic> json) {
    return WeeklyChartData(
      days: List<String>.from(json['days'] ?? []),
      steps: List<int>.from(json['steps'] ?? []),
    );
  }
}

class RecommendationItem {
  final String type;
  final String text;

  RecommendationItem({required this.type, required this.text});

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      type: json['type'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

class DashboardModel {
  final String userName;
  final AnomalyData anomaly;
  final RiskData risk;
  final ActivityData activity;
  final SleepHeartData sleepHeart;
  final WeeklyChartData weeklyChart;
  final List<RecommendationItem> recommendations;

  DashboardModel({
    required this.userName,
    required this.anomaly,
    required this.risk,
    required this.activity,
    required this.sleepHeart,
    required this.weeklyChart,
    required this.recommendations,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    var recsList = json['recommendations'] as List? ?? [];
    List<RecommendationItem> recs =
        recsList.map((i) => RecommendationItem.fromJson(i)).toList();

    return DashboardModel(
      userName: json['user_name'] ?? '',
      anomaly: AnomalyData.fromJson(json['anomaly'] ?? {}),
      risk: RiskData.fromJson(json['risk'] ?? {}),
      activity: ActivityData.fromJson(json['activity'] ?? {}),
      sleepHeart: SleepHeartData.fromJson(json['sleep_heart'] ?? {}),
      weeklyChart: WeeklyChartData.fromJson(json['weekly_chart'] ?? {}),
      recommendations: recs,
    );
  }
}
