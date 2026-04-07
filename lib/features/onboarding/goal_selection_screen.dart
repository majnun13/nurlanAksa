import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../data/repositories/profile_repository.dart';
import 'wearable_connect_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  String _selectedGoal = '';
  bool _loading = false;
  final _profileRepo = ProfileRepository();
  final List<String> _selectedSecondaryGoals = [];

  static const _goals = [
    {
      'id': 'lose_weight',
      'title': 'Kilo Ver',
      'desc': 'Yağ oranını azalt, sağlıklı kiloya ulaş',
      'emoji': '📉',
      'gradient': [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      'details': [
        'Kalori açığı planı',
        'Yüksek protein, düşük karbonhidrat',
        'Kardiyo odaklı egzersiz',
      ],
    },
    {
      'id': 'maintain',
      'title': 'Kilo Koru',
      'desc': 'Mevcut kiloyu dengede tutarak sağlığını optimize et',
      'emoji': '⚖️',
      'gradient': [Color(0xFF06B6D4), Color(0xFF0891B2)],
      'details': [
        'Dengeli beslenme planı',
        'Karma aktivite önerileri',
        'Genel sağlık optimizasyonu',
      ],
    },
    {
      'id': 'gain_weight',
      'title': 'Kilo Al',
      'desc': 'Kas kütlesi ve sağlıklı ağırlık kazanımı',
      'emoji': '📈',
      'gradient': [Color(0xFF10B981), Color(0xFF059669)],
      'details': [
        'Kalori fazlası planı',
        'Yüksek protein takviyesi',
        'Direnç ve kuvvet antrenmanı',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Sağlık Hedefi',
        subtitle: 'Kişisel hedefinizi belirleyin',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                // ── Header info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AksaColors.primary.withOpacity(0.1),
                        AksaColors.secondary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AksaColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Text('🎯', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hedef Seçimi',
                                style: TextStyle(
                                    color: AksaColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            SizedBox(height: 2),
                            Text(
                              'Seçiminiz tüm AI tavsiye ve analizlerini kişiselleştirir.',
                              style: TextStyle(
                                  color: AksaColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Goal cards
                ..._goals.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _GoalCard(
                        goal: g,
                        isSelected: _selectedGoal == g['id'],
                        onTap: () =>
                            setState(() => _selectedGoal = g['id'] as String),
                      ),
                    )),

                const SizedBox(height: 8),

                // ── Secondary goals
                _buildSecondaryGoals(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: Column(
              children: [
                if (_selectedGoal.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Devam etmek için bir hedef seçin',
                      style: TextStyle(
                          color: AksaColors.textMuted, fontSize: 13),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _selectedGoal.isNotEmpty
                          ? AksaColors.gradPrimary
                          : null,
                      color: _selectedGoal.isEmpty
                          ? AksaColors.surfaceCard
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _selectedGoal.isNotEmpty
                          ? [
                              BoxShadow(
                                color: AksaColors.primary.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: FilledButton.icon(
                      onPressed: _selectedGoal.isNotEmpty ? _proceed : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white),
                      label: Text(
                        _loading ? 'Kaydediliyor…' : 'Devam Et',
                        style: TextStyle(
                          color: _selectedGoal.isNotEmpty
                              ? Colors.white
                              : AksaColors.textMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _proceed() async {
    setState(() => _loading = true);
    try {
      // Hedefi API'ye UPSERT ile kaydet
      await _profileRepo.saveHealthProfile(healthGoal: _selectedGoal);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WearableConnectScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AksaColors.riskHigh,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSecondaryGoals() {
    final secondary = [
      '😴 Daha iyi uyku',
      '❤️ Kalp sağlığı',
      '💪 Daha fit görünüm',
      '🧠 Zihinsel sağlık',
      '⚡ Enerji artışı',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AksaColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('İkincil Hedefler (İsteğe Bağlı)',
              style: TextStyle(
                  color: AksaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondary.map((s) {
              final sel = _selectedSecondaryGoals.contains(s);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _selectedSecondaryGoals.remove(s);
                  } else {
                    _selectedSecondaryGoals.add(s);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? AksaColors.primary.withOpacity(0.15)
                        : AksaColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AksaColors.primary
                          : const Color(0xFF334155),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sel) ...[
                        const Icon(Icons.check_circle_rounded,
                            color: AksaColors.primaryLight, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(s,
                          style: TextStyle(
                            color: sel
                                ? AksaColors.primaryLight
                                : AksaColors.textSecondary,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Goal Card
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> goal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradColors = (goal['gradient'] as List).cast<Color>();
    final details = (goal['details'] as List).cast<String>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: gradColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [AksaColors.surfaceCard, AksaColors.surfaceCard],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFF1E293B),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradColors.first.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(goal['emoji'] as String,
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal['title'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AksaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          goal['desc'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : AksaColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18),
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2), height: 1),
                const SizedBox(height: 12),
                ...details.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(d,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
