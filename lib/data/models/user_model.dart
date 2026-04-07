// ─────────────────────────────────────────────────────────────
//  UserModel – users tablosuna karşılık gelen Dart modeli
// ─────────────────────────────────────────────────────────────

class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isEmailVerified,
    required this.onboardingDone,
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
    this.oauthProvider,
  });

  final String id;
  final String fullName;
  final String email;
  final bool isActive;
  final bool isEmailVerified;
  final bool onboardingDone;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final String? oauthProvider;

  /// API JSON yanıtından UserModel oluşturur (FastAPI response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      onboardingDone: json['onboarding_done'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      oauthProvider: json['oauth_provider'] as String?,
    );
  }

  /// PostgreSQL satırından UserModel oluşturur (eski, kaldırılacak)
  factory UserModel.fromRow(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'].toString(),
      fullName: row['full_name'] as String,
      email: row['email'] as String,
      isEmailVerified: row['is_email_verified'] as bool? ?? false,
      onboardingDone: row['onboarding_done'] as bool? ?? false,
      isActive: row['is_active'] as bool? ?? true,
      oauthProvider: row['oauth_provider'] as String?,
    );
  }

  /// Kolaylık sağlamak için copyWith
  UserModel copyWith({
    bool? onboardingDone,
    bool? isEmailVerified,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      fullName: fullName,
      email: email,
      isActive: isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      oauthProvider: oauthProvider,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, fullName: $fullName)';
}
