import 'package:flutter/material.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/info_card.dart';
import '../../core/widgets/section_title.dart';
import 'preferences_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AksaAppBar(title: 'Ayarlar'),
      body: ListView(
        children: [
          const SectionTitle("Bildirimler", subtitle: "Tür ve sıklık (UI)."),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Öğün hatırlatmaları / gün sonu özeti"),
                    value: PreferencesStore.notifMeals,
                    onChanged: (v) => setState(() => PreferencesStore.notifMeals = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Egzersiz hatırlatmaları"),
                    value: PreferencesStore.notifExercise,
                    onChanged: (v) => setState(() => PreferencesStore.notifExercise = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Anomali uyarıları (kademeli)"),
                    value: PreferencesStore.notifAnomaly,
                    onChanged: (v) => setState(() => PreferencesStore.notifAnomaly = v),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle("Görünürlük", subtitle: "Hangi kart/grafikler gösterilsin?"),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InfoCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Adım"),
                    value: PreferencesStore.showSteps,
                    onChanged: (v) => setState(() => PreferencesStore.showSteps = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Nabız"),
                    value: PreferencesStore.showHeart,
                    onChanged: (v) => setState(() => PreferencesStore.showHeart = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Uyku"),
                    value: PreferencesStore.showSleep,
                    onChanged: (v) => setState(() => PreferencesStore.showSleep = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}