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

class ExerciseModel {
  final RationaleData rationale;
  final List<ExerciseRecommendation> recommendations;
  final HRZoneData hrZone;
  final List<WeeklyPlanItem> weeklyPlan;
  final List<double> heartRateHourly;

  ExerciseModel({
    required this.rationale,
    required this.recommendations,
    required this.hrZone,
    required this.weeklyPlan,
    required this.heartRateHourly,
  });

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
    );
  }
}
