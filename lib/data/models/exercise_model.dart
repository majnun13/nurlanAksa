class RationaleTag {
  final String label;

  RationaleTag({required this.label});

  factory RationaleTag.fromJson(Map<String, dynamic> json) {
    return RationaleTag(
      label: json['label'] ?? '',
    );
  }
}

class RationaleData {
  final String title;
  final String description;
  final List<RationaleTag> tags;

  RationaleData({
    required this.title,
    required this.description,
    required this.tags,
  });

  factory RationaleData.fromJson(Map<String, dynamic> json) {
    return RationaleData(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      tags: (json['tags'] as List?)
              ?.map((t) => RationaleTag.fromJson(t))
              .toList() ??
          [],
    );
  }
}

class ExerciseRecommendation {
  final String icon;
  final String type;
  final String duration;
  final String intensity;
  final String desc;
  final int color;

  ExerciseRecommendation({
    required this.icon,
    required this.type,
    required this.duration,
    required this.intensity,
    required this.desc,
    required this.color,
  });

  factory ExerciseRecommendation.fromJson(Map<String, dynamic> json) {
    return ExerciseRecommendation(
      icon: json['icon'] ?? '',
      type: json['type'] ?? '',
      duration: json['duration'] ?? '',
      intensity: json['intensity'] ?? '',
      desc: json['desc'] ?? '',
      color: json['color'] ?? 0xFF000000,
    );
  }
  ExerciseRecommendation copyWith({
    String? icon,
    String? type,
    String? duration,
    String? intensity,
    String? desc,
    int? color,
  }) {
    return ExerciseRecommendation(
      icon:      icon      ?? this.icon,
      type:      type      ?? this.type,
      duration:  duration  ?? this.duration,
      intensity: intensity ?? this.intensity,
      desc:      desc      ?? this.desc,
      color:     color     ?? this.color,
    );
  }
}

class HRZoneData {
  final int minHr;
  final int targetHr;
  final int maxHr;

  HRZoneData({
    required this.minHr,
    required this.targetHr,
    required this.maxHr,
  });

  factory HRZoneData.fromJson(Map<String, dynamic> json) {
    return HRZoneData(
      minHr: json['min_hr'] ?? 0,
      targetHr: json['target_hr'] ?? 0,
      maxHr: json['max_hr'] ?? 0,
    );
  }
}

class WeeklyPlanItem {
  final String day;
  final String activity;
  final bool done;

  WeeklyPlanItem({
    required this.day,
    required this.activity,
    required this.done,
  });

  factory WeeklyPlanItem.fromJson(Map<String, dynamic> json) {
    return WeeklyPlanItem(
      day: json['day'] ?? '',
      activity: json['activity'] ?? '',
      done: json['done'] ?? false,
    );
  }
}

class WeeklyStats {
  final int totalActiveMinutes;
  final int totalCalories;
  final int workoutsDone;
  final int streakDays;

  WeeklyStats({
    required this.totalActiveMinutes,
    required this.totalCalories,
    required this.workoutsDone,
    this.streakDays = 0,
  });

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStats(
      totalActiveMinutes: json['total_active_minutes'] ?? 0,
      totalCalories:      json['total_calories']       ?? 0,
      workoutsDone:       json['workouts_done']        ?? 0,
      streakDays:         json['streak_days']          ?? 0,
    );
  }
}

class ExerciseModel {
  final RationaleData rationale;
  final List<ExerciseRecommendation> recommendations;
  final HRZoneData hrZone;
  final List<WeeklyPlanItem> weeklyPlan;
  final List<double> heartRateHourly;
  final int recoveryScore;
  final WeeklyStats weeklyStats;

  ExerciseModel({
    required this.rationale,
    required this.recommendations,
    required this.hrZone,
    required this.weeklyPlan,
    required this.heartRateHourly,
    this.recoveryScore = 65,
    WeeklyStats? weeklyStats,
  }) : weeklyStats = weeklyStats ??
            WeeklyStats(totalActiveMinutes: 0, totalCalories: 0, workoutsDone: 0);

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      rationale: RationaleData.fromJson(json['rationale'] ?? {}),
      recommendations: (json['recommendations'] as List?)
              ?.map((r) => ExerciseRecommendation.fromJson(r))
              .toList() ??
          [],
      hrZone: HRZoneData.fromJson(json['hr_zone'] ?? {}),
      weeklyPlan: (json['weekly_plan'] as List?)
              ?.map((p) => WeeklyPlanItem.fromJson(p))
              .toList() ??
          [],
      heartRateHourly: (json['heart_rate_hourly'] as List?)
              ?.map((h) => (h as num).toDouble())
              .toList() ??
          [],
      recoveryScore: json['recovery_score'] ?? 65,
      weeklyStats: json['weekly_stats'] != null
          ? WeeklyStats.fromJson(json['weekly_stats'])
          : null,
    );
  }
}
