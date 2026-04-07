import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/health_profile_model.dart';
import '../../core/network/api_client.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _anomalyAlerts = true;
  bool _weeklyReport = false;
  bool _googleFitConnected = false;
  bool _healthKitConnected = false;

  final _profileRepo = ProfileRepository();
  HealthProfileModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
                          onTap: () {},
                          showDivider: true,
                        ),
                        _MenuTile(
                          icon: Icons.security_outlined,
                          color: AksaColors.accent,
                          title: 'Güvenlik',
                          onTap: () {},
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
                          onTap: () {},
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
    final name = p != null ? 'Kullanıcı' : 'Yükleniyor...';
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
                  p?.gender != null ? '${p!.gender}' : name,
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
          lastSync: _googleFitConnected ? 'Son sync: 2 dk önce' : 'Bağlı değil',
          onToggle: () =>
              setState(() => _googleFitConnected = !_googleFitConnected),
        ),
        const SizedBox(height: 10),
        _WearableTile(
          logo: '⬜',
          name: 'Apple HealthKit',
          status: _healthKitConnected ? 'Bağlı' : 'Bağlı Değil',
          isConnected: _healthKitConnected,
          lastSync: _healthKitConnected ? 'Son sync: 5 dk önce' : 'Bağlı değil',
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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AksaColors.surface,
        title: const Text('Verileri Sil',
            style: TextStyle(color: AksaColors.textPrimary)),
        content: const Text(
          'Tüm sağlık verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: AksaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
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