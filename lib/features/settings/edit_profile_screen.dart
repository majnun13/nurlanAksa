import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../data/models/health_profile_model.dart';
import '../../data/repositories/profile_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final HealthProfileModel currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _medicationCtrl;

  late String _selectedGender;
  late String _selectedLifestyle;
  late String _selectedGoal;
  
  late List<String> _selectedDiet;
  late List<String> _selectedConditions;
  late List<String> _customConditions;

  bool _isSaving = false;
  final _profileRepo = ProfileRepository();

  static const _genders = ['Erkek', 'Kadın', 'Belirtmek İstemiyorum'];
  static const _lifestyles = ['Sedanter', 'Orta', 'Aktif'];
  static const _goals = [
    {'id': 'lose_weight', 'label': 'Kilo Ver'},
    {'id': 'maintain', 'label': 'Kilo Koru'},
    {'id': 'gain_weight', 'label': 'Kilo Al'},
  ];
  
  static const _dietOptions = [
    'Vejetaryen', 'Vegan', 'Glutensiz', 'Laktozsuz', 'Fındık Alerjisi', 'Diyabetik',
  ];
  static const _conditionsList = [
    'Hipertansiyon', 'Diyabet', 'Kalp Hastalığı', 'Astım', 'Böbrek Hastalığı', 'Tiroid',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    
    _weightCtrl = TextEditingController(text: p.weightKg?.toStringAsFixed(1) ?? '');
    _heightCtrl = TextEditingController(text: p.heightCm?.toStringAsFixed(0) ?? '');
    _ageCtrl = TextEditingController(text: p.age?.toString() ?? '');
    _medicationCtrl = TextEditingController(text: p.medications ?? '');

    _selectedGender = p.gender ?? 'Belirtmek İstemiyorum';
    _selectedLifestyle = p.lifestyle ?? 'Orta';
    _selectedGoal = p.healthGoal ?? 'maintain';

    _selectedDiet = List.from(p.dietaryRestrictions);
    
    // Varolan standart ve özel hastalıkları ayrıştır
    _selectedConditions = [];
    _customConditions = [];
    for (var c in p.medicalConditions) {
      if (_conditionsList.contains(c)) {
        _selectedConditions.add(c);
      } else {
        _customConditions.add(c);
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _medicationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final allConditions = [..._selectedConditions, ..._customConditions];
      await _profileRepo.saveHealthProfile(
        age: int.tryParse(_ageCtrl.text),
        weightKg: double.tryParse(_weightCtrl.text),
        heightCm: double.tryParse(_heightCtrl.text),
        gender: _selectedGender,
        lifestyle: _selectedLifestyle,
        healthGoal: _selectedGoal,
        dietaryRestrictions: _selectedDiet,
        medicalConditions: allConditions,
        medications: _medicationCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true); // true = profil güncellendi
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AksaColors.riskHigh,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addCustomCondition() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AksaColors.surfaceCard,
        title: const Text('Başka Hastalık Ekle', style: TextStyle(color: AksaColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AksaColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Hastalık adını yazın'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty && !_customConditions.contains(val)) {
                setState(() => _customConditions.add(val));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'Profili Düzenle',
        subtitle: 'Kişisel verilerini güncelle',
        trailing: _isSaving
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AksaColors.primary))),
              )
            : TextButton(
                onPressed: _saveProfile,
                child: const Text('Kaydet', style: TextStyle(color: AksaColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Temel Fiziksel Bilgiler ──
            const _SectionTitle('Temel Bilgiler'),
            Row(
              children: [
                Expanded(child: _buildTextField('Yaş', _ageCtrl, suffix: 'yıl')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Boy', _heightCtrl, suffix: 'cm')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('Kilo', _weightCtrl, suffix: 'kg')),
              ],
            ),
            const SizedBox(height: 24),

            // ── Cinsiyet & Yaşam Tarzı ──
            const _SectionTitle('Cinsiyet'),
            Wrap(
              spacing: 8,
              children: _genders.map((g) => ChoiceChip(
                label: Text(g),
                selected: _selectedGender == g,
                onSelected: (s) { if (s) setState(() => _selectedGender = g); },
                selectedColor: AksaColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AksaColors.primaryLight,
                labelStyle: TextStyle(color: _selectedGender == g ? AksaColors.primaryLight : AksaColors.textSecondary),
                backgroundColor: AksaColors.surfaceElevated,
                side: BorderSide(color: _selectedGender == g ? AksaColors.primary : AksaColors.surfaceElevated),
              )).toList(),
            ),
            const SizedBox(height: 24),

            const _SectionTitle('Hareket / Yaşam Tarzı'),
            Wrap(
              spacing: 8,
              children: _lifestyles.map((l) => ChoiceChip(
                label: Text(l),
                selected: _selectedLifestyle == l,
                onSelected: (s) { if (s) setState(() => _selectedLifestyle = l); },
                selectedColor: AksaColors.primary.withValues(alpha: 0.2),
                backgroundColor: AksaColors.surfaceElevated,
                checkmarkColor: AksaColors.primaryLight,
                labelStyle: TextStyle(color: _selectedLifestyle == l ? AksaColors.primaryLight : AksaColors.textSecondary),
                side: BorderSide(color: _selectedLifestyle == l ? AksaColors.primary : AksaColors.surfaceElevated),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // ── Sağlık Hedefi ──
            const _SectionTitle('Ana Sağlık Hedefi'),
            Wrap(
              spacing: 8,
              children: _goals.map((g) {
                final id = g['id']!;
                final label = g['label']!;
                final isSelected = _selectedGoal == id;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (s) { if (s) setState(() => _selectedGoal = id); },
                  selectedColor: AksaColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AksaColors.surfaceElevated,
                  checkmarkColor: AksaColors.primaryLight,
                  labelStyle: TextStyle(color: isSelected ? AksaColors.primaryLight : AksaColors.textSecondary),
                  side: BorderSide(color: isSelected ? AksaColors.primary : AksaColors.surfaceElevated),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Diyet ──
            const _SectionTitle('Diyet Kısıtlamaları'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dietOptions.map((d) {
                final sel = _selectedDiet.contains(d);
                return FilterChip(
                  label: Text(d),
                  selected: sel,
                  onSelected: (s) => setState(() => s ? _selectedDiet.add(d) : _selectedDiet.remove(d)),
                  selectedColor: AksaColors.riskMedium.withValues(alpha: 0.2),
                  backgroundColor: AksaColors.surfaceElevated,
                  checkmarkColor: AksaColors.riskMedium,
                  labelStyle: TextStyle(color: sel ? AksaColors.riskMedium : AksaColors.textSecondary),
                  side: BorderSide(color: sel ? AksaColors.riskMedium : AksaColors.surfaceElevated),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Kronik Hastalıklar ──
            const _SectionTitle('Kronik Hastalıklar'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._conditionsList.map((c) {
                  final sel = _selectedConditions.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (s) => setState(() => s ? _selectedConditions.add(c) : _selectedConditions.remove(c)),
                    selectedColor: AksaColors.riskHigh.withValues(alpha: 0.15),
                    backgroundColor: AksaColors.surfaceElevated,
                    checkmarkColor: AksaColors.riskHigh,
                    labelStyle: TextStyle(color: sel ? AksaColors.riskHigh : AksaColors.textSecondary),
                    side: BorderSide(color: sel ? AksaColors.riskHigh : AksaColors.surfaceElevated),
                  );
                }),
                ..._customConditions.map((c) {
                  return InputChip(
                    label: Text(c),
                    onDeleted: () => setState(() => _customConditions.remove(c)),
                    deleteIconColor: AksaColors.riskHigh,
                    backgroundColor: AksaColors.riskHigh.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(color: AksaColors.riskHigh),
                    side: const BorderSide(color: AksaColors.riskHigh),
                  );
                }),
                ActionChip(
                  label: const Text('Diğer Ekle +'),
                  onPressed: _addCustomCondition,
                  backgroundColor: AksaColors.surfaceElevated,
                  labelStyle: const TextStyle(color: AksaColors.textSecondary),
                  side: const BorderSide(color: AksaColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── İlaçlar ──
            const _SectionTitle('Düzenli İlaç Kullanımı'),
            TextField(
              controller: _medicationCtrl,
              maxLines: 3,
              style: const TextStyle(color: AksaColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Kullandığınız ilaçları buraya yazabilirsiniz...',
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {required String suffix}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AksaColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
