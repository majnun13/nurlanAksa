import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/info_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/mock/mock_data.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _metric = "Adım";

  @override
  Widget build(BuildContext context) {
    final values = MockAksaData.series[_metric] ?? [];
    final spots = <FlSpot>[
      for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return Scaffold(
      appBar: const AksaAppBar(title: 'Detay / Trendler'),
      body: ListView(
        children: [
          const SectionTitle("Metrik Seç", subtitle: "Grafikte görmek istediğin metriği seç."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MockAksaData.series.keys.map((k) {
                final selected = _metric == k;
                return ChoiceChip(
                  label: Text(k),
                  selected: selected,
                  onSelected: (_) => setState(() => _metric = k),
                );
              }).toList(),
            ),
          ),
          const SectionTitle("Zaman Serisi", subtitle: "Örnek veri (son 7 gün)."),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InfoCard(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: true),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        spots: spots,
                        barWidth: 3,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}