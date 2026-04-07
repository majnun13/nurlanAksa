// ─────────────────────────────────────────────────────────────
//  EmailVerificationScreen
//  Kullanıcı kayıt sonrasında e-postasına gelen 6 haneli
//  OTP kodunu buraya girer. Doğrulanınca HealthProfile'a geçer.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../onboarding/health_profile_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _repo = AuthRepository();
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _sending = false;
  int _resendCooldown = 0; // saniye

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode =>
      _ctrls.map((c) => c.text).join();

  // ── Doğrulama ───────────────────────────────────────────────
  Future<void> _verify() async {
    final code = _enteredCode;
    if (code.length < 6) {
      _showError('Lütfen 6 haneli kodu tam girin.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _repo.verifyCode(userId: widget.user.id, code: code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HealthProfileScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
      // Yanlış kodda kutuları temizle
      for (final c in _ctrls) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Kodu tekrar gönder ───────────────────────────────────────
  Future<void> _resend() async {
    if (_resendCooldown > 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendVerificationCode(
        userId: widget.user.id,
        email: widget.user.email,
        userName: widget.user.fullName.split(' ').first,
      );
      if (!mounted) return;
      _showSuccess('Yeni kod gönderildi!');
      _startCooldown();
    } on Exception catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AksaColors.riskHigh,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AksaColors.riskLow,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Glow
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AksaColors.primary.withAlpha(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  // İkon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AksaColors.gradPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AksaColors.primary.withAlpha(90),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mark_email_read_outlined,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'E-postanı Doğrula',
                    style: TextStyle(
                      color: AksaColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.user.email} adresine\n6 haneli doğrulama kodu gönderdik.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AksaColors.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── 6 Kutucuk ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _OtpBox(
                      controller: _ctrls[i],
                      focusNode: _focusNodes[i],
                      onChanged: (val) {
                        if (val.length == 1 && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        }
                        if (val.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    )),
                  ),

                  const SizedBox(height: 32),

                  // ── Doğrula butonu ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _enteredCode.length == 6
                            ? AksaColors.gradPrimary
                            : null,
                        color: _enteredCode.length < 6
                            ? AksaColors.surfaceCard
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _enteredCode.length == 6
                            ? [
                                BoxShadow(
                                  color: AksaColors.primary.withAlpha(90),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: FilledButton(
                        onPressed: _enteredCode.length == 6 && !_loading
                            ? _verify
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'Doğrula ve Devam Et',
                                style: TextStyle(
                                  color: _enteredCode.length == 6
                                      ? Colors.white
                                      : AksaColors.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Tekrar gönder ──────────────────────────
                  TextButton(
                    onPressed: _resendCooldown == 0 && !_sending ? _resend : null,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: AksaColors.primaryLight, strokeWidth: 2),
                          )
                        : Text(
                            _resendCooldown > 0
                                ? 'Tekrar gönder (${_resendCooldown}s)'
                                : 'Kodu Tekrar Gönder',
                            style: const TextStyle(
                              color: AksaColors.primaryLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (_loading)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: AksaColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tek OTP Kutusu ────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(
          color: AksaColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AksaColors.surfaceCard,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AksaColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
