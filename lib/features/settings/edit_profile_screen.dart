import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  late final TextEditingController _medicationCtrl;

  // Picker değerleri
  late int _selectedAge;
  late int _selectedHeight;
  late int _selectedWeightWhole;
  late int _selectedWeightDecimal;

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

  // Picker aralıkları
  static const _minAge = 10;
  static const _maxAge = 100;
  static const _minHeight = 100;
  static const _maxHeight = 220;
  static const _minWeight = 30;
  static const _maxWeight = 200;

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;
    
    _medicationCtrl = TextEditingController(text: p.medications ?? '');

    _selectedAge = (p.age ?? 25).clamp(_minAge, _maxAge);
    _selectedHeight = (p.heightCm?.round() ?? 170).clamp(_minHeight, _maxHeight);
    
    final weight = p.weightKg ?? 70.0;
    _selectedWeightWhole = weight.floor().clamp(_minWeight, _maxWeight);
    _selectedWeightDecimal = ((weight - weight.floor()) * 10).round().clamp(0, 9);

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
    _medicationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final allConditions = [..._selectedConditions, ..._customConditions];
      final weightKg = _selectedWeightWhole + (_selectedWeightDecimal / 10);
      await _profileRepo.saveHealthProfile(
        age: _selectedAge,
        weightKg: weightKg,
        heightCm: _selectedHeight.toDouble(),
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

  // ── Picker Bottom Sheet ──
  void _showPickerSheet({
    required String title,
    required int min,
    required int max,
    required int current,
    required String unit,
    required ValueChanged<int> onChanged,
    double step = 1,
  }) {
    int tempValue = current;
    final items = List.generate(max - min + 1, (i) => min + i);
    final initialIndex = items.indexOf(current).clamp(0, items.length - 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: AksaColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AksaColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İptal', style: TextStyle(color: AksaColors.textMuted, fontSize: 16)),
                  ),
                  Text(title, style: const TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
                  TextButton(
                    onPressed: () {
                      onChanged(tempValue);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Tamam', style: TextStyle(color: AksaColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
            // Picker
            SizedBox(
              height: 220,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                magnification: 1.2,
                squeeze: 1.1,
                useMagnifier: true,
                itemExtent: 44,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AksaColors.primary.withOpacity(0.3), width: 1),
                    ),
                  ),
                ),
                onSelectedItemChanged: (index) {
                  tempValue = items[index];
                },
                children: items.map((val) => Center(
                  child: Text(
                    '$val $unit',
                    style: const TextStyle(color: AksaColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWeightPickerSheet() {
    // 30.0 ~ 200.0 arasında 0.1 adımlarla tüm değerleri üret
    final allWeights = List.generate(
      (_maxWeight - _minWeight) * 10 + 1,
      (i) => _minWeight + (i / 10),
    );
    final currentWeight = _selectedWeightWhole + (_selectedWeightDecimal / 10);
    int initialIndex = allWeights.indexWhere((w) => (w - currentWeight).abs() < 0.05);
    if (initialIndex < 0) initialIndex = 0;
    double tempWeight = currentWeight;

    showModalBottomSheet(
      context: context,
      backgroundColor: AksaColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AksaColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İptal', style: TextStyle(color: AksaColors.textMuted, fontSize: 16)),
                  ),
                  const Text('Kilo', style: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedWeightWhole = tempWeight.floor();
                        _selectedWeightDecimal = ((tempWeight - tempWeight.floor()) * 10).round();
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Tamam', style: TextStyle(color: AksaColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                magnification: 1.22,
                squeeze: 1.0,
                useMagnifier: true,
                itemExtent: 48,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: AksaColors.primary.withOpacity(0.3), width: 1),
                    ),
                  ),
                ),
                onSelectedItemChanged: (index) {
                  tempWeight = allWeights[index];
                },
                children: allWeights.map((val) => Center(
                  child: Text(
                    '${val.toStringAsFixed(1)} kg',
                    style: const TextStyle(color: AksaColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AksaColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                Expanded(child: _buildPickerTile(
                  label: 'Yaş',
                  value: '$_selectedAge',
                  unit: 'yıl',
                  icon: Icons.cake_outlined,
                  color: AksaColors.primary,
                  onTap: () => _showPickerSheet(
                    title: 'Yaş',
                    min: _minAge,
                    max: _maxAge,
                    current: _selectedAge,
                    unit: 'yıl',
                    onChanged: (v) => setState(() => _selectedAge = v),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: _buildPickerTile(
                  label: 'Boy',
                  value: '$_selectedHeight',
                  unit: 'cm',
                  icon: Icons.height_rounded,
                  color: AksaColors.accent,
                  onTap: () => _showPickerSheet(
                    title: 'Boy',
                    min: _minHeight,
                    max: _maxHeight,
                    current: _selectedHeight,
                    unit: 'cm',
                    onChanged: (v) => setState(() => _selectedHeight = v),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: _buildPickerTile(
                  label: 'Kilo',
                  value: '$_selectedWeightWhole.$_selectedWeightDecimal',
                  unit: 'kg',
                  icon: Icons.monitor_weight_outlined,
                  color: AksaColors.secondary,
                  onTap: () => _showWeightPickerSheet(),
                )),
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

  Widget _buildPickerTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AksaColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: AksaColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(color: AksaColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AksaColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: color, size: 11),
                  const SizedBox(width: 3),
                  Text('Değiştir', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
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
