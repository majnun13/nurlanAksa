import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/health_profile_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/login_screen.dart';
import 'legal_screens.dart';
import 'edit_profile_screen.dart';
import '../../core/network/api_client.dart';
import '../../core/services/wearable_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _anomalyAlerts = true;
  bool _weeklyReport = false;
  bool _googleFitConnected = false;
  bool _healthKitConnected = false;

  final _profileRepo = ProfileRepository();
  HealthProfileModel? _profile;
  bool _isLoading = true;

  String _userName = 'Kullanıcı';
  String _lastSyncLabel = 'Bağlı değil';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSyncStatus();
    ApiClient.getUserName().then((val) {
      if (val != null && mounted) {
        setState(() => _userName = val);
      }
    });
  }

  Future<void> _loadSyncStatus() async {
    // iOS'ta hasPermissions() her zaman null döndürür (Apple gizlilik kuralı).
    // Bunun yerine son sync zamanını kontrol ederek bağlı olup olmadığına karar veririz.
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_wearable_sync');
    final isConnected = lastSync != null; // en az bir kez sync olduysa bağlı sayılır
    final label = await WearableSyncService.getLastSyncLabel();
    if (mounted) {
      setState(() {
        _healthKitConnected = isConnected;
        _lastSyncLabel = isConnected ? label : 'Bağlı değil';
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepo.getHealthProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ShellScreen'den sekme değişikliğinde çağrılır
  void refreshProfile() {
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Profil & Ayarlar',
        subtitle: 'Hesap ve tercihler',
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AksaColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ── Profile Card
                const SectionHeader('Profil'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildProfileCard(context),
                ),

                // ── BMI Card
                if (_profile != null && _profile!.weightKg != null && _profile!.heightCm != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildBMICard(context),
                  ),

                // ── Health Details
                if (_profile != null) ...[
                  const SectionHeader('Sağlık Bilgileri',
                      subtitle: 'Kayıtlı profil verileri'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHealthDetailsCard(context),
                  ),
                ],

                // ── Wearable Connections
                const SectionHeader('Giyilebilir Cihaz Bağlantıları',
                    subtitle: 'Sağlık verisi platformları'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildWearableSection(context),
                ),

                // ── Notifications
                const SectionHeader('Bildirimler'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AksaCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        _SwitchTile(
                          icon: Icons.notifications_outlined,
                          color: AksaColors.primary,
                          title: 'Bildirimler',
                          subtitle: 'Genel uygulama bildirimleri',
                          value: _notifications,
                          onChanged: (v) => setState(() => _notifications = v),
                          showDivider: true,
                        ),
                        _SwitchTile(
                          icon: Icons.warning_amber_outlined,
                          color: AksaColors.riskHigh,
                          title: 'Anomali Uyarıları',
                          subtitle: 'Anormal veri tespitinde anında bildir',
                          value: _anomalyAlerts,
                          onChanged: (v) => setState(() => _anomalyAlerts = v),
                          showDivider: true,
                        ),
                        _SwitchTile(
                          icon: Icons.summarize_outlined,
                          color: AksaColors.accent,
                          title: 'Haftalık Rapor',
                          subtitle: 'Her Pazar haftalık özet e-postası',
                          value: _weeklyReport,
                          onChanged: (v) => setState(() => _weeklyReport = v),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Health Goal
                const SectionHeader('Sağlık Hedefi'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGoalSection(context),
                ),

                // ── Account
                const SectionHeader('Hesap'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AksaCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        _MenuTile(
                          icon: Icons.privacy_tip_outlined,
                          color: AksaColors.secondary,
                          title: 'Gizlilik & Veri',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                          showDivider: true,
                        ),
                        _MenuTile(
                          icon: Icons.security_outlined,
                          color: AksaColors.accent,
                          title: 'Güvenlik',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
                          showDivider: true,
                        ),
                        _MenuTile(
                          icon: Icons.delete_outline,
                          color: AksaColors.riskHigh,
                          title: 'Verilerimi Sil',
                          subtitle: 'Tüm sağlık verilerini kalıcı sil',
                          onTap: () => _showDeleteConfirm(context),
                          showDivider: true,
                        ),
                        _MenuTile(
                          icon: Icons.logout_rounded,
                          color: AksaColors.riskMedium,
                          title: 'Çıkış Yap',
                          onTap: () => _showLogoutConfirm(context),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── App info
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AksaColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('AKSA v1.0.0',
                            style: TextStyle(
                                color: AksaColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),
                      const Text('Akıllı Kişisel Sağlık Asistanı',
                          style: TextStyle(
                              color: AksaColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final p = _profile;
    final name = _userName;
    final ageStr = p?.age != null ? '${p!.age} yaş' : '-- yaş';
    final weightStr = p?.weightKg != null ? '${p!.weightKg!.toStringAsFixed(0)} kg' : '-- kg';
    final heightStr = p?.heightCm != null ? '${p!.heightCm!.toStringAsFixed(0)} cm' : '-- cm';
    final goalStr = p?.healthGoalLabel ?? 'Belirtilmedi';
    final lifestyleStr = p?.lifestyle ?? '--';

    return GradientCard(
      gradient: AksaColors.gradPrimary,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ageStr  •  $weightStr  •  $heightStr',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '🎯 $goalStr  •  $lifestyleStr yaşam tarzı',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              if (p == null) return;
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(currentProfile: p)),
              );
              if (changed == true) {
                if (mounted) _loadProfile();
              }
            },
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDetailsCard(BuildContext context) {
    final p = _profile!;
    return AksaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hastalıklar ──
          const Row(
            children: [
              Icon(Icons.medical_services_outlined, color: AksaColors.riskHigh, size: 16),
              SizedBox(width: 8),
              Text('Kronik Hastalıklar', style: TextStyle(color: AksaColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (p.medicalConditions.isNotEmpty)
            Wrap(
              spacing: 6, runSpacing: 6,
              children: p.medicalConditions.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AksaColors.riskHigh.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(c, style: const TextStyle(color: AksaColors.riskHigh, fontSize: 11)),
              )).toList(),
            )
          else
            const Text('Yok (Eklemek için düzenleyin)', style: TextStyle(color: AksaColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
          const Divider(height: 24),

          // ── Diyet Kısıtlamaları ──
          const Row(
            children: [
              Icon(Icons.restaurant_outlined, color: AksaColors.riskMedium, size: 16),
              SizedBox(width: 8),
              Text('Diyet Kısıtlamaları', style: TextStyle(color: AksaColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (p.dietaryRestrictions.isNotEmpty)
            Wrap(
              spacing: 6, runSpacing: 6,
              children: p.dietaryRestrictions.map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AksaColors.riskMedium.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(d, style: const TextStyle(color: AksaColors.riskMedium, fontSize: 11)),
              )).toList(),
            )
          else
            const Text('Yok', style: TextStyle(color: AksaColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
          const Divider(height: 24),

          // ── İlaç Kullanımı ──
          const Row(
            children: [
              Icon(Icons.medication_outlined, color: AksaColors.accent, size: 16),
              SizedBox(width: 8),
              Text('İlaç Kullanımı', style: TextStyle(color: AksaColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (p.medications != null && p.medications!.trim().isNotEmpty)
            Text(p.medications!, style: const TextStyle(color: AksaColors.textPrimary, fontSize: 13))
          else
            const Text('Düzenli kullanılan ilaç kaydı yok', style: TextStyle(color: AksaColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildWearableSection(BuildContext context) {
    return Column(
      children: [
        _WearableTile(
          logo: '🟢',
          name: 'Google Fit',
          status: _googleFitConnected ? 'Bağlı' : 'Bağlı Değil',
          isConnected: _googleFitConnected,
          lastSync: _googleFitConnected ? _lastSyncLabel : 'Bağlı değil',
          onToggle: () =>
              setState(() => _googleFitConnected = !_googleFitConnected),
        ),
        const SizedBox(height: 10),
        _WearableTile(
          logo: '⬜',
          name: 'Apple HealthKit',
          status: _healthKitConnected ? 'Bağlı' : 'Bağlı Değil',
          isConnected: _healthKitConnected,
          lastSync: _healthKitConnected ? _lastSyncLabel : 'Bağlı değil',
          onToggle: () =>
              setState(() => _healthKitConnected = !_healthKitConnected),
        ),
      ],
    );
  }

  Widget _buildGoalSection(BuildContext context) {
    final currentGoal = _profile?.healthGoal ?? 'maintain';
    final goals = [
      {'label': 'Kilo Ver', 'icon': '📉', 'id': 'lose_weight'},
      {'label': 'Kilo Koru', 'icon': '⚖️', 'id': 'maintain'},
      {'label': 'Kilo Al', 'icon': '📈', 'id': 'gain_weight'},
    ];

    return AksaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aktif Hedef',
              style: TextStyle(
                  color: AksaColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: goals.map((g) {
              final selected = g['id'] == currentGoal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AksaColors.primary.withOpacity(0.2)
                            : AksaColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AksaColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(g['icon'] as String,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 6),
                          Text(
                            g['label'] as String,
                            style: TextStyle(
                              color: selected
                                  ? AksaColors.primaryLight
                                  : AksaColors.textMuted,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBMICard(BuildContext context) {
    final w = _profile!.weightKg!;
    final h = _profile!.heightCm!;
    final bmi = w / ((h / 100) * (h / 100));
    final bmiStr = bmi.toStringAsFixed(1);

    String label;
    Color color;
    String emoji;
    String advice;

    if (bmi < 18.5) {
      label = 'Zayıf';
      color = AksaColors.riskMedium;
      emoji = '⚠️';
      advice = 'Kalori alımını artırmayı düşünebilirsiniz.';
    } else if (bmi < 25) {
      label = 'Normal';
      color = AksaColors.riskLow;
      emoji = '✅';
      advice = 'Kilonuz ideal aralıkta, korumaya devam edin!';
    } else if (bmi < 30) {
      label = 'Fazla Kilolu';
      color = AksaColors.riskMedium;
      emoji = '⚡';
      advice = 'Düzenli egzersiz ve dengeli beslenme önerilir.';
    } else {
      label = 'Obez';
      color = AksaColors.riskHigh;
      emoji = '🔴';
      advice = 'Bir uzmana başvurarak sağlık planı oluşturun.';
    }

    // BMI bar pozisyonu (15-40 aralığı üzerinden)
    final barProgress = ((bmi - 15) / 25).clamp(0.0, 1.0);

    return AksaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined, color: AksaColors.textSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Vücut Kitle İndeksi (VKİ)',
                  style: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),

          // Büyük değer ve durum
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(bmiStr,
                  style: TextStyle(color: color, fontSize: 42, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('kg/m²',
                    style: TextStyle(color: color.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Stack(
            children: [
              // Background gradient bar
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6), // Zayıf
                      Color(0xFF22C55E), // Normal
                      Color(0xFFF59E0B), // Fazla Kilolu
                      Color(0xFFEF4444), // Obez
                    ],
                    stops: [0.0, 0.38, 0.6, 1.0],
                  ),
                ),
              ),
              // Indicator
              Positioned(
                left: (MediaQuery.of(context).size.width - 64 - 32) * barProgress, // 64=padding, 32=insets
                top: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Range labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15', style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
              Text('18.5', style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
              Text('25', style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
              Text('30', style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
              Text('40', style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),

          // Öneri
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(advice,
                      style: const TextStyle(color: AksaColors.textSecondary, fontSize: 12, height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagCtx) => AlertDialog(
        backgroundColor: AksaColors.surface,
        title: const Text('Çıkış Yap', style: TextStyle(color: AksaColors.textPrimary)),
        content: const Text(
          'Oturumunuz sonlandırılacak. Çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: AksaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagCtx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(diagCtx);
              _logout();
            },
            style: FilledButton.styleFrom(backgroundColor: AksaColors.riskMedium),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagCtx) => AlertDialog(
        backgroundColor: AksaColors.surface,
        title: const Text('Verileri Sil', style: TextStyle(color: AksaColors.textPrimary)),
        content: const Text(
          'Tüm sağlık verileriniz ve hesabınız kalıcı olarak silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: AksaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagCtx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(diagCtx); // Dialogu kapat
              setState(() => _isLoading = true);
              try {
                await AuthRepository().deleteAccount();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: AksaColors.riskHigh,
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AksaColors.riskHigh),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// ── Wearable Tile
class _WearableTile extends StatelessWidget {
  const _WearableTile({
    required this.logo,
    required this.name,
    required this.status,
    required this.isConnected,
    required this.lastSync,
    required this.onToggle,
  });

  final String logo;
  final String name;
  final String status;
  final bool isConnected;
  final String lastSync;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(logo, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AksaColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AksaColors.riskLow
                            : AksaColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(status,
                        style: TextStyle(
                            color: isConnected
                                ? AksaColors.riskLow
                                : AksaColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                Text(lastSync,
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: isConnected
                  ? AksaColors.riskHigh.withOpacity(0.15)
                  : AksaColors.accent.withOpacity(0.15),
              foregroundColor:
                  isConnected ? AksaColors.riskHigh : AksaColors.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
            ),
            child: Text(
              isConnected ? 'Bağlantıyı Kes' : 'Bağlan',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Switch Tile
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.showDivider,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: AksaColors.textPrimary, fontSize: 14)),
          subtitle: subtitle != null
              ? Text(subtitle!,
                  style: const TextStyle(
                      color: AksaColors.textMuted, fontSize: 12))
              : null,
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AksaColors.primary,
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 56, endIndent: 16),
      ],
    );
  }
}

// ── Menu Tile
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    required this.showDivider,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: AksaColors.textPrimary, fontSize: 14)),
          subtitle: subtitle != null
              ? Text(subtitle!,
                  style: const TextStyle(
                      color: AksaColors.textMuted, fontSize: 12))
              : null,
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AksaColors.textMuted, size: 20),
        ),
        if (showDivider) const Divider(height: 1, indent: 56, endIndent: 16),
      ],
    );
  }
}