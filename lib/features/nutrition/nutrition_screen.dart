import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/mock/mock_data.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'nutrition_report_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  NutritionScreenState createState() => NutritionScreenState();
}

class NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nutritionRepo = NutritionRepository();
  List<Map<String, dynamic>> _todayMeals = [];
  bool _loadingMeals = false;

  // Günlük toplamlar
  double _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;

  // Kişiselleştirilmiş hedefler (backend'den gelecek)
  double _calorieTarget = 2000;
  double _proteinTarget = 100;
  double _carbsTarget = 225;
  double _fatTarget = 67;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadTodayMeals();
    _loadNutritionTargets();
  }

  Future<void> _loadNutritionTargets() async {
    try {
      final targets = await _nutritionRepo.getNutritionTargets();
      if (mounted) {
        setState(() {
          _calorieTarget = (targets['calorie_target'] as num).toDouble();
          _proteinTarget = (targets['protein_target'] as num).toDouble();
          _carbsTarget = (targets['carbs_target'] as num).toDouble();
          _fatTarget = (targets['fat_target'] as num).toDouble();
        });
      }
    } catch (_) {
      // Backend erişilemezse mock varsayılanlar kalır
    }
  }

  /// ShellScreen'den sekme değişikliğinde çağrılır
  void refreshTargets() {
    _loadNutritionTargets();
  }

  Future<void> _loadTodayMeals() async {
    setState(() => _loadingMeals = true);
    try {
      final meals = await _nutritionRepo.getTodayMeals();
      double cal = 0, pro = 0, carb = 0, fat = 0;
      for (final m in meals) {
        cal += (m['calories'] as num?)?.toDouble() ?? 0;
        pro += (m['protein'] as num?)?.toDouble() ?? 0;
        carb += (m['carbs'] as num?)?.toDouble() ?? 0;
        fat += (m['fat'] as num?)?.toDouble() ?? 0;
      }
      if (mounted) {
        setState(() {
          _todayMeals = meals;
          _totalCalories = cal;
          _totalProtein = pro;
          _totalCarbs = carb;
          _totalFat = fat;
          _loadingMeals = false;
        });
      }
    } catch (_) {
      // Backend bağlı değilse mock data kullan
      if (mounted) {
        setState(() {
          _totalCalories = MockAksaData.caloriesToday;
          _totalProtein = MockAksaData.proteinToday;
          _totalCarbs = MockAksaData.carbsToday;
          _totalFat = MockAksaData.fatToday;
          _loadingMeals = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'Beslenme',
        subtitle: 'Gün özeti & öğün kaydı',
        trailing: IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: AksaColors.primary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NutritionReportScreen()),
            );
          },
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: AksaColors.primaryLight,
          unselectedLabelColor: AksaColors.textMuted,
          indicatorColor: AksaColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Günlük Özet'),
            Tab(text: 'Öğünlerim'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMealSheet,
        backgroundColor: AksaColors.primary,
        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
        label: const Text('Öğün Ekle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildDailySummaryTab(),
          _buildMealsListTab(),
        ],
      ),
    );
  }

  Widget _buildDailySummaryTab() {
    final calorieTarget = _calorieTarget;
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Calorie ring card
        const SectionHeader('Kalori Takibi'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GradientCard(
            gradient: AksaColors.gradPrimary,
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: (_totalCalories / calorieTarget).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_totalCalories.toInt()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          const Text('kcal',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alınan Kalori',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${_totalCalories.toInt()} / ${calorieTarget.toInt()} kcal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text('Kalan',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${(calorieTarget - _totalCalories).toInt()} kcal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Macro breakdown
        const SectionHeader('Makro Besin Dağılımı',
            subtitle: 'Günlük hedeflere göre'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AksaCard(
            child: Column(
              children: [
                MacroProgressRow(
                  label: 'Protein',
                  current: _totalProtein,
                  target: _proteinTarget,
                  unit: 'g',
                  color: AksaColors.riskHigh,
                ),
                const Divider(height: 20),
                MacroProgressRow(
                  label: 'Karbonhidrat',
                  current: _totalCarbs,
                  target: _carbsTarget,
                  unit: 'g',
                  color: AksaColors.riskMedium,
                ),
                const Divider(height: 20),
                MacroProgressRow(
                  label: 'Yağ',
                  current: _totalFat,
                  target: _fatTarget,
                  unit: 'g',
                  color: AksaColors.accent,
                ),
              ],
            ),
          ),
        ),

        // Next meal suggestion
        const SectionHeader('Sonraki Öğün Önerisi'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: AksaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🍽️', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Text('Akşam Öğünü İçin',
                        style: TextStyle(
                            color: AksaColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                _SuggestionChip('Izgara tavuk veya balık'),
                _SuggestionChip('Zeytinyağlı sebzeli salata'),
                _SuggestionChip('Baklagil (nohut / mercimek)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealsListTab() {
    if (_loadingMeals) {
      return const Center(
        child: CircularProgressIndicator(color: AksaColors.primary),
      );
    }

    // Eğer API'den öğünler geldiyse onları göster, yoksa mock data
    final displayMeals = _todayMeals.isNotEmpty
        ? _todayMeals
        : MockAksaData.meals;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const SectionHeader('Bugünkü Öğünler'),
        ...displayMeals.map((m) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _MealCard(meal: m),
            )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: _showAddMealSheet,
            icon: const Icon(Icons.add),
            label: const Text('Öğün Ekle'),
          ),
        ),
      ],
    );
  }

  void _showAddMealSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AksaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddMealSheet(
        onPhotoTap: () {
          Navigator.pop(context);
          _pickImageAndPredict(ImageSource.camera);
        },
        onGalleryTap: () {
          Navigator.pop(context);
          _pickImageAndPredict(ImageSource.gallery);
        },
        onManualTap: () {
          Navigator.pop(context);
          _showManualMealEntry();
        },
      ),
    );
  }

  void _pickImageAndPredict(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    if (!mounted) return;

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          color: AksaColors.surface,
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AksaColors.primary),
                SizedBox(height: 16),
                Text('MacroVision analiz ediyor...',
                    style: TextStyle(color: AksaColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = File(picked.path);
      final result = await _nutritionRepo.predictFood(file);

      if (!mounted) return;
      Navigator.pop(context); // Loading dialog kapat

      _showPredictionResult(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Loading dialog kapat
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tahmin hatası: ${e.toString().replaceAll("Exception: ", "")}'),
        backgroundColor: AksaColors.riskHigh,
      ));
    }
  }

  void _showPredictionResult(Map<String, dynamic> result) {
    final predictedFood = result['predicted_food'] as String;
    final confidence = (result['confidence'] as num).toDouble();
    final gramCtrl = TextEditingController(text: '150');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AksaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AksaColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('🍽️ Tahmin Sonucu',
                  style: TextStyle(
                      color: AksaColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              AksaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      predictedFood.replaceAll('-', ' ').toUpperCase(),
                      style: const TextStyle(
                          color: AksaColors.primaryLight,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Güven: %${confidence.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: AksaColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gramCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AksaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Miktar (gram)',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    final gram = double.tryParse(gramCtrl.text) ?? 150;
                    Navigator.pop(ctx);
                    await _calculateAndAddMeal(predictedFood, gram, 'Öğün');
                  },
                  child: const Text('Besin Değerlerini Hesapla ve Ekle'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _calculateAndAddMeal(String foodName, double gram, String mealType) async {
    try {
      final result = await _nutritionRepo.calculateNutrition(foodName, gram);

      await _nutritionRepo.logMeal(
        foodName: foodName,
        mealType: mealType,
        gram: gram,
        protein: (result['protein'] as num).toDouble(),
        carbs: (result['carbs'] as num).toDouble(),
        fat: (result['fat'] as num).toDouble(),
        calories: (result['calories'] as num).toDouble(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Öğün başarıyla eklendi! ✅'),
          backgroundColor: AksaColors.accent,
        ));
        _loadTodayMeals(); // Listeyi yenile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AksaColors.riskHigh,
        ));
      }
    }
  }

  void _showManualMealEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AksaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ManualMealEntrySheet(
        nutritionRepo: _nutritionRepo,
        onMealAdded: () => _loadTodayMeals(),
      ),
    );
  }
}

