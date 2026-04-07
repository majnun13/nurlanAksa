import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/mock/mock_data.dart';

import '../../core/network/api_client.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/models/exercise_model.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  late ExerciseRepository _repository;
  ExerciseModel? _exerciseData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = ExerciseRepository(ApiClient.dio);
    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getExerciseSummary();
      setState(() {
        _exerciseData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AksaColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AksaColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AksaColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AksaColors.riskHigh, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AksaColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadExerciseData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AksaColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _exerciseData!;

    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Egzersiz',
        subtitle: 'Kişiselleştirilmiş öneri & plan',
      ),
      body: RefreshIndicator(
        onRefresh: _loadExerciseData,
        color: AksaColors.primary,
        backgroundColor: AksaColors.surfaceElevated,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Personalised Rationale
            const SectionHeader('Bugün İçin Öneri',
                subtitle: 'Verilerinize göre oluşturuldu'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRationaleCard(context, data.rationale),
            ),

            // ── Activity Cards
            const SectionHeader('Önerilen Aktiviteler'),
            ...data.recommendations.map(
              (rec) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ExerciseCard(rec: rec),
              ),
            ),

            // ── HR Target Zone
            const SectionHeader('Hedef Kalp Atış Hızı Bölgesi'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHRZoneCard(context, data.hrZone),
            ),

            // ── Weekly Plan
            const SectionHeader('Haftalık Plan',
                subtitle: 'Bu haftanın programı'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildWeeklyPlan(context, data.weeklyPlan),
            ),

            // ── Heart Rate 24h Chart
            const SectionHeader('Kalp Atış Hızı – 24 Saat',
                subtitle: 'Bugünkü HR dağılımı'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHRChart(context, data.heartRateHourly),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRationaleCard(BuildContext context, RationaleData data) {
    return GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F4C81), Color(0xFF1E2A50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  data.description,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: data.tags.map((t) => _TagChip(t.label)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRZoneCard(BuildContext context, HRZoneData data) {
    return AksaCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_outline, color: AksaColors.riskHigh, size: 18),
              SizedBox(width: 8),
              Text('Bugün için güvenli bölge',
                  style: TextStyle(
                      color: AksaColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HRZoneValue('Min', data.minHr.toString(), 'bpm', AksaColors.accent),
              Container(
                width: 1,
                height: 50,
                color: AksaColors.textMuted.withOpacity(0.3),
              ),
              _HRZoneValue('Hedef', data.targetHr.toString(), 'bpm', AksaColors.primary),
              Container(
                width: 1,
                height: 50,
                color: AksaColors.textMuted.withOpacity(0.3),
              ),
              _HRZoneValue('Max', data.maxHr.toString(), 'bpm', AksaColors.riskMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Zone bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AksaColors.accent,
                    AksaColors.primary,
                    AksaColors.riskMedium,
                    AksaColors.riskHigh,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Çok Düşük',
                  style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
              Text('Optimal',
                  style: TextStyle(
                      color: AksaColors.textSecondary, fontSize: 10)),
              Text('Çok Yüksek',
                  style: TextStyle(color: AksaColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlan(BuildContext context, List<WeeklyPlanItem> plan) {
    return AksaCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: plan.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isToday = i == 5; // Cumartesi örnek
          final done = item.done;
          return Container(
            decoration: BoxDecoration(
              color: isToday ? AksaColors.primary.withOpacity(0.08) : null,
              border: i < plan.length - 1
                  ? const Border(
                      bottom: BorderSide(color: Color(0xFF1E293B)))
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(20))
                  : i == plan.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(20))
                      : null,
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isToday
                      ? AksaColors.primary.withOpacity(0.2)
                      : AksaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.day,
                  style: TextStyle(
                    color: isToday
                        ? AksaColors.primaryLight
                        : AksaColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                item.activity,
                style: TextStyle(
                  color: done
                      ? AksaColors.textMuted
                      : AksaColors.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: done
                  ? const Icon(Icons.check_circle_rounded,
                      color: AksaColors.accent, size: 20)
                  : isToday
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AksaColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Bugün',
                              style: TextStyle(
                                  color: AksaColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        )
                      : const Icon(Icons.circle_outlined,
                          color: AksaColors.textMuted, size: 20),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHRChart(BuildContext context, List<double> hrs) {
    return AksaCard(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AksaColors.surfaceElevated,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${s.y.toInt()} bpm',
                          const TextStyle(
                              color: AksaColors.riskHigh,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ))
                    .toList(),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFF1E293B), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 4,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}:00',
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 9),
                  ),
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            minY: 50,
            maxY: 130,
            lineBarsData: [
              LineChartBarData(
                spots: hrs
                    .asMap()
                    .entries
                    .map((e) =>
                        FlSpot(e.key.toDouble(), e.value))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: AksaColors.riskHigh,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AksaColors.riskHigh.withOpacity(0.25),
                      AksaColors.riskHigh.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.rec});
  final ExerciseRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final color = Color(rec.color);
    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(rec.icon,
                style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rec.type,
                        style: const TextStyle(
                            color: AksaColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(rec.duration,
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AksaChip(
                        label: rec.intensity, color: color),
                  ],
                ),
                const SizedBox(height: 8),
                Text(rec.desc,
                    style: const TextStyle(
                        color: AksaColors.textSecondary,
                        fontSize: 12,
                        height: 1.5)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: color.withOpacity(0.15),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Başla',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}

class _HRZoneValue extends StatelessWidget {
  const _HRZoneValue(this.label, this.value, this.unit, this.color);
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AksaColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: value,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                      color: AksaColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}