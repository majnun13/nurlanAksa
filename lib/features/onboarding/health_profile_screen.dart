import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../data/repositories/profile_repository.dart';
import 'goal_selection_screen.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  // Form controllers
  final _weightCtrl = TextEditingController(text: '78');
  final _heightCtrl = TextEditingController(text: '178');
  final _ageCtrl = TextEditingController(text: '27');
  final _medicationCtrl = TextEditingController();

  String _selectedGender = 'Erkek';
  String _selectedLifestyle = 'Orta';
  final List<String> _selectedDiet = [];
  final List<String> _selectedConditions = [];
  final List<String> _customConditions = [];

  static const _genders = ['Erkek', 'Kadın', 'Belirtmek İstemiyorum'];
  static const _lifestyles = ['Sedanter', 'Orta', 'Aktif'];
  static const _dietOptions = [
    'Vejetaryen',
    'Vegan',
    'Glutensiz',
    'Laktozsuz',
    'Fındık Alerjisi',
    'Diyabetik',
  ];
  static const _conditions = [
    'Hipertansiyon',
    'Diyabet',
    'Kalp Hastalığı',
    'Astım',
    'Böbrek Hastalığı',
    'Tiroid',
  ];

  int _step = 0;
  bool _loading = false;
  final _pageCtrl = PageController();
  final _profileRepo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    // VKİ anında güncellenmesi için listener'lar
    _weightCtrl.addListener(_onBMIFieldChanged);
    _heightCtrl.addListener(_onBMIFieldChanged);
  }

  void _onBMIFieldChanged() {
    setState(() {}); // VKİ widget'ını rebuild eder
  }

  void _nextStep() async {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // 3. adımdaysak API'ye kaydet
      setState(() => _loading = true);
      try {
        final allConditions = [..._selectedConditions, ..._customConditions];
        await _profileRepo.saveHealthProfile(
          age: int.tryParse(_ageCtrl.text),
          weightKg: double.tryParse(_weightCtrl.text),
          heightCm: double.tryParse(_heightCtrl.text),
          gender: _selectedGender,
          lifestyle: _selectedLifestyle,
          dietaryRestrictions: _selectedDiet,
          medicalConditions: allConditions,
          medications: _medicationCtrl.text.trim(),
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const GoalSelectionScreen(),
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
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_onBMIFieldChanged);
    _heightCtrl.removeListener(_onBMIFieldChanged);
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _medicationCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Temel Bilgiler', 'Yaşam Tarzı', 'Sağlık Geçmişi'];

    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'Sağlık Profili',
        subtitle: 'Adım ${_step + 1} / ${steps.length}',
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AksaColors.textPrimary),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: List.generate(steps.length, (i) {
                final active = i == _step;
                final done = i < _step;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: done || active ? AksaColors.gradPrimary : null,
                        color: done || active ? null : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          // ── Step labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: steps.asMap().entries.map((e) {
                final active = e.key == _step;
                return Text(
                  e.value,
                  style: TextStyle(
                    color: active ? AksaColors.primaryLight : AksaColors.textMuted,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Pages
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoPage(),
                _buildLifestylePage(),
                _buildHealthHistoryPage(),
              ],
            ),
          ),

          // ── Next button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: _buildNextButton(),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Basic Info
  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Fiziksel Bilgiler',
            icon: Icons.monitor_weight_outlined,
            color: AksaColors.primary,
            child: Column(
              children: [
                // Age
                _ProfileField(
                  label: 'Yaş',
                  controller: _ageCtrl,
                  unit: 'yıl',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  icon: Icons.cake_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Height
                    Expanded(
                      child: _ProfileField(
                        label: 'Boy',
                        controller: _heightCtrl,
                        unit: 'cm',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        icon: Icons.height_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Weight
                    Expanded(
                      child: _ProfileField(
                        label: 'Kilo',
                        controller: _weightCtrl,
                        unit: 'kg',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // BMI indicator
                _buildBMICard(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Cinsiyet',
            icon: Icons.person_outline,
            color: AksaColors.secondary,
            child: Row(
              children: _genders.map((g) {
                final sel = g == _selectedGender;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AksaColors.primary.withOpacity(0.2)
                              : AksaColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AksaColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel
                                ? AksaColors.primaryLight
                                : AksaColors.textMuted,
                            fontSize: 12,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMICard() {
    final h = double.tryParse(_heightCtrl.text) ?? 178;
    final w = double.tryParse(_weightCtrl.text) ?? 78;
    final bmi = w / ((h / 100) * (h / 100));
    final bmiStr = bmi.toStringAsFixed(1);
    final label = bmi < 18.5
        ? 'Zayıf'
        : bmi < 25
            ? 'Normal'
            : bmi < 30
                ? 'Fazla Kilolu'
                : 'Obez';
    final color = bmi < 18.5
        ? AksaColors.riskMedium
        : bmi < 25
            ? AksaColors.riskLow
            : bmi < 30
                ? AksaColors.riskMedium
                : AksaColors.riskHigh;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, size: 18, color: AksaColors.textMuted),
          const SizedBox(width: 10),
          Text('VKİ (BMI): ',
              style: const TextStyle(color: AksaColors.textSecondary, fontSize: 13)),
          Text(bmiStr,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(width: 6),
          Text('• $label',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Page 2: Lifestyle
  Widget _buildLifestylePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Yaşam Tarzı Seviyesi',
            icon: Icons.directions_walk_outlined,
            color: AksaColors.accent,
            child: Column(
              children: _lifestyles.map((l) {
                final sel = l == _selectedLifestyle;
                final icons = {
                  'Sedanter': '🪑',
                  'Orta': '🚶',
                  'Aktif': '🏃',
                };
                final descs = {
                  'Sedanter':
                      'Çoğunlukla masa başı, düzenli egzersiz yok',
                  'Orta':
                      'Haftada 2-4 kez orta şiddette aktivite',
                  'Aktif':
                      'Neredeyse her gün düzenli ve yoğun aktivite',
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedLifestyle = l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sel
                            ? AksaColors.accent.withOpacity(0.12)
                            : AksaColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel
                              ? AksaColors.accent
                              : const Color(0xFF334155),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(icons[l]!,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l,
                                    style: TextStyle(
                                      color: sel
                                          ? AksaColors.accent
                                          : AksaColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    )),
                                Text(descs[l]!,
                                    style: const TextStyle(
                                      color: AksaColors.textMuted,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                                color: AksaColors.accent, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Diyet Kısıtlamaları',
            icon: Icons.restaurant_outlined,
            color: AksaColors.riskMedium,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dietOptions.map((d) {
                final sel = _selectedDiet.contains(d);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) _selectedDiet.remove(d);
                    else _selectedDiet.add(d);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AksaColors.riskMedium.withOpacity(0.15)
                          : AksaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? AksaColors.riskMedium
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sel) ...[
                          const Icon(Icons.check,
                              color: AksaColors.riskMedium, size: 14),
                          const SizedBox(width: 4),
                        ],
                        Text(d,
                            style: TextStyle(
                              color: sel
                                  ? AksaColors.riskMedium
                                  : AksaColors.textSecondary,
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Health History
  Widget _buildHealthHistoryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AksaColors.riskMedium.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AksaColors.riskMedium.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AksaColors.riskMedium, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu bilgiler yalnızca AI analizinizi kişiselleştirmek için kullanılır. '
                    'Tıbbi tanı veya tedavi amaçlı değildir.',
                    style: TextStyle(
                        color: AksaColors.textMuted,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Kronik Hastalıklar',
            icon: Icons.medical_services_outlined,
            color: AksaColors.riskHigh,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._conditions.map((c) {
                      final sel = _selectedConditions.contains(c);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) _selectedConditions.remove(c);
                          else _selectedConditions.add(c);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AksaColors.riskHigh.withOpacity(0.1)
                                : AksaColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AksaColors.riskHigh
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(Icons.check,
                                    color: AksaColors.riskHigh, size: 14),
                                const SizedBox(width: 4),
                              ],
                              Text(c,
                                  style: TextStyle(
                                    color: sel
                                        ? AksaColors.riskHigh
                                        : AksaColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Kullanıcının eklediği özel hastalıklar
                    ..._customConditions.map((c) {
                      return GestureDetector(
                        onTap: () => setState(() => _customConditions.remove(c)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AksaColors.riskHigh.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AksaColors.riskHigh),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close,
                                  color: AksaColors.riskHigh, size: 14),
                              const SizedBox(width: 4),
                              Text(c,
                                  style: const TextStyle(
                                    color: AksaColors.riskHigh,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showAddConditionDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Diğer Ekle',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'İlaç Kullanımı',
            icon: Icons.medication_outlined,
            color: AksaColors.riskMedium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _medicationCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Kullandığınız ilaçları yazın (isteğe bağlı)',
                    prefixIcon: Icon(Icons.medication_outlined,
                        color: AksaColors.textMuted, size: 20),
                  ),
                  style: const TextStyle(color: AksaColors.textPrimary),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AksaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: AksaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _showAddConditionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AksaColors.surface,
        title: const Text('Hastalık Ekle',
            style: TextStyle(color: AksaColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: AksaColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Hastalık adını yazın',
          ),
          onSubmitted: (_) {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              setState(() => _customConditions.add(text));
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _customConditions.add(text));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _step == 2;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AksaColors.gradPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AksaColors.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: _loading ? null : _nextStep,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
          label: Text(
            isLast ? 'Tamamla ve Devam Et' : 'Sonraki Adım',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Profile number field
class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.unit,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String unit;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AksaColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: AksaColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AksaColors.textMuted, size: 18),
            suffixText: unit,
            suffixStyle: const TextStyle(
                color: AksaColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
