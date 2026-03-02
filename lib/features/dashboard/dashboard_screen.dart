import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/info_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/mock/mock_data.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Color _riskColor(double score, ColorScheme cs) {
    if (score < 0.33) return cs.primary;
    if (score < 0.66) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = MockAksaData.riskScore;

    return Scaffold(
      appBar: AksaAppBar(
        title: 'AKSA',
        trailing: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Bildirimler',
        ),
      ),
      body: ListView(
        children: [
          if (MockAksaData.hasAnomaly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: InfoCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Anomali Uyarısı • ${MockAksaData.anomalyLevel}",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(MockAksaData.anomalyMessage),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () {},
                            child: const Text("Detayı Gör"),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

          const SectionTitle("Günlük Özet", subtitle: "Risk skoru, öne çıkan etkenler ve öneriler."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Genel Risk Skoru", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: score,
                            minHeight: 12,
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(_riskColor(score, cs)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("${(score * 100).round()}%",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Seviye: ${MockAksaData.riskLabel}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
          ),

          const SectionTitle("Öne Çıkan Etkenler", subtitle: "Skora en çok etki eden faktörler (açıklanabilirlik)."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              child: Column(
                children: MockAksaData.topFactors.map((f) {
                  final impact = (f["impact"] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(f["name"] as String)),
                        Text("+${(impact * 100).round()}",
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SectionTitle("Öneriler", subtitle: "Uygulanabilir yönlendirmeler."),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                InfoCard(
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(MockAksaData.nutritionTip)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                InfoCard(
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(MockAksaData.exerciseTip)),
                    ],
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