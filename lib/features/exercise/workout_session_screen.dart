import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../app/theme.dart';

// ─────────────────────────────────────────────────────────────────
//  WorkoutSessionScreen – Antrenman Sayacı Ekranı
//  Kullanıcı "Başla"ya bastığında tam ekran modal olarak açılır.
// ─────────────────────────────────────────────────────────────────

class WorkoutSessionScreen extends StatefulWidget {
  final String exerciseName;
  final String exerciseIcon;
  final String durationStr; // "30 dk", "20 dk" vb.
  final Color accentColor;
  final String intensity;

  const WorkoutSessionScreen({
    super.key,
    required this.exerciseName,
    required this.exerciseIcon,
    required this.durationStr,
    required this.accentColor,
    required this.intensity,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen>
    with SingleTickerProviderStateMixin {
  // ── Timer State ───────────────────────────────────────────────
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isPaused  = false;
  bool _isFinished = false;

  // ── 3-2-1 Geri Sayım (G) ───────────────────────────────────────
  bool _isCountingDown = true;  // Başlangıçta geri sayım aktif
  int  _countdownValue = 3;

  // ── HIIT & Interval Config (E) ────────────────────────────────

  /// Sadece HIIT antrenmanı için interval konfigürasyon.
  /// Diğer egzersizler (Kalistenik, Güç, Yüzme vb.) interval göstergesi kullanmaz.
  static const Map<String, _IntervalConfig> _intervalConfigs = {
    'hiit': _IntervalConfig(
      workSecs:  40, restSecs:  20,
      workLabel: 'ÇALİŞ', restLabel: 'DİNLEN',
      workIcon:  Icons.directions_run_rounded,
      restIcon:  Icons.self_improvement_rounded,
    ),
  };

  _IntervalConfig? get _intervalCfg {
    final name = widget.exerciseName.toLowerCase();
    for (final key in _intervalConfigs.keys) {
      if (name.contains(key)) return _intervalConfigs[key]!;
    }
    return null;
  }

  bool get _hasIntervals => _intervalCfg != null;

  // Interval çalışma durumu (initState'de cfg'ye göre güncellenir)
  int  _intervalPhaseRemaining = 40;
  bool _intervalIsWorking      = true;
  int  _intervalRound          = 1;

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Milestones ────────────────────────────────────────────────
  bool _halfwayNotified = false;
  bool _quarterNotified = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds    = _parseDuration(widget.durationStr);
    _remainingSeconds = _totalSeconds;

    // Interval başlangıç değerini egzersiz tipine göre ayarla
    final cfg = _intervalCfg;
    if (cfg != null) {
      _intervalPhaseRemaining = cfg.workSecs;
    }

    // Ekranı açık tut
    WakelockPlus.enable();

    // Nabiz animasyonu
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3-2-1 Geri sayımı başlat (G)
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ── Yardımcı: "30 dk" → 1800 saniye ─────────────────────────
  int _parseDuration(String str) {
    if (str == '—' || str == '-' || str.trim().isEmpty) return 0;
    final match = RegExp(r'(\d+)').firstMatch(str);
    final minutes = match != null ? int.parse(match.group(1)!) : 20;
    return minutes * 60;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress =>
      _totalSeconds > 0 ? (_totalSeconds - _remainingSeconds) / _totalSeconds : 0;

  // ── Timer Logic ───────────────────────────────────────────────

  /// 3-2-1 geri sayım, sonra asıl timer başlar (G)
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdownValue > 1) {
        HapticFeedback.lightImpact();
        setState(() => _countdownValue--);
      } else {
        _timer?.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _isCountingDown = false;
          _countdownValue = 0;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      if (_remainingSeconds <= 0) {
        _onFinished();
        return;
      }

      bool phaseChanged = false;
      bool nowWorking   = true;

      setState(() {
        _remainingSeconds--;
        if (_hasIntervals) {
          _intervalPhaseRemaining--;
          if (_intervalPhaseRemaining <= 0) {
            _intervalIsWorking = !_intervalIsWorking;
            final cfg = _intervalCfg!;
            _intervalPhaseRemaining =
                _intervalIsWorking ? cfg.workSecs : cfg.restSecs;
            if (_intervalIsWorking) _intervalRound++;
            phaseChanged = true;
            nowWorking   = _intervalIsWorking;
          }
        }
      });

      // ── Ses + titreşim setState DIŞINDA ─────────────────────────
      if (phaseChanged) {
        _playIntervalPhaseSound(toWork: nowWorking);
      }

      _checkMilestones();
    });
  }

  /// Çalış → Dinlen : bildirim çını (yumuşak)
  /// Dinlen → Çalış : alarm sesi (güçlü)
  void _playIntervalPhaseSound({required bool toWork}) {
    if (toWork) {
      HapticFeedback.heavyImpact();
      FlutterRingtonePlayer().playAlarm();
    } else {
      HapticFeedback.mediumImpact();
      FlutterRingtonePlayer().playNotification();
    }
  }

  void _checkMilestones() {
    final pct = _progress;
    // %50 — hafif titreşim
    if (!_halfwayNotified && pct >= 0.50) {
      _halfwayNotified = true;
      HapticFeedback.lightImpact();
    }
    // %75 — orta titreşim
    if (!_quarterNotified && pct >= 0.75) {
      _quarterNotified = true;
      HapticFeedback.mediumImpact();
    }
    // Son 10 saniye — hızlı titreşim + bip
    if (_remainingSeconds == 10) {
      HapticFeedback.heavyImpact();
      FlutterRingtonePlayer().playNotification();
    }
  }

  Future<void> _onFinished() async {
    _timer?.cancel();
    setState(() => _isFinished = true);
    // Güçlü titreşim + sistem bildirim sesi
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();
    FlutterRingtonePlayer().playNotification();
    if (mounted) _showCompletionDialog();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    HapticFeedback.lightImpact();
  }

  // ── Yarıda Bırakma ────────────────────────────────────────────
  Future<void> _onQuit() async {
    _timer?.cancel();

    final completedSeconds = _totalSeconds - _remainingSeconds;
    final completedPct = (completedSeconds / _totalSeconds * 100).round();

    final quit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuitConfirmDialog(
        completedPct: completedPct,
        exerciseName: widget.exerciseName,
      ),
    );

    if (!mounted) return;

    if (quit == true) {
      // "Zor mu geldi?" sorusu
      final isTooHard = await showDialog<bool>(
        context: context,
        builder: (ctx) => _TooHardDialog(exerciseName: widget.exerciseName),
      );

      if (!mounted) return;

      if (isTooHard == true) {
        // Kullanıcı zordu dedi → her zaman prefer_easy_mode = true yap
        final prefs = await SharedPreferences.getInstance();
        final prevCount = prefs.getInt('hard_quit_count') ?? 0;
        await prefs.setInt('hard_quit_count', prevCount + 1);
        await prefs.setBool('prefer_easy_mode', true);  // ← her zaman true
      }

      // Ekrana kalan süreyi ve tamamlama bilgisini döndür
      if (mounted) {
        Navigator.of(context).pop(WorkoutResult(
          completed: false,
          completedSeconds: completedSeconds,
          totalSeconds: _totalSeconds,
          markedTooHard: isTooHard ?? false,
        ));
      }
    } else {
      // İptal ettiyse timer'ı temizçe yeniden başlat
      _timer?.cancel();
      _startTimer();
    }
  }

  // ── Tamamlama Dialog ──────────────────────────────────────────
  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompletionDialog(
        exerciseName: widget.exerciseName,
        exerciseIcon: widget.exerciseIcon,
        exerciseType: widget.exerciseName,
        totalSeconds: _totalSeconds,
        accentColor: widget.accentColor,
        onClose: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop(WorkoutResult(
            completed: true,
            completedSeconds: _totalSeconds,
            totalSeconds: _totalSeconds,
            markedTooHard: false,
          ));
        },
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    final timeStr = _formatTime(_remainingSeconds);
    final isLastTen = _remainingSeconds <= 10 && !_isFinished;

    // 3-2-1 Geri sayım ekranı (G)
    if (_isCountingDown) {
      return Scaffold(
        backgroundColor: AksaColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(widget.exerciseIcon,
                  style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              Text(
                widget.exerciseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AksaColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 48),
              TweenAnimationBuilder<double>(
                key: ValueKey(_countdownValue),
                tween: Tween(begin: 1.4, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Text(
                  '$_countdownValue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hazırlan...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AksaColors.textMuted, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AksaColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onQuit,
                    icon: const Icon(Icons.close_rounded,
                        color: AksaColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    widget.exerciseName,
                    style: const TextStyle(
                        color: AksaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Egzersiz İkonu + Yoğunluk ─────────────────────
            const SizedBox(height: 8),
            Text(widget.exerciseIcon,
                style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(widget.intensity,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),

            // ── Progress Ring + Timer ──────────────────────────
            const Spacer(),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: (_isPaused || _isFinished) ? 1.0 : _pulseAnim.value,
                child: child,
              ),
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress daire
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _progress),
                        duration: const Duration(milliseconds: 500),
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          backgroundColor:
                              AksaColors.surfaceElevated,
                          color: isLastTen
                              ? AksaColors.riskHigh
                              : color,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    // Timer text
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: isLastTen
                                ? AksaColors.riskHigh
                                : AksaColors.textPrimary,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                          child: Text(timeStr),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isPaused
                              ? 'Duraklatıldı'
                              : _isFinished
                                  ? 'Tamamlandı! 🎉'
                                  : 'Kalan Süre',
                          style: const TextStyle(
                              color: AksaColors.textMuted,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Interval Göstergesi — tüm desteklenen egzersizler (E) ──
            if (_hasIntervals && !_isFinished && !_isPaused) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(builder: (_) {
                    final cfg = _intervalCfg!;
                    final isWorking = _intervalIsWorking;
                    final phaseColor =
                        isWorking ? AksaColors.riskHigh : AksaColors.accent;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: phaseColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isWorking ? cfg.workIcon : cfg.restIcon,
                            color: phaseColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isWorking ? cfg.workLabel : cfg.restLabel,
                            style: TextStyle(
                              color: phaseColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_intervalPhaseRemaining}sn',
                            style: TextStyle(
                                color: phaseColor, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Text(
                    'Tur $_intervalRound',
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],

            // ── Motivasyon Mesajı ──────────────────
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _motivationText(),
                key: ValueKey(_motivationText()),
                style: const TextStyle(
                    color: AksaColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // ── Butonlar ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                children: [
                  // Durdur / Devam Et
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isFinished ? null : _togglePause,
                      icon: Icon(
                        _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(_isPaused ? 'Devam Et' : 'Duraklat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bırak
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isFinished ? null : _onQuit,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Bitir'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AksaColors.riskHigh.withValues(alpha: 0.15),
                        foregroundColor: AksaColors.riskHigh,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _motivationText() {
    if (_isFinished) return '🎉 Mükemmel iş çıkardın!';
    if (_isPaused) return '⏸ Hazır olduğunda devam et…';
    final pct = _progress;
    if (pct < 0.1) return '💪 Haydi, başlıyoruz!';
    if (pct < 0.4) return '🔥 Harika gidiyorsun, tempo koru!';
    if (pct < 0.6) return '⚡ Yarı yoldasın, pes etme!';
    if (pct < 0.8) return '🚀 Az kaldı, tam gaz devam!';
    return '🏁 Bitmek üzere, son ivmeyi ver!';
  }
}

// ─────────────────────────────────────────────────────────────────
//  Sonuç Nesnesi — Navigator.pop ile geri döner
// ─────────────────────────────────────────────────────────────────
class WorkoutResult {
  final bool completed;
  final int completedSeconds;
  final int totalSeconds;
  final bool markedTooHard;

  const WorkoutResult({
    required this.completed,
    required this.completedSeconds,
    required this.totalSeconds,
    required this.markedTooHard,
  });

  int get remainingSeconds => totalSeconds - completedSeconds;
  int get remainingMinutes => (remainingSeconds / 60).ceil();
}

// ─────────────────────────────────────────────────────────────────
//  Çıkış Onay Dialogu
// ─────────────────────────────────────────────────────────────────
class _QuitConfirmDialog extends StatelessWidget {
  final int completedPct;
  final String exerciseName;

  const _QuitConfirmDialog(
      {required this.completedPct, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AksaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Antrenmanı Bırak?',
          style: TextStyle(color: AksaColors.textPrimary, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Antrenmanın %$completedPct\'ini tamamladın.',
            style: const TextStyle(
                color: AksaColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Bırakmak istediğine emin misin?',
            style: TextStyle(color: AksaColors.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Devam Et',
              style: TextStyle(color: AksaColors.primary)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
              backgroundColor: AksaColors.riskHigh.withValues(alpha: 0.2),
              foregroundColor: AksaColors.riskHigh),
          child: const Text('Bırak'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Zorluk Sorusu Dialogu
// ─────────────────────────────────────────────────────────────────
class _TooHardDialog extends StatelessWidget {
  final String exerciseName;
  const _TooHardDialog({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AksaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nasıl Hissediyorsun?',
          style: TextStyle(color: AksaColors.textPrimary, fontSize: 18)),
      content: const Text(
        'Bu antrenman sana zor mu geldi?',
        style: TextStyle(color: AksaColors.textSecondary, fontSize: 14),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hayır, vaktim yoktu',
              style: TextStyle(color: AksaColors.textMuted, fontSize: 12)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
              backgroundColor: AksaColors.riskMedium.withValues(alpha: 0.2),
              foregroundColor: AksaColors.riskMedium),
          child: const Text('Evet, zordu'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tamamlama Dialogu
// ─────────────────────────────────────────────────────────────────
class _CompletionDialog extends StatelessWidget {
  final String exerciseName;
  final String exerciseIcon;
  final String exerciseType;   // Tip bazlı kalori için
  final int totalSeconds;
  final Color accentColor;
  final VoidCallback onClose;

  // Egzersiz tipine göre kcal/dakika (exercise_screen ile aynı)
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

  const _CompletionDialog({
    required this.exerciseName,
    required this.exerciseIcon,
    required this.exerciseType,
    required this.totalSeconds,
    required this.accentColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final minutes    = totalSeconds ~/ 60;
    final kcalPerMin = _kcalPerMin[exerciseType] ?? 5;
    final kcal       = minutes * kcalPerMin;

    return AlertDialog(
      backgroundColor: AksaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('🎉', style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('Antrenman Tamamlandı!',
              style: TextStyle(
                  color: AksaColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '$exerciseIcon $exerciseName',
            style: const TextStyle(
                color: AksaColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(label: 'Süre', value: '$minutes dk',
                  color: accentColor),
              _StatChip(label: 'Kalori', value: '~$kcal kcal',
                  color: AksaColors.riskMedium),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Harika! 💪',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AksaColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Interval antrenman konfigürasyonu
@immutable
class _IntervalConfig {
  final int workSecs;
  final int restSecs;
  final String workLabel;
  final String restLabel;
  final IconData workIcon;
  final IconData restIcon;

  const _IntervalConfig({
    required this.workSecs,
    required this.restSecs,
    required this.workLabel,
    required this.restLabel,
    required this.workIcon,
    required this.restIcon,
  });
}
