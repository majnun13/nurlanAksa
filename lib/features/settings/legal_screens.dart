import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/widgets/aksa_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'Gizlilik ve Veri Politikası',
        subtitle: 'Kişisel verileriniz bizim için önemli',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AksaColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Hangi Verileri Topluyoruz?',
              content: 'AKSA, daha iyi bir deneyim sunmak amacıyla boy, kilo, beslenme rutinleriniz, sağlık hedefleriniz ve kronik rahatsızlıklarınız gibi temel sağlık verilerinizi toplar.',
            ),
            _buildSection(
              title: 'Verilerinizi Nasıl Kullanıyoruz?',
              content: 'Toplanan veriler yalnızca size özel beslenme programları ve sağlık analizleri oluşturmak için yapay zeka (MacroVision) modellerimizde işlenir. Profil verileriniz kendi belirlediğiniz hedeflere ulaşmanızı kolaylaştırmak için kullanılır.',
            ),
            _buildSection(
              title: 'Üçüncü Şahıslarla Paylaşım',
              content: 'Kişisel sağlık verileriniz ve uygulama içi kayıtlarınız kesinlikle reklam ajansları veya veri brokerleri ile satılmaz veya paylaşılmaz. Verileriniz tamamen güvenli (şifrelenmiş) sunucularda saklanır.',
            ),
            _buildSection(
              title: 'Veri Silme Hakkı',
              content: 'Uygulama içerisindeki "Hesap" menüsünden dilediğiniz zaman tüm geçmiş sağlık verilerinizi, öğünlerinizi ve hesabınızı kalıcı olarak silebilirsiniz.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AksaColors.primaryLight, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: AksaColors.textSecondary, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AksaColors.bg,
      appBar: AksaAppBar(
        title: 'Güvenlik Bilgileri',
        subtitle: 'Veri güvenliği mimarimiz',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AksaColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              icon: Icons.lock_outline,
              title: 'Uçtan Uca Şifreleme (JWT)',
              content: 'Hesabınıza giriş yaptığınız andan itibaren, sunucu ile cihazınız arasındaki her adım JWT (JSON Web Token) altyapısı ile güvence altındadır.',
            ),
            _buildSection(
              icon: Icons.shield_outlined,
              title: 'Parola Güvenliği (Bcrypt)',
              content: 'Uygulamaya kayıt olurken belirlediğiniz şifreler, düz metin halinde saklanmaz. Gelişmiş Bcrypt algoritmasıyla "hash"lenerek korunur.',
            ),
            _buildSection(
              icon: Icons.cloud_done_outlined,
              title: 'Güvenli Veritabanı Mimarisi',
              content: 'Tüm mobil işlemler direkt olarak sunucu katmanı aracılığıyla (FastAPI) gerçekteşir. Uygulama hiçbir zaman direkt olarak veritabanına açık uçlu bir bağlantı kurmaz.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AksaColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AksaColors.accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AksaColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(color: AksaColors.textSecondary, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
