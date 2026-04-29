import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/models/exercise_model.dart';
import 'workout_session_screen.dart';

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

  // ── Zorluk / "Bugün Yorgunum" durumu ─────────────────────────
  bool _isTired = false;
  String get _difficulty => _isTired ? 'easy' : 'normal';

  @override
  void initState() {
    super.initState();
    _repository = ExerciseRepository(ApiClient.dio);
    _loadPrefsAndData();
  }

  Future<void> _loadPrefsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isTired = prefs.getBool('is_tired_mode') ?? false);
    await _loadExerciseData();
  }

  // Egzersiz tipine göre kcal/dakika — backend ile birebir eşleşir
  static const Map<String, int> _kcalPerMin = {
    'HIIT Kardiyo':        12,
    'Güç Antrenmanı':        8,
    'Bisiklet / Spinning':  7,
    'Yüzme':                 9,
    'Kalistenik':            6,
    'Tempolu Yürüyüş':      4,
    'Yoga & Esneme':         3,
    'Aktif Dinlenme':        1,
  };

  Future<void> _loadExerciseData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getExerciseSummary(difficulty: _difficulty);
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

  Future<void> _toggleTired({bool forceTired = false}) async {
    final newValue = forceTired ? true : !_isTired;
    setState(() => _isTired = newValue);
    // Tercihi kalıcı kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tired_mode', newValue);
    await _loadExerciseData();
  }

  // Antrenman sonucu işleme
  Future<void> _handleWorkoutResult(
      WorkoutResult result, int recIndex) async {
    // ── Backend'e kaydet (B) ──────────────────────────────────
    final rec        = _exerciseData!.recommendations[recIndex];
    final kcalPerMin = _kcalPerMin[rec.type] ?? 5;
    final kcal       = (result.completedSeconds ~/ 60) * kcalPerMin;
    unawaited(_repository.completeSession(
      exerciseName:    rec.type,
      durationSeconds: result.completedSeconds,
      caloriesBurned:  kcal,
      completed:       result.completed,
      markedTooHard:   result.markedTooHard,
    ));

    if (result.completed) {
      // Konfeti efekti göster
      if (mounted) _showCompletionCelebration(context);

      // Haftalık planda bugünü ✅ yap (local state)
      if (_exerciseData != null) {
        final todayIndex = DateTime.now().weekday - 1;
        final updatedPlan = _exerciseData!.weeklyPlan.asMap().entries.map((e) {
          if (e.key == todayIndex) {
            return WeeklyPlanItem(
                day: e.value.day, activity: e.value.activity, done: true);
          }
          return e.value;
        }).toList();
        setState(() {
          _exerciseData = ExerciseModel(
            rationale:       _exerciseData!.rationale,
            recommendations: _exerciseData!.recommendations,
            hrZone:          _exerciseData!.hrZone,
            weeklyPlan:      updatedPlan,
            heartRateHourly: _exerciseData!.heartRateHourly,
            recoveryScore:   _exerciseData!.recoveryScore,
            weeklyStats:     _exerciseData!.weeklyStats,
          );
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Antrenman tamamlandı! Harika iş!'),
            backgroundColor: AksaColors.riskLow,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      // Yarıda bırakıldı
      if (result.markedTooHard) {
        // Zor buldu → pref kaydet ve her zaman easy moda geç
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('prefer_easy_mode', true);
        if (!_isTired) {
          await _toggleTired(forceTired: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('💆 Hafif mod aktif. Bir sonraki öneri güncellendi.'),
                backgroundColor: AksaColors.riskMedium,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return; // _loadExerciseData zaten çağrıldı
        }
      }

      // Kalan süreyi öneriye yansıt
      if (result.remainingMinutes > 0 && _exerciseData != null) {
        final updated = List<ExerciseRecommendation>.from(
            _exerciseData!.recommendations);
        if (recIndex < updated.length) {
          updated[recIndex] = updated[recIndex]
              .copyWith(duration: '${result.remainingMinutes} dk kaldı');
          setState(() {
            _exerciseData = ExerciseModel(
              rationale:       _exerciseData!.rationale,
              recommendations: updated,
              hrZone:          _exerciseData!.hrZone,
              weeklyPlan:      _exerciseData!.weeklyPlan,
              heartRateHourly: _exerciseData!.heartRateHourly,
              recoveryScore:   _exerciseData!.recoveryScore,
              weeklyStats:     _exerciseData!.weeklyStats,
            );
          });
        }
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
      appBar: AksaAppBar(
        title: 'Egzersiz',
        subtitle: _isTired
            ? '😴 Dinlenme modu aktif'
            : 'Kişiselleştirilmiş öneri & plan',
      ),
      body: RefreshIndicator(
        onRefresh: _loadExerciseData,
        color: AksaColors.primary,
        backgroundColor: AksaColors.surfaceElevated,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── "Bugün Yorgunum" Toggle Banner ──────────────────
            _buildTiredBanner(),

            // ── Personalised Rationale
            const SectionHeader('Bugün İçin Öneri',
                subtitle: 'Verilerinize göre oluşturuldu'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRationaleCard(context, data.rationale),
            ),

            // ── Toparlanma Skoru (F)
            const SectionHeader('Toparlanma Durumu',
                subtitle: 'Bugünkü vücut hazırlığı'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRecoveryCard(context, data.recoveryScore),
            ),

            // ── Activity Cards
            const SectionHeader('Önerilen Aktiviteler'),
            ...data.recommendations.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _ExerciseCard(
                  rec: entry.value,
                  index: entry.key,
                  onResult: _handleWorkoutResult,
                ),
              ),
            ),

            // ── HR Target Zone
            const SectionHeader('Hedef Kalp Atış Hızı Bölgesi'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildHRZoneCard(context, data.hrZone),
            ),

            // ── Haftalık Özet İstatistik (H)
            const SectionHeader('Bu Haftaki Aktivite',
                subtitle: 'Pazartesiden bugüne'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildWeeklyStatsCard(context, data.weeklyStats),
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

  // ── "Bugün Yorgunum" Toggle Banner ───────────────────────────
  Widget _buildTiredBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: _isLoading ? null : _toggleTired,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _isTired
                ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                : AksaColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isTired
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                  : AksaColors.textMuted.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // İkon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isTired ? Icons.bedtime_rounded : Icons.bolt_rounded,
                  key: ValueKey(_isTired),
                  color: _isTired
                      ? const Color(0xFFA78BFA)
                      : AksaColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Metin
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(_isTired),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isTired
                            ? 'Dinlenme modu aktif'
                            : 'Bugün yorgun hissediyor musun?',
                        style: TextStyle(
                          color: _isTired
                              ? const Color(0xFFA78BFA)
                              : AksaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isTired
                            ? 'Egzersizler hafifletildi. Dokunarak normale dön.'
                            : 'Dokunarak önerileri hafiflet.',
                        style: const TextStyle(
                          color: AksaColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Toggle chip
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isTired
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                      : AksaColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isTired ? 'Aktif' : 'Normal',
                  style: TextStyle(
                    color: _isTired
                        ? const Color(0xFFA78BFA)
                        : AksaColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Toparlanma Skoru Kartı (F) ───────────────────────────────
  Widget _buildRecoveryCard(BuildContext context, int score) {
    final Color scoreColor = score >= 75
        ? AksaColors.riskLow
        : score >= 45
            ? AksaColors.riskMedium
            : AksaColors.riskHigh;
    final String label = score >= 75
        ? 'Harika — Antrenman için hazırsın!'
        : score >= 45
            ? 'Orta — Hafif antrenman önerilir'
            : 'Düşük — Dinlenmeyi tercih et';

    return AksaCard(
      child: Row(
        children: [
          // Daire gösterge
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 7,
                    backgroundColor: AksaColors.surfaceElevated,
                    color: scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toparlanma Skoru',
                  style: const TextStyle(
                      color: AksaColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                      color: scoreColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Konfeti Kutlama Overlay ─────────────────────────────────
  void _showCompletionCelebration(BuildContext ctx) {
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CompletionOverlay(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  // ── Haftalık İstatistik Özet Kartı (H) ───────────────────────
  Widget _buildWeeklyStatsCard(BuildContext context, WeeklyStats stats) {
    final streakLabel = stats.streakDays >= 7
        ? '🔥 ${stats.streakDays} gün'
        : '${stats.streakDays} gün';
    return AksaCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _WeeklyStatChip(
            icon: Icons.timer_outlined,
            value: '${stats.totalActiveMinutes} dk',
            label: 'Aktif Süre',
            color: AksaColors.primary,
          ),
          Container(width: 1, height: 44,
              color: AksaColors.textMuted.withValues(alpha: 0.2)),
          _WeeklyStatChip(
            icon: Icons.local_fire_department_outlined,
            value: '${stats.totalCalories} kcal',
            label: 'Kalori',
            color: AksaColors.riskMedium,
          ),
          Container(width: 1, height: 44,
              color: AksaColors.textMuted.withValues(alpha: 0.2)),
          _WeeklyStatChip(
            icon: Icons.fitness_center_outlined,
            value: '${stats.workoutsDone} gün',
            label: 'Antrenman',
            color: AksaColors.riskLow,
          ),
          Container(width: 1, height: 44,
              color: AksaColors.textMuted.withValues(alpha: 0.2)),
          _WeeklyStatChip(
            icon: Icons.local_fire_department_rounded,
            value: streakLabel,
            label: 'Seri',
            color: stats.streakDays >= 7
                ? const Color(0xFFFF6B35)
                : AksaColors.riskMedium,
          ),
        ],
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
              color: Colors.white.withValues(alpha: 0.15),
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
                color: AksaColors.textMuted.withValues(alpha: 0.3),
              ),
              _HRZoneValue('Hedef', data.targetHr.toString(), 'bpm', AksaColors.primary),
              Container(
                width: 1,
                height: 50,
                color: AksaColors.textMuted.withValues(alpha: 0.3),
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
    // Dart: Pazartesi=1 ... Pazar=7 → 0-indexed: Pzt=0 ... Paz=6
    final todayIndex = DateTime.now().weekday - 1;
    return AksaCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: plan.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          final isToday = i == todayIndex;
          final done    = item.done;
          return Container(
            decoration: BoxDecoration(
              color: isToday ? AksaColors.primary.withValues(alpha: 0.08) : null,
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
                      ? AksaColors.primary.withValues(alpha: 0.2)
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
                            color: AksaColors.primary.withValues(alpha: 0.2),
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
                      AksaColors.riskHigh.withValues(alpha: 0.25),
                      AksaColors.riskHigh.withValues(alpha: 0.0),
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

class _WeeklyStatChip extends StatelessWidget {
  const _WeeklyStatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
              color: AksaColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Konfeti Kutlama Widget'ı ─────────────────────────────────────────────────
class _CompletionOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _CompletionOverlay({required this.onDone});

  @override
  State<_CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<_CompletionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _emojis = ['🎉', '🔥', '⚡', '💪', '🏆', '✨'];
  static const _count   = 18;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            children: List.generate(_count, (i) {
              final frac   = i / _count;
              final left   = (frac * size.width + i * 37.0) % size.width;
              final top    = _ctrl.value * size.height * (0.7 + frac * 0.4);
              final opacity = (1 - _ctrl.value).clamp(0.0, 1.0);
              return Positioned(
                left: left,
                top: top - 60,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    _emojis[i % _emojis.length],
                    style: TextStyle(fontSize: 24 + (i % 3) * 6.0),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.rec, required this.index, required this.onResult});
  final ExerciseRecommendation rec;
  final int index;
  final Future<void> Function(WorkoutResult, int) onResult;

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
              color: color.withValues(alpha: 0.15),
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
                        color: color.withValues(alpha: 0.15),
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
                FilledButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<WorkoutResult>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => WorkoutSessionScreen(
                          exerciseName: rec.type,
                          exerciseIcon: rec.icon,
                          durationStr: rec.duration,
                          accentColor: color,
                          intensity: rec.intensity,
                        ),
                      ),
                    );
                    if (result != null) {
                      await onResult(result, index);
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Başla',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.15),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
        color: Colors.white.withValues(alpha: 0.12),
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