// ─────────────────────────────────────────────────────────────
//  HealthProfileModel – health_profiles tablosunun Dart modeli
// ─────────────────────────────────────────────────────────────

class HealthProfileModel {
  const HealthProfileModel({
    required this.id,
    required this.userId,
    this.age,
    this.weightKg,
    this.heightCm,
    this.gender,
    this.lifestyle,
    this.healthGoal,
    this.dietaryRestrictions = const [],
    this.medicalConditions = const [],
    this.medications,
  });

  final String id;
  final String userId;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final String? gender;
  final String? lifestyle;
  final String? healthGoal;
  final List<String> dietaryRestrictions;
  final List<String> medicalConditions;
  final String? medications;

  factory HealthProfileModel.fromJson(Map<String, dynamic> json) {
    return HealthProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      age: json['age'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
      lifestyle: json['lifestyle'] as String?,
      healthGoal: json['health_goal'] as String?,
      dietaryRestrictions: List<String>.from(json['dietary_restrictions'] ?? []),
      medicalConditions: List<String>.from(json['medical_conditions'] ?? []),
      medications: json['medications'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'gender': gender,
        'lifestyle': lifestyle,
        'health_goal': healthGoal,
        'dietary_restrictions': dietaryRestrictions,
        'medical_conditions': medicalConditions,
        'medications': medications,
      };

  /// healthGoal'u Türkçe karşılığına çevirir
  String get healthGoalLabel {
    switch (healthGoal) {
      case 'lose_weight':
        return 'Kilo Ver';
      case 'maintain':
        return 'Kilo Koru';
      case 'gain_weight':
        return 'Kilo Al';
      default:
        return healthGoal ?? 'Belirtilmedi';
    }
  }
}