// ── Manual Meal Entry Sheet ──────────────────────────
class _ManualMealEntrySheet extends StatefulWidget {
  const _ManualMealEntrySheet({
    required this.nutritionRepo,
    required this.onMealAdded,
  });
  final NutritionRepository nutritionRepo;
  final VoidCallback onMealAdded;

  @override
  State<_ManualMealEntrySheet> createState() => _ManualMealEntrySheetState();
}

class _ManualMealEntrySheetState extends State<_ManualMealEntrySheet> {
  final _searchCtrl = TextEditingController();
  final _gramCtrl = TextEditingController(text: '150');
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedFood;
  Map<String, dynamic>? _calculatedNutrition;
  bool _searching = false;
  bool _calculating = false;
  String _selectedMealType = 'Öğle';

  final _mealTypes = ['Kahvaltı', 'Öğle', 'Akşam', 'Ara öğün'];

  void _searchFoods(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.nutritionRepo.searchFoods(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      _selectedFood = food;
      _searchCtrl.text = (food['name'] as String).replaceAll('-', ' ');
      _searchResults = [];
    });
    _calculateNutrition();
  }

  void _calculateNutrition() async {
    if (_selectedFood == null) return;
    final gram = double.tryParse(_gramCtrl.text) ?? 150;
    setState(() => _calculating = true);
    try {
      final result = await widget.nutritionRepo.calculateNutrition(
        _selectedFood!['name'] as String,
        gram,
      );
      if (mounted) {
        setState(() {
          _calculatedNutrition = result;
          _calculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _calculating = false);
    }
  }

  void _addMeal() async {
    if (_calculatedNutrition == null) return;
    final n = _calculatedNutrition!;
    try {
      await widget.nutritionRepo.logMeal(
        foodName: n['food_name'] as String,
        mealType: _selectedMealType,
        gram: (n['gram'] as num).toDouble(),
        protein: (n['protein'] as num).toDouble(),
        carbs: (n['carbs'] as num).toDouble(),
        fat: (n['fat'] as num).toDouble(),
        calories: (n['calories'] as num).toDouble(),
      );
      if (mounted) {
        widget.onMealAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Öğün başarıyla eklendi! ✅'),
          backgroundColor: AksaColors.accent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AksaColors.riskHigh,
        ));
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _gramCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AksaColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Manuel Öğün Ekle',
                style: TextStyle(
                    color: AksaColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Yemek arama
            TextField(
              controller: _searchCtrl,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AksaColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Yemek adı yazın (ör: pilav, tavuk sote)',
                prefixIcon: Icon(Icons.search, color: AksaColors.textMuted),
              ),
              onChanged: _searchFoods,
            ),

            // Arama sonuçları
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AksaColors.primary),
                  ),
                ),
              ),

            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AksaColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final food = _searchResults[i];
                    final name = (food['name'] as String).replaceAll('-', ' ');
                    final cal = food['calories_per_100g'];
                    return ListTile(
                      dense: true,
                      title: Text(name,
                          style: const TextStyle(
                              color: AksaColors.textPrimary, fontSize: 14)),
                      subtitle: cal != null
                          ? Text('${cal} kcal / 100g',
                              style: const TextStyle(
                                  color: AksaColors.textMuted, fontSize: 11))
                          : null,
                      trailing: const Icon(Icons.add_circle_outline,
                          color: AksaColors.primary, size: 20),
                      onTap: () => _selectFood(food),
                    );
                  },
                ),
              ),

            if (_selectedFood != null) ...[
              const SizedBox(height: 16),

              // Öğün tipi seçimi
              const Text('Öğün Tipi',
                  style: TextStyle(
                      color: AksaColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _mealTypes.map((t) {
                  final sel = t == _selectedMealType;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMealType = t),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AksaColors.primary.withOpacity(0.15)
                            : AksaColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AksaColors.primary : const Color(0xFF334155),
                        ),
                      ),
                      child: Text(t,
                          style: TextStyle(
                            color: sel
                                ? AksaColors.primaryLight
                                : AksaColors.textSecondary,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Gram girişi
              TextField(
                controller: _gramCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AksaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Miktar (gram)',
                  suffixText: 'g',
                ),
                onChanged: (_) => _calculateNutrition(),
              ),
            ],

            // Besin değerleri gösterimi
            if (_calculating)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AksaColors.primary, strokeWidth: 2),
                ),
              ),

            if (_calculatedNutrition != null && !_calculating) ...[
              const SizedBox(height: 16),
              AksaCard(
                child: Column(
                  children: [
                    _NutritionRow(
                        'Kalori',
                        '${(_calculatedNutrition!['calories'] as num).toStringAsFixed(0)} kcal',
                        AksaColors.riskMedium),
                    const Divider(height: 12),
                    _NutritionRow(
                        'Protein',
                        '${(_calculatedNutrition!['protein'] as num).toStringAsFixed(1)} g',
                        AksaColors.riskHigh),
                    const Divider(height: 12),
                    _NutritionRow(
                        'Karbonhidrat',
                        '${(_calculatedNutrition!['carbs'] as num).toStringAsFixed(1)} g',
                        AksaColors.riskMedium),
                    const Divider(height: 12),
                    _NutritionRow(
                        'Yağ',
                        '${(_calculatedNutrition!['fat'] as num).toStringAsFixed(1)} g',
                        AksaColors.accent),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AksaColors.gradPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FilledButton.icon(
                    onPressed: _addMeal,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text('Öğünü Kaydet',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AksaColors.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Suggestion Chip
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: AksaColors.accent, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AksaColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Meal Card
class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final Map<String, dynamic> meal;

  @override
  Widget build(BuildContext context) {
    // API'den gelen veya mock data formatını destekle
    final name = (meal['food_name'] ?? meal['name'] ?? '').toString().replaceAll('-', ' ');
    final type = (meal['meal_type'] ?? meal['type'] ?? '').toString();
    final time = meal['time'] ?? '';
    final kcal = meal['calories'] ?? meal['kcal'] ?? 0;
    final protein = meal['protein'] ?? 0;
    final carbs = meal['carbs'] ?? 0;
    final fat = meal['fat'] ?? 0;
    final emoji = meal['emoji'] ?? '🍽️';

    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji.toString(), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
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
                    Text(
                        '$type${time.isNotEmpty ? "  •  $time" : ""}',
                        style: const TextStyle(
                            color: AksaColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(kcal as num).toInt()} kcal',
                      style: const TextStyle(
                          color: AksaColors.riskMedium,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroChip('P: ${(protein as num).toInt()}g', AksaColors.riskHigh),
              const SizedBox(width: 8),
              _MacroChip('K: ${(carbs as num).toInt()}g', AksaColors.riskMedium),
              const SizedBox(width: 8),
              _MacroChip('Y: ${(fat as num).toInt()}g', AksaColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Add Meal Bottom Sheet
class _AddMealSheet extends StatelessWidget {
  const _AddMealSheet({
    required this.onPhotoTap,
    required this.onGalleryTap,
    required this.onManualTap,
  });
  final VoidCallback onPhotoTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AksaColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Öğün Ekle',
              style: TextStyle(
                  color: AksaColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _SheetOption(
            icon: Icons.camera_alt_outlined,
            color: AksaColors.primary,
            title: 'Fotoğraf Çek',
            subtitle: 'MacroVision AI besin değerlerini otomatik tanır',
            onTap: onPhotoTap,
          ),
          const SizedBox(height: 12),
          _SheetOption(
            icon: Icons.photo_library_outlined,
            color: AksaColors.secondary,
            title: 'Galeriden Seç',
            subtitle: 'Daha önce çektiğiniz bir fotoğraf yükleyin',
            onTap: onGalleryTap,
          ),
          const SizedBox(height: 12),
          _SheetOption(
            icon: Icons.edit_outlined,
            color: AksaColors.accent,
            title: 'Manuel Gir',
            subtitle: 'Yemek arayın ve besin değerlerini görün',
            onTap: onManualTap,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AksaColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AksaColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AksaColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AksaColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}