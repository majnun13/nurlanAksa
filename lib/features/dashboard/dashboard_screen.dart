import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../core/network/api_client.dart';
import '../../core/services/wearable_sync_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardRepository _repository;
  DashboardModel? _dashboardData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(ApiClient.dio);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Önce Apple Health verilerini backend'e gönder (gerçek risk skoru için)
    // Hata olursa sessizce devam et – dashboard yine de yüklenir
    await WearableSyncService.instance.syncNow();

    try {
      final data = await _repository.getDashboardSummary();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

    if (_error != null || _dashboardData == null) {
      return Scaffold(
        backgroundColor: AksaColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AksaColors.riskHigh, size: 48),
              const SizedBox(height: 16),
              Text(
                'Bir hata oluştu:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AksaColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadDashboardData();
                },
                child: const Text('Tekrar Dene'),
              )
            ],
          ),
        ),
      );
    }

    final data = _dashboardData!;

    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'AKSA',
        showLogo: true,
        subtitle: _greeting(data.userName),
        trailing: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined,
                  color: AksaColors.textPrimary),
            ),
            if (data.anomaly.hasAnomaly)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AksaColors.riskHigh,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── Anomaly Banner
            if (data.anomaly.hasAnomaly) _buildAnomalyBanner(context, data.anomaly),

            // ── Risk Score Card
            _buildRiskScoreCard(context, data.risk),

            // ── Activity Stats Row
            SectionHeader(
              'Aktivite',
              subtitle: 'Bugünkü hareket verileri',
              action: TextButton(
                onPressed: () {},
                child: const Text('Tümü',
                    style: TextStyle(
                        color: AksaColors.primaryLight, fontSize: 13)),
              ),
            ),
            _buildActivityGrid(context, data.activity),

            // ── Sleep + HR
            SectionHeader(
              'Uyku & Kalp',
              subtitle: 'Bu geceye ait veriler',
            ),
            _buildSleepHRRow(context, data.sleepHeart),

            // ── Weekly Steps Chart
            const SectionHeader('Haftalık Adım Grafiği', subtitle: 'Son 7 gün'),
            _buildStepsChart(context, data.weeklyChart),

            // ── Recommendations
            const SectionHeader('Kişisel Öneriler',
                subtitle: 'AI destekli yönlendirmeler'),
            _buildRecommendations(context, data.recommendations),
          ],
        ),
      ),
    );
  }

  String _greeting(String userName) {
    final h = DateTime.now().hour;
    if (h < 12) return 'Günaydın, $userName 👋';
    if (h < 18) return 'İyi günler, $userName 👋';
    return 'İyi akşamlar, $userName 👋';
  }

  Widget _buildAnomalyBanner(BuildContext context, AnomalyData anomaly) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C2D12), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Anomali Uyarısı',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          anomaly.level,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anomaly.message,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Detayı Gör',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskScoreCard(BuildContext context, RiskData risk) {
    final score = risk.score;
    final trend = risk.trend;
    final grad = score < 30
        ? AksaColors.gradSuccess
        : score < 70
            ? AksaColors.gradWarn
            : AksaColors.gradDanger;
    final scoreColor =
        score < 30 ? AksaColors.riskLow : score < 70 ? AksaColors.riskMedium : AksaColors.riskHigh;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GradientCard(
        gradient: grad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Sağlık Risk Skoru',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trend > 0 ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trend > 0 ? '+' : ''}$trend puan',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 4),
                  child: Text('/100',
                      style: TextStyle(color: Colors.white54, fontSize: 18)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        risk.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            // Top factors
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: risk.topFactors
                  .take(3)
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${f.icon} ${f.name}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGrid(BuildContext context, ActivityData activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          _ActivityProgressTile(
            icon: Icons.directions_walk_outlined,
            label: 'Adım',
            value: activity.stepsToday,
            goal: activity.stepsGoal,
            unit: 'adım',
            color: AksaColors.primary,
          ),
          _ActivityProgressTile(
            icon: Icons.local_fire_department_outlined,
            label: 'Kalori',
            value: activity.caloriesBurned,
            goal: activity.caloriesGoal,
            unit: 'kcal',
            color: AksaColors.riskMedium,
          ),
          _ActivityProgressTile(
            icon: Icons.timer_outlined,
            label: 'Aktif Süre',
            value: activity.activeMinutes,
            goal: activity.activeMinutesGoal,
            unit: 'dk',
            color: AksaColors.secondary,
          ),
          _ActivityProgressTile(
            icon: Icons.route_outlined,
            label: 'Mesafe',
            value: (activity.distanceKm * 10).round(),
            goal: 80,
            unit: 'km',
            color: AksaColors.accent,
            displayValue: activity.distanceKm.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepHRRow(BuildContext context, SleepHeartData sleepHeart) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: AksaCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bedtime_outlined,
                            color: Color(0xFF7C3AED), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('Uyku',
                          style: TextStyle(
                              color: AksaColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${sleepHeart.sleepHours}',
                          style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 28,
                              fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(
                          text: ' sa',
                          style: TextStyle(
                              color: AksaColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: sleepHeart.sleepQuality,
                      minHeight: 4,
                      backgroundColor:
                          const Color(0xFF7C3AED).withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kalite: %${(sleepHeart.sleepQuality * 100).round()}',
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AksaCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AksaColors.riskHigh.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.favorite_outlined,
                            color: AksaColors.riskHigh, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('Kalp Atışı',
                          style: TextStyle(
                              color: AksaColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${sleepHeart.restingHr}',
                          style: const TextStyle(
                              color: AksaColors.riskHigh,
                              fontSize: 28,
                              fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(
                          text: ' bpm',
                          style: TextStyle(
                              color: AksaColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                   const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final sev = sleepHeart.restingHrSeverity;
                    final Color color = sev == 'danger'
                        ? AksaColors.riskHigh
                        : sev == 'warning'
                            ? AksaColors.riskMedium
                            : AksaColors.riskLow;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        sleepHeart.restingHrLabel,
                        style: TextStyle(color: color, fontSize: 10),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsChart(BuildContext context, WeeklyChartData chartData) {
    if (chartData.steps.isEmpty || chartData.days.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final steps = chartData.steps;
    final days = chartData.days;
    final maxVal = steps.reduce((a, b) => a > b ? a : b).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AksaCard(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[i],
                              style: const TextStyle(
                                  color: AksaColors.textMuted, fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => const FlLine(
                        color: Color(0xFF1E293B), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(steps.length, (i) {
                    final isToday = i == steps.length - 2;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: steps[i].toDouble(),
                          width: 20,
                          borderRadius: BorderRadius.circular(6),
                          gradient: isToday
                              ? AksaColors.gradPrimary
                              : LinearGradient(
                                  colors: [
                                    AksaColors.primary.withOpacity(0.4),
                                    AksaColors.primary.withOpacity(0.2),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        gradient: AksaColors.gradPrimary,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('Bugün',
                    style:
                        TextStyle(color: AksaColors.textMuted, fontSize: 11)),
                const SizedBox(width: 16),
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: AksaColors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                const Text('Diğer',
                    style:
                        TextStyle(color: AksaColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context, List<RecommendationItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: items.map((item) {
          IconData icon;
          Color color;
          String title;

          switch (item.type) {
            case 'nutrition':
              icon = Icons.restaurant_outlined;
              color = AksaColors.accent;
              title = 'Beslenme';
              break;
            case 'exercise':
              icon = Icons.directions_walk_outlined;
              color = AksaColors.secondary;
              title = 'Egzersiz';
              break;
            case 'sleep':
            default:
              icon = Icons.bedtime_outlined;
              color = const Color(0xFF7C3AED);
              title = 'Uyku';
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecommendationTile(
              icon: icon,
              color: color,
              title: title,
              text: item.text,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ────────────────────────────────────────────
class _ActivityProgressTile extends StatelessWidget {
  const _ActivityProgressTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
    this.displayValue,
  });

  final IconData icon;
  final String label;
  final int value;
  final int goal;
  final String unit;
  final Color color;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    final pct = (value / goal).clamp(0.0, 1.0);
    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayValue ?? value.toString(),
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            '$label / $goal $unit',
            style:
                const TextStyle(color: AksaColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
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
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        color: AksaColors.textSecondary,
                        fontSize: 12,
                        height: 1.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AksaColors.textMuted, size: 20),
        ],
      ),
    );
  }
}