import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../app/theme.dart';
import '../../core/widgets/aksa_app_bar.dart';
import '../../core/widgets/aksa_widgets.dart';
import '../../core/services/health_connect_service.dart';
import '../shell/shell_screen.dart';

class WearableConnectScreen extends StatefulWidget {
  const WearableConnectScreen({super.key});

  @override
  State<WearableConnectScreen> createState() => _WearableConnectScreenState();
}

class _WearableConnectScreenState extends State<WearableConnectScreen> {
  bool _googleFit = false;
  bool _healthKit = false;
  bool _connectingGoogle = false;
  bool _connectingApple = false;
  final _healthService = HealthConnectService.instance;

  void _connectGoogle() async {
    setState(() => _connectingGoogle = true);
    try {
      final granted = await _healthService.requestAuthorization();
      if (mounted) {
        setState(() {
          _connectingGoogle = false;
          _googleFit = granted;
        });
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Google Fit izni verilemedi. Lütfen ayarlardan izin verin.'),
            backgroundColor: AksaColors.riskMedium,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingGoogle = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bağlantı hatası: ${e.toString()}'),
          backgroundColor: AksaColors.riskHigh,
        ));
      }
    }
  }

  void _connectApple() async {
    setState(() => _connectingApple = true);
    try {
      final granted = await _healthService.requestAuthorization();
      if (mounted) {
        setState(() {
          _connectingApple = false;
          _healthKit = granted;
        });
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('HealthKit izni verilemedi. Lütfen ayarlardan izin verin.'),
            backgroundColor: AksaColors.riskMedium,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingApple = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bağlantı hatası: ${e.toString()}'),
          backgroundColor: AksaColors.riskHigh,
        ));
      }
    }
  }

  void _disconnectGoogle() async {
    await _healthService.revokeAccess();
    if (mounted) setState(() => _googleFit = false);
  }

  void _disconnectApple() async {
    await _healthService.revokeAccess();
    if (mounted) setState(() => _healthKit = false);
  }

  void _goToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ShellScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _googleFit || _healthKit;

    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: const AksaAppBar(
        title: 'Cihaz Bağla',
        subtitle: 'Sağlık verilerini entegre et',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 8),

                // ── Header banner
                _buildBanner(),

                const SizedBox(height: 24),

                // ── Google Fit
                _WearableCard(
                  platformName: 'Google Fit',
                  description: 'Adım sayısı, egzersiz, uyku ve kalp atışı verilerini senkronize edin.',
                  isConnected: _googleFit,
                  isLoading: _connectingGoogle,
                  logoWidget: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.directions_run_rounded,
                        color: Colors.white, size: 26),
                  ),
                  permissions: const [
                    '📊 Adım & Mesafe',
                    '❤️ Kalp Atış Hızı',
                    '😴 Uyku Verileri',
                    '🔥 Yakılan Kalori',
                  ],
                  onConnect: Platform.isAndroid ? _connectGoogle : _connectGoogle,
                  onDisconnect: _disconnectGoogle,
                ),

                const SizedBox(height: 14),

                // ── Apple HealthKit
                _WearableCard(
                  platformName: 'Apple HealthKit',
                  description: 'iPhone & Apple Watch ile sağlık ve fitness verilerini aktarın.',
                  isConnected: _healthKit,
                  isLoading: _connectingApple,
                  logoWidget: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AksaColors.surfaceElevated,
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Center(
                      child: Text('🍎', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  permissions: const [
                    '📊 Aktivite & Adım',
                    '❤️ EKG & Kalp Atışı',
                    '😴 Uyku Analizi',
                    '🩸 Kan Oksijeni',
                  ],
                  onConnect: Platform.isIOS ? _connectApple : _connectApple,
                  onDisconnect: _disconnectApple,
                ),

                const SizedBox(height: 24),

                // ── Privacy note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AksaColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_outlined,
                              color: AksaColors.accent, size: 18),
                          SizedBox(width: 8),
                          Text('Verileriniz Güvende',
                              style: TextStyle(
                                  color: AksaColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sağlık verileriniz uçtan uca şifrelenerek işlenir. '
                        'Üçüncü taraflarla paylaşılmaz. Dilediğiniz zaman izni iptal edebilirsiniz.',
                        style: TextStyle(
                            color: AksaColors.textMuted,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Main CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: Column(
              children: [
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: connected
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: TextButton(
                    onPressed: _goToApp,
                    child: const Text(
                      'Şimdi Değil, Atla',
                      style: TextStyle(
                          color: AksaColors.textMuted,
                          fontSize: 14,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AksaColors.gradPrimary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AksaColors.primary.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _goToApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.rocket_launch_rounded,
                          color: Colors.white),
                      label: Text(
                        connected
                            ? 'AKSA\'yı Başlat'
                            : 'Bağlantı Olmadan Devam Et',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1060), Color(0xFF0F2257)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.watch_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giyilebilir Cihaz Bağla',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Verilerinizi otomatik senkronize ederek çok daha kişisel analizler alın.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wearable Card Widget
class _WearableCard extends StatelessWidget {
  const _WearableCard({
    required this.platformName,
    required this.description,
    required this.isConnected,
    required this.isLoading,
    required this.logoWidget,
    required this.permissions,
    required this.onConnect,
    required this.onDisconnect,
  });

  final String platformName;
  final String description;
  final bool isConnected;
  final bool isLoading;
  final Widget logoWidget;
  final List<String> permissions;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isConnected
            ? AksaColors.riskLow.withOpacity(0.05)
            : AksaColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected
              ? AksaColors.riskLow.withOpacity(0.4)
              : const Color(0xFF1E293B),
          width: isConnected ? 1.5 : 1,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: AksaColors.riskLow.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              logoWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(platformName,
                            style: const TextStyle(
                                color: AksaColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        if (isConnected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AksaColors.riskLow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('✓ Bağlı',
                                style: TextStyle(
                                    color: AksaColors.riskLow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            color: AksaColors.textMuted, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Permissions
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: permissions.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AksaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p,
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 11)),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: !isConnected ? AksaColors.gradPrimary : null,
                color: isConnected
                    ? AksaColors.riskHigh.withOpacity(0.1)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                onPressed: isLoading
                    ? null
                    : (isConnected ? onDisconnect : onConnect),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: isConnected
                      ? AksaColors.riskHigh
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isConnected ? 'Bağlantıyı Kes' : '$platformName\'ı Bağla',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
