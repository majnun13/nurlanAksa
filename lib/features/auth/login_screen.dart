import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/repositories/auth_repository.dart';
import 'email_verification_screen.dart';
import '../shell/shell_screen.dart';
import '../onboarding/health_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _termsAccepted = false; // Kullanım koşulları onayı

  final _authRepo = AuthRepository();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _showError('E-posta ve şifre alanlarını doldurun.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _authRepo.login(email: email, password: pass);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ShellScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _showError('Tüm alanları doldurun.');
      return;
    }
    // E-posta format kontrolü
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Geçerli bir e-posta adresi girin.');
      return;
    }
    if (pass != confirm) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }
    if (pass.length < 8) {
      _showError('Şifre en az 8 karakter olmalıdır.');
      return;
    }
    if (!_termsAccepted) {
      _showError('Devam etmek için kullanım koşullarını kabul etmeniz gerekiyor.');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) Kullanıcıyı oluştur (Backend otomatik olarak doğrulama maili gönderir)
      final user = await _authRepo.register(
        fullName: name,
        email: email,
        password: pass,
      );
      
      if (!mounted) return;
      // 3) Doğrulama ekranına geç
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              EmailVerificationScreen(user: user),
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AksaColors.riskHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      final result = await _authRepo.googleSignIn();
      if (!mounted) return;

      final bool isNew = result['isNew'] as bool;

      if (isNew) {
        // Yeni kullanıcı → Onboarding
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HealthProfileScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        // Mevcut kullanıcı → Ana ekran
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ShellScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      body: Stack(
        children: [
          // ── Background glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AksaColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AksaColors.secondary.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // ── Logo
                  _buildLogo(),

                  const SizedBox(height: 40),

                  // ── Tab selector
                  _buildTabSelector(),

                  const SizedBox(height: 32),

                  // ── Forms
                  AnimatedBuilder(
                    animation: _tab,
                    builder: (_, __) => _tab.index == 0
                        ? _buildLoginForm()
                        : _buildRegisterForm(),
                  ),

                  const SizedBox(height: 24),

                  // ── Divider
                  _buildDivider(),

                  const SizedBox(height: 24),

                  // ── Social login (placeholder)
                  _buildSocialButtons(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Loading overlay
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AksaColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: AksaColors.gradPrimary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AksaColors.primary.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'AKSA',
          style: TextStyle(
            color: AksaColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Akıllı Kişisel Sağlık Asistanınıza Hoş Geldiniz',
          style: TextStyle(color: AksaColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AksaColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          gradient: AksaColors.gradPrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: Colors.white,
        unselectedLabelColor: AksaColors.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Giriş Yap'),
          Tab(text: 'Kaydol'),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AksaTextField(
          controller: _emailCtrl,
          label: 'E-posta',
          hint: 'ornek@mail.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _AksaTextField(
          controller: _passCtrl,
          label: 'Şifre',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: _obscurePass,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
            icon: Icon(
              _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AksaColors.textMuted,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _showError('Şifremi unuttum özelliği yakında eklenecek. '
                  'Hesabınızı silip yeniden oluşturabilirsiniz.');
            },
            child: const Text(
              'Şifremi Unuttum',
              style: TextStyle(color: AksaColors.primaryLight, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildPrimaryButton('Giriş Yap', _handleLogin),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _AksaTextField(
          controller: _nameCtrl,
          label: 'Ad Soyad',
          hint: 'Yavuz Selim',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _AksaTextField(
          controller: _emailCtrl,
          label: 'E-posta',
          hint: 'ornek@mail.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _AksaTextField(
          controller: _passCtrl,
          label: 'Şifre',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: _obscurePass,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
            icon: Icon(
              _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AksaColors.textMuted,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AksaTextField(
          controller: _confirmCtrl,
          label: 'Şifre Tekrar',
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            icon: Icon(
              _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AksaColors.textMuted,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              activeColor: AksaColors.primary,
              side: const BorderSide(color: AksaColors.textMuted),
            ),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AksaColors.textMuted, fontSize: 12),
                  children: [
                    TextSpan(text: 'Gizlilik Politikası ve '),
                    TextSpan(
                      text: 'Kullanım Koşullarını',
                      style: TextStyle(color: AksaColors.primaryLight),
                    ),
                    TextSpan(text: ' kabul ediyorum.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton('Hesap Oluştur', _handleRegister),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
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
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'veya',
            style: TextStyle(color: AksaColors.textMuted.withOpacity(0.8), fontSize: 13),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _SocialButton(
          icon: 'G',
          label: 'Google ile Devam Et',
          onTap: _handleGoogleLogin,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: '🍎',
          label: 'Apple ile Devam Et',
          onTap: () {
            _showError('Apple ile giriş yakında eklenecek.');
          },
          isApple: true,
        ),
      ],
    );
  }
}

// ── Reusable text field
class _AksaTextField extends StatelessWidget {
  const _AksaTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AksaColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: AksaColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AksaColors.textMuted, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

// ── Social button
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isApple = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isApple;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AksaColors.surfaceCard,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isApple
                ? Text(icon, style: const TextStyle(fontSize: 18))
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      icon,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AksaColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
