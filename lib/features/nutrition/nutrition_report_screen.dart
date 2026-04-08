import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app/theme.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../data/repositories/nutrition_repository.dart';

class NutritionReportScreen extends StatefulWidget {
  const NutritionReportScreen({super.key});

  @override
  State<NutritionReportScreen> createState() => _NutritionReportScreenState();
}

class _NutritionReportScreenState extends State<NutritionReportScreen> {
  final _repo = NutritionRepository();
  bool _isWeekly = true; // true = haftalık, false = aylık
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  // Gün detay açma
  String? _expandedDate;
  List<Map<String, dynamic>> _expandedMeals = [];
  bool _loadingMeals = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _isWeekly
          ? await _repo.getWeeklyReport()
          : await _repo.getMonthlyReport();
      if (mounted) setState(() { _report = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDayMeals(String dateStr) async {
    if (_expandedDate == dateStr) {
      setState(() => _expandedDate = null);
      return;
    }
    setState(() { _expandedDate = dateStr; _loadingMeals = true; });
    try {
      final date = DateTime.parse(dateStr);
      final meals = await _repo.getMealsByDate(date);
      if (mounted) setState(() { _expandedMeals = meals; _loadingMeals = false; });
    } catch (_) {
      if (mounted) setState(() { _expandedMeals = []; _loadingMeals = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AppBar(
        backgroundColor: AksaColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AksaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Beslenme Raporları',
            style: TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AksaColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AksaColors.textMuted),
            const SizedBox(height: 16),
            const Text('Rapor yüklenemedi',
                style: TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Backend sunucusunun çalıştığından emin olun.',
                style: TextStyle(color: AksaColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(backgroundColor: AksaColors.primary),
              child: const Text('Tekrar Dene', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildPeriodToggle(),
        _buildSummaryCards(),
        _buildCalorieChart(),
        _buildMacroAverages(),
        _buildDailyList(),
        _buildRecommendations(),
      ],
    );
  }

  // ── Haftalık / Aylık Toggle ──────────────────────────────
  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AksaColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(child: _toggleBtn('Haftalık', true)),
            const SizedBox(width: 4),
            Expanded(child: _toggleBtn('Aylık', false)),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool isWeekly) {
    final selected = _isWeekly == isWeekly;
    return GestureDetector(
      onTap: () {
        if (_isWeekly != isWeekly) {
          setState(() => _isWeekly = isWeekly);
          _loadReport();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AksaColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AksaColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )),
        ),
      ),
    );
  }

  // ── Özet Kartları ────────────────────────────────────────
  Widget _buildSummaryCards() {
    final avg = _report?['averages'] as Map<String, dynamic>? ?? {};
    final targets = _report?['targets'] as Map<String, dynamic>? ?? {};
    final activeDays = _report?['active_days'] ?? 0;
    final totalDays = _isWeekly ? 7 : 30;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(child: _summaryCard(
            '🔥', 'Ort. Kalori',
            '${avg['avg_calories'] ?? 0}',
            'Hedef: ${targets['calorie_target'] ?? 0}',
            AksaColors.primary,
          )),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(
            '📊', 'Kayıtlı Gün',
            '$activeDays / $totalDays',
            'gün kayıt yapıldı',
            AksaColors.accent,
          )),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(
            '🍽️', 'Ort. Öğün',
            '${avg['avg_meals'] ?? 0}',
            'öğün / gün',
            AksaColors.riskMedium,
          )),
        ],
      ),
    );
  }

  Widget _summaryCard(String emoji, String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AksaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AksaColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: AksaColors.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  // ── Kalori Trend Grafiği ────────────────────────────────
  Widget _buildCalorieChart() {
    final dailyData = _report?['daily_data'] as List<dynamic>? ?? [];
    if (dailyData.isEmpty) return const SizedBox.shrink();

    final calTarget = (_report?['targets']?['calorie_target'] ?? 2000).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: AksaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kalori Trendi 📈',
                style: TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Günlük kalori alımınız ve hedefiniz',
                style: TextStyle(color: AksaColors.textMuted, fontSize: 11)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (calTarget * 1.5).ceilToDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final d = dailyData[group.x.toInt()];
                        final dateStr = d['date']?.toString() ?? '';
                        final day = dateStr.length >= 10 ? dateStr.substring(5) : dateStr;
                        return BarTooltipItem(
                          '$day\n${rod.toY.toInt()} kcal',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= dailyData.length) return const SizedBox();
                          final dateStr = dailyData[idx]['date']?.toString() ?? '';
                          final label = dateStr.length >= 10 ? dateStr.substring(8) : '';
                          // Aylıkta her 3 günde bir etiket göster
                          if (!_isWeekly && idx % 3 != 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label, style: const TextStyle(fontSize: 9, color: AksaColors.textMuted)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: calTarget,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AksaColors.riskHigh.withOpacity(0.4),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(dailyData.length, (i) {
                    final cal = (dailyData[i]['total_calories'] ?? 0).toDouble();
                    final overTarget = cal > calTarget;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: cal,
                        width: _isWeekly ? 28 : 7,
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: overTarget
                              ? [AksaColors.riskHigh.withOpacity(0.7), AksaColors.riskHigh]
                              : [AksaColors.primary.withOpacity(0.6), AksaColors.primaryLight],
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(AksaColors.primary, 'Hedef altı'),
                const SizedBox(width: 16),
                _legendItem(AksaColors.riskHigh, 'Hedef üstü'),
                const SizedBox(width: 16),
                _legendItem(AksaColors.riskHigh.withOpacity(0.4), 'Hedef çizgisi'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AksaColors.textMuted, fontSize: 10)),
      ],
    );
  }

  // ── Makro Ortalamaları ──────────────────────────────────
  Widget _buildMacroAverages() {
    final avg = _report?['averages'] as Map<String, dynamic>? ?? {};
    final targets = _report?['targets'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AksaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Makro Ortalamaları',
                style: TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_isWeekly ? 'Son 7 günün ortalaması' : 'Son 30 günün ortalaması',
                style: const TextStyle(color: AksaColors.textMuted, fontSize: 11)),
            const SizedBox(height: 16),
            MacroProgressRow(
              label: 'Protein',
              current: (avg['avg_protein'] ?? 0).toDouble(),
              target: (targets['protein_target'] ?? 100).toDouble(),
              unit: 'g',
              color: AksaColors.riskHigh,
            ),
            const Divider(height: 20),
            MacroProgressRow(
              label: 'Karbonhidrat',
              current: (avg['avg_carbs'] ?? 0).toDouble(),
              target: (targets['carbs_target'] ?? 225).toDouble(),
              unit: 'g',
              color: AksaColors.riskMedium,
            ),
            const Divider(height: 20),
            MacroProgressRow(
              label: 'Yağ',
              current: (avg['avg_fat'] ?? 0).toDouble(),
              target: (targets['fat_target'] ?? 67).toDouble(),
              unit: 'g',
              color: AksaColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  // ── Gün Gün Detay Listesi ──────────────────────────────
  Widget _buildDailyList() {
    final dailyData = _report?['daily_data'] as List<dynamic>? ?? [];
    // Ters sırada (en yeni gün en üstte)
    final reversed = dailyData.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gün Bazlı Detay',
              style: TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Bir güne dokunarak o günün öğünlerini görün',
              style: TextStyle(color: AksaColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          ...reversed.map((d) => _buildDayTile(d as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildDayTile(Map<String, dynamic> day) {
    final dateStr = day['date']?.toString() ?? '';
    final cal = day['total_calories'] ?? 0;
    final mealCount = day['meal_count'] ?? 0;
    final isExpanded = _expandedDate == dateStr;
    final isToday = dateStr == DateTime.now().toString().substring(0, 10);

    // Tarih formatla
    String formattedDate = dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      final weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
      formattedDate = '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AksaCard(
        child: Column(
          children: [
            InkWell(
              onTap: mealCount > 0 ? () => _loadDayMeals(dateStr) : null,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: mealCount > 0
                          ? AksaColors.primary.withOpacity(0.1)
                          : AksaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        mealCount > 0 ? '🍽️' : '—',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(formattedDate,
                                style: const TextStyle(color: AksaColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AksaColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Bugün', style: TextStyle(color: AksaColors.primary, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mealCount > 0
                              ? '$mealCount öğün  •  P: ${(day['total_protein'] ?? 0).toStringAsFixed(0)}g  K: ${(day['total_carbs'] ?? 0).toStringAsFixed(0)}g  Y: ${(day['total_fat'] ?? 0).toStringAsFixed(0)}g'
                              : 'Kayıt yok',
                          style: const TextStyle(color: AksaColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    mealCount > 0 ? '$cal kcal' : '',
                    style: TextStyle(
                      color: cal > (_report?['targets']?['calorie_target'] ?? 2000)
                          ? AksaColors.riskHigh : AksaColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (mealCount > 0)
                    Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AksaColors.textMuted, size: 20),
                ],
              ),
            ),
            // Genişletilmiş öğün detayı
            if (isExpanded) ...[
              const Divider(height: 16),
              if (_loadingMeals)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AksaColors.primary))),
                )
              else if (_expandedMeals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Öğün bulunamadı', style: TextStyle(color: AksaColors.textMuted, fontSize: 12)),
                )
              else
                ..._expandedMeals.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: AksaColors.primary, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['food_name'] ?? '', style: const TextStyle(color: AksaColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('${m['meal_type']}  •  ${(m['gram'] ?? 0).toStringAsFixed(0)}g',
                                style: const TextStyle(color: AksaColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${(m['calories'] ?? 0).toStringAsFixed(0)} kcal',
                          style: const TextStyle(color: AksaColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                )),
            ],
          ],
        ),
      ),
    );
  }

  // ── Akıllı Öneriler ────────────────────────────────────
  Widget _buildRecommendations() {
    final recs = _report?['recommendations'] as List<dynamic>? ?? [];
    if (recs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Akıllı Öneriler',
              style: TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Beslenme verilerinize göre kişisel öneriler',
              style: const TextStyle(color: AksaColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          ...recs.map((r) {
            final rec = r as Map<String, dynamic>;
            return _buildRecommendationCard(rec);
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    // Başlığa göre renk belirle
    final title = rec['title'] ?? '';
    Color cardColor;
    if (title.contains('Harika') || title.contains('İyi') || title.contains('Tamam')) {
      cardColor = const Color(0xFF10B981); // Yeşil
    } else if (title.contains('Artır') || title.contains('Şart') || title.contains('Ekle')) {
      cardColor = AksaColors.riskMedium; // Turuncu
    } else if (title.contains('Azalt') || title.contains('Fazla') || title.contains('Çok Az')) {
      cardColor = AksaColors.riskHigh; // Kırmızı
    } else {
      cardColor = AksaColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AksaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: cardColor, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec['emoji'] ?? '💡', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: cardColor, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(rec['description'] ?? '',
                      style: const TextStyle(color: AksaColors.textSecondary, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
