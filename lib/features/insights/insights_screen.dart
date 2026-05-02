import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/health_profile_model.dart';
import '../../core/network/api_client.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DashboardRepository _dashRepo;
  late ProfileRepository _profileRepo;

  DashboardModel? _data;
  HealthProfileModel? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dashRepo = DashboardRepository(ApiClient.dio);
    _profileRepo = ProfileRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dashRepo.getDashboardSummary(),
        _profileRepo.getHealthProfile(),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as DashboardModel;
          _profile = results[1] as HealthProfileModel;
          _isLoading = false;
        });
      }
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

    if (_error != null || _data == null) {
      return Scaffold(
        backgroundColor: AksaColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AksaColors.riskHigh, size: 48),
              const SizedBox(height: 16),
              Text(
                'Bir hata oluştu:\n${_error ?? "Bilinmeyen hata"}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AksaColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;

    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Risk & Detay',
        subtitle: 'Sağlık skoru ve trend analizi',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Risk Score Gauge
            const SectionHeader('Sağlık Risk Skoru'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRiskGauge(data.risk),
            ),

            // ── Sub-scores breakdown (computed from real data)
            const SectionHeader('Alt Skor Detayı',
                subtitle: 'Skora katkıda bulunan faktörler'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSubScores(data),
            ),

            // ── Score history line chart (son 7 günün haftalık adımlarından)
            const SectionHeader('Risk Skoru Trendi',
                subtitle: 'Son 7 günlük değişim'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRiskTrendChart(data),
            ),

            // ── Actionable recommendations (gerçek API önerileri)
            const SectionHeader('Skoru İyileştir',
                subtitle: 'Uygulanabilir öneriler'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActionableRecs(data.recommendations),
            ),

            // ── Profile Risk (gerçek profil verisi)
            const SectionHeader('Profil Risk Faktörleri'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _buildProfileRisk(_profile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskGauge(RiskData risk) {
    final score = risk.score;
    final trend = risk.trend;
    final isLow = score < 30;
    final isMed = score < 70;
    final scoreColor = isLow
        ? AksaColors.riskLow
        : isMed
            ? AksaColors.riskMedium
            : AksaColors.riskHigh;
    final grad = isLow
        ? AksaColors.gradSuccess
        : isMed
            ? AksaColors.gradWarn
            : AksaColors.gradDanger;

    return AksaCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 14,
                  backgroundColor: scoreColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text('/100',
                      style: TextStyle(
                          color: AksaColors.textMuted, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: grad,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: scoreColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Text(
                  risk.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (trend > 0 ? AksaColors.riskHigh : AksaColors.riskLow)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (trend > 0 ? AksaColors.riskHigh : AksaColors.riskLow)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      trend > 0 ? Icons.trending_up : Icons.trending_down,
                      color: trend > 0
                          ? AksaColors.riskHigh
                          : AksaColors.riskLow,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trend > 0 ? '+' : ''}$trend bu hafta',
                      style: TextStyle(
                        color: trend > 0
                            ? AksaColors.riskHigh
                            : AksaColors.riskLow,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubScores(DashboardModel data) {
    final sleepHours = data.sleepHeart.sleepHours;
    final sleepScore = ((sleepHours / 9.0).clamp(0.0, 1.0) * 100).round();
    final sleepColor = sleepScore >= 70
        ? AksaColors.riskLow
        : sleepScore >= 45
            ? AksaColors.riskMedium
            : AksaColors.riskHigh;

    final steps = data.activity.stepsToday;
    final stepsGoal = data.activity.stepsGoal;
    final activityScore = ((steps / stepsGoal).clamp(0.0, 1.0) * 100).round();
    final activityColor = activityScore >= 70
        ? AksaColors.riskLow
        : activityScore >= 40
            ? AksaColors.riskMedium
            : AksaColors.riskHigh;

    final recs = data.recommendations;
    final hasNutritionRec = recs.any((r) => r.type == 'nutrition');
    final nutritionScore = hasNutritionRec ? 55 : 80;
    final nutritionColor = nutritionScore >= 70 ? AksaColors.riskLow : AksaColors.riskMedium;

    final anomalyScore = data.anomaly.hasAnomaly ? 45 : 90;
    final anomalyColor = data.anomaly.hasAnomaly ? AksaColors.riskMedium : AksaColors.riskLow;

    final items = [
      {
        'label': 'Beslenme',
        'icon': '🍎',
        'score': nutritionScore / 100.0,
        'color': nutritionColor,
        'desc': hasNutritionRec ? 'Beslenme iyileştirme önerisi var' : 'Beslenme dengeli görünüyor',
      },
      {
        'label': 'Aktivite',
        'icon': '🏃',
        'score': activityScore / 100.0,
        'color': activityColor,
        'desc': steps < stepsGoal
            ? 'Bugün $steps adım / hedef $stepsGoal'
            : 'Günlük hedef tamamlandı!',
      },
      {
        'label': 'Uyku',
        'icon': '💤',
        'score': sleepScore / 100.0,
        'color': sleepColor,
        'desc': sleepHours < 0.5
            ? 'Uyku verisi henüz alınmadı'
            : '${sleepHours.toStringAsFixed(1)} sa uyku süresi',
      },
      {
        'label': 'Anomali',
        'icon': '❤️',
        'score': anomalyScore / 100.0,
        'color': anomalyColor,
        'desc': data.anomaly.hasAnomaly
            ? data.anomaly.level.isNotEmpty
                ? '${data.anomaly.level} seviye uyarı'
                : 'Anomali tespit edildi'
            : 'Anormal veri tespit edilmedi',
      },
    ];

    return AksaCard(
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final color = item['color'] as Color;
          final scoreVal = ((item['score'] as double) * 100).round();
          return Column(
            children: [
              if (i > 0) const Divider(height: 20),
              Row(
                children: [
                  Text(item['icon'] as String,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['label'] as String,
                            style: const TextStyle(
                                color: AksaColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(item['desc'] as String,
                            style: const TextStyle(
                                color: AksaColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$scoreVal',
                          style: TextStyle(
                              color: color,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const Text('/100',
                          style: TextStyle(
                              color: AksaColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item['score'] as double,
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRiskTrendChart(DashboardModel data) {
    // Haftalık adım verisinden risk trendi türet
    final weeklySteps = data.weeklyChart.steps;
    final weeklyDays = data.weeklyChart.days;
    final currentScore = data.risk.score;

    // Adımlara göre geçmiş günlerin risk skorunu tahmin et
    // Bugünkü skoru baz alarak adım oranlarından hesapla
    final List<Map<String, dynamic>> history = [];
    for (int i = 0; i < weeklySteps.length && i < weeklyDays.length; i++) {
      final steps = weeklySteps[i];
      // Eğer bugün (son eleman) ise gerçek skoru kullan
      if (i == weeklySteps.length - 1) {
        history.add({'date': weeklyDays[i], 'score': currentScore});
      } else {
        // Adım sayısına göre risk skoru tahmini
        // Az adım = yüksek risk, fazla adım = düşük risk
        int estimatedScore;
        if (steps == 0) {
          estimatedScore = (currentScore + 8).clamp(20, 90);
        } else if (steps >= 8000) {
          estimatedScore = (currentScore - 5).clamp(20, 90);
        } else if (steps >= 5000) {
          estimatedScore = (currentScore + 2).clamp(20, 90);
        } else {
          estimatedScore = (currentScore + 6).clamp(20, 90);
        }
        history.add({'date': weeklyDays[i], 'score': estimatedScore});
      }
    }

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final scores = history.map((h) => (h['score'] as int).toDouble()).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);

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
                          '${s.y.toInt()}',
                          const TextStyle(
                              color: AksaColors.riskMedium,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
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
                  reservedSize: 32,
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
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= history.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        history[i]['date'] as String,
                        style: const TextStyle(
                            color: AksaColors.textMuted, fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            minY: (minScore - 8).clamp(0, 100),
            maxY: (maxScore + 8).clamp(0, 100),
            lineBarsData: [
              LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(
                          e.key.toDouble(),
                          (e.value['score'] as int).toDouble(),
                        ))
                    .toList(),
                isCurved: true,
                curveSmoothness: 0.35,
                color: AksaColors.riskMedium,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                    radius: i == history.length - 1 ? 5 : 3,
                    color: i == history.length - 1
                        ? AksaColors.primary
                        : AksaColors.riskMedium,
                    strokeWidth: 2,
                    strokeColor: AksaColors.bg,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AksaColors.riskMedium.withValues(alpha: 0.2),
                      AksaColors.riskMedium.withValues(alpha: 0.0),
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

  Widget _buildActionableRecs(List<RecommendationItem> recs) {
    if (recs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: AksaCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '✅ Şu an için özel öneri bulunmuyor.',
                style: TextStyle(color: AksaColors.textMuted),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: recs
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AksaCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.type == 'nutrition'
                            ? '🍎'
                            : r.type == 'exercise'
                                ? '🏃'
                                : '💤',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(r.text,
                            style: const TextStyle(
                                color: AksaColors.textSecondary,
                                fontSize: 13,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildProfileRisk(HealthProfileModel? profile) {
    final age = profile?.age ?? 0;
    final weight = profile?.weightKg ?? 0.0;
    final height = profile?.heightCm ?? 0.0;
    final lifestyle = profile?.lifestyle ?? 'Bilinmiyor';
    final medicalConditions = profile?.medicalConditions ?? [];

    // BMI hesapla
    double bmi = 0;
    if (height > 0 && weight > 0) {
      bmi = weight / ((height / 100) * (height / 100));
    }
    final bmiLabel = bmi.toStringAsFixed(1);
    final bmiSafe = bmi >= 18.5 && bmi <= 24.9;

    // Yaş risk
    final ageSafe = age >= 18 && age <= 45;
    final agePuan = age > 60 ? '+15 puan' : age > 45 ? '+8 puan' : '+0 puan';

    // Kronik hastalık
    final hasConditions = medicalConditions.isNotEmpty;
    final conditionPuan = hasConditions ? '+${medicalConditions.length * 10} puan' : '+0 puan';

    // Yaşam tarzı
    final lifestyleActive = lifestyle.toLowerCase().contains('aktif');
    final lifestylePuan = lifestyleActive ? '+0 puan' : '+5 puan';

    final factors = [
      {
        'label': 'Yaş${age > 0 ? ' ($age)' : ''}',
        'value': agePuan,
        'safe': ageSafe,
      },
      {
        'label': bmi > 0 ? 'BMI ($bmiLabel)' : 'BMI (Hesaplanamadı)',
        'value': bmiSafe ? '+0 puan' : bmi < 18.5 ? '+8 puan' : '+10 puan',
        'safe': bmiSafe,
      },
      {
        'label': hasConditions
            ? 'Kronik hastalık (${medicalConditions.join(", ")})'
            : 'Kronik hastalık',
        'value': conditionPuan,
        'safe': !hasConditions,
      },
      {
        'label': 'Yaşam tarzı ($lifestyle)',
        'value': lifestylePuan,
        'safe': lifestyleActive,
      },
    ];

    return Column(
      children: [
        AksaCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: factors.asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
              final safe = f['safe'] as bool;
              return Container(
                decoration: BoxDecoration(
                  border: i < factors.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFF1E293B)))
                      : null,
                ),
                child: ListTile(
                  title: Text(f['label'] as String,
                      style: const TextStyle(
                          color: AksaColors.textSecondary, fontSize: 14)),
                  trailing: Text(
                    f['value'] as String,
                    style: TextStyle(
                      color: safe ? AksaColors.riskLow : AksaColors.riskMedium,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  leading: Icon(
                    safe ? Icons.check_circle_outline : Icons.info_outline,
                    color: safe ? AksaColors.riskLow : AksaColors.riskMedium,
                    size: 20,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        const AksaCard(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AksaColors.textMuted, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AKSA tarafından sunulan içerikler bilgilendirme amaçlıdır. '
                  'Tıbbi tanı yerine geçmez. Sağlık sorunları için bir uzmana danışın.',
                  style: TextStyle(
                      color: AksaColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}