import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/info_card.dart';
import '../../core/widgets/section_title.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AksaAppBar(title: 'Beslenme'),
      body: ListView(
        children: [
          const SectionTitle("Öğün Kaydı", subtitle: "Manuel kayıt (şimdilik UI)."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Öğün adı",
                      hintText: "Örn: Tavuk + pilav",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Kalori (kcal)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Protein (g)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text("Kaydet"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle("Fotoğraf ile Kayıt", subtitle: "Bu ekran ileride kamera/segmentasyon akışına bağlanacak."),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InfoCard(
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined),
                  const SizedBox(width: 10),
                  const Expanded(child: Text("Fotoğraf çek / yükle (placeholder)")),
                  OutlinedButton(onPressed: () {}, child: const Text("Aç")),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}