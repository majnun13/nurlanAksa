import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/info_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/mock/mock_data.dart';

class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AksaAppBar(title: 'Egzersiz'),
      body: ListView(
        children: [
          const SectionTitle("Bugün İçin Öneri", subtitle: "Güvenlik kapıları / uygunluk kontrolü sonrası öneri."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(MockAksaData.exerciseTip, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: const [
                      Chip(label: Text("Orta yoğunluk")),
                      Chip(label: Text("20 dk")),
                      Chip(label: Text("Yürüyüş")),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () {}, child: const Text("Daha Kolay"))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(onPressed: () {}, child: const Text("Başlat"))),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}