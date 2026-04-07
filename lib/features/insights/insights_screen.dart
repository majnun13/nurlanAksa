import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../app/theme.dart';
import '../../data/mock/mock_data.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Risk & Detay',
        subtitle: 'Sağlık skoru ve trend analizi',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Risk Score Gauge
          const SectionHeader('Sağlık Risk Skoru'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRiskGauge(context),
          ),

          // ── Sub-scores breakdown
          const SectionHeader('Alt Skor Detayı',
              subtitle: 'Skora katkıda bulunan faktörler'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSubScores(context),
          ),

          // ── Score history line chart
          const SectionHeader('Risk Skoru Trendi',
              subtitle: 'Son 7 günlük değişim'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRiskTrendChart(context),
          ),

          // ── Actionable recommendations
          const SectionHeader('Skoru İyileştir',
              subtitle: 'Uygulanabilir öneriler'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionableRecs(context),
          ),

          // ── Profile Risk
          const SectionHeader('Profil Risk Faktörleri'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _buildProfileRisk(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGauge(BuildContext context) {
    final score = MockAksaData.riskPoints;
    final trend = MockAksaData.riskTrend;
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
                  backgroundColor: scoreColor.withOpacity(0.1),
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
                        color: scoreColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Text(
                  MockAksaData.riskLabel,
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
                  color: AksaColors.riskHigh.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AksaColors.riskHigh.withOpacity(0.3)),
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

  Widget _buildSubScores(BuildContext context) {
    final items = [
      {
        'label': 'Beslenme',
        'icon': '🍎',
        'score': 0.62,
        'color': AksaColors.riskMedium,
        'desc': 'Protein alımı düşük'
      },
      {
        'label': 'Aktivite',
        'icon': '🏃',
        'score': 0.68,
        'color': AksaColors.riskMedium,
        'desc': 'Adım sayısı hedefin altında'
      },
      {
        'label': 'Uyku',
        'icon': '💤',
        'score': 0.72,
        'color': AksaColors.riskHigh,
        'desc': 'Kalite düşük, 6.2 sa'
      },
      {
        'label': 'Anomali',
        'icon': '❤️',
        'score': 0.45,
        'color': AksaColors.riskMedium,
        'desc': '1 orta seviye uyarı'
      },
    ];

    return AksaCard(
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final color = item['color'] as Color;
          final score = ((item['score'] as double) * 100).round();
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
                      Text('$score',
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
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRiskTrendChart(BuildContext context) {
    final history = MockAksaData.riskHistory;
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
                    if (i < 0 || i >= history.length) return const SizedBox.shrink();
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
            minY: 40,
            maxY: 70,
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
                    color: AksaColors.riskMedium,
                    strokeWidth: 2,
                    strokeColor: AksaColors.bg,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AksaColors.riskMedium.withOpacity(0.2),
                      AksaColors.riskMedium.withOpacity(0.0),
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

  Widget _buildActionableRecs(BuildContext context) {
    final recs = [
      {
        'icon': '💤',
        'text': '7-8 saatlik düzenli uyku hedefleyin. Yatış saatini sabit tutun.',
        'impact': -8,
      },
      {
        'icon': '🚶',
        'text':
            'Günlük adım sayınızı kademeli artırın — bu hafta 5,000 hedefleyin.',
        'impact': -12,
      },
      {
        'icon': '🍗',
        'text': 'Her öğüne protein kaynağı (yumurta, tavuk, baklagil) ekleyin.',
        'impact': -6,
      },
    ];

    return Column(
      children: recs
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AksaCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['icon'] as String,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(r['text'] as String,
                            style: const TextStyle(
                                color: AksaColors.textSecondary,
                                fontSize: 13,
                                height: 1.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AksaColors.riskLow.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${r['impact']} puan',
                          style: const TextStyle(
                              color: AksaColors.riskLow,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildProfileRisk(BuildContext context) {
    final factors = [
      {'label': 'Yaş (27)', 'value': '+0 puan', 'safe': true},
      {'label': 'BMI (24.6)', 'value': '+0 puan', 'safe': true},
      {'label': 'Kronik hastalık', 'value': '+0 puan', 'safe': true},
      {'label': 'Yaşam tarzı (Orta)', 'value': '+5 puan', 'safe': false},
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
                  style: TextStyle(color: AksaColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}