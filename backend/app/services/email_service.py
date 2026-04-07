import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from ..core.config import settings


async def send_verification_email(
    to_email: str,
    user_name: str,
    code: str,
) -> None:
    """Gmail SMTP ile 6 haneli OTP içeren HTML mail gönderir."""

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "AKSA – E-posta Doğrulama Kodunuz"
    msg["From"] = f"AKSA Sağlık <{settings.SMTP_EMAIL}>"
    msg["To"] = to_email

    html = f"""
<!DOCTYPE html>
<html lang="tr">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#0F172A;font-family:sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table width="480" style="background:#1E293B;border-radius:20px;overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg,#6366F1,#06B6D4);padding:32px;text-align:center;">
              <div style="font-size:36px;">❤️</div>
              <h1 style="color:#fff;margin:8px 0 4px;font-size:24px;letter-spacing:-1px;">AKSA</h1>
              <p style="color:rgba(255,255,255,.75);margin:0;font-size:13px;">Akıllı Kişisel Sağlık Asistanı</p>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;text-align:center;">
              <p style="color:#94A3B8;font-size:15px;margin:0 0 8px;">Merhaba, <strong style="color:#E2E8F0;">{user_name}</strong></p>
              <p style="color:#64748B;font-size:14px;margin:0 0 28px;line-height:1.6;">
                Hesabınızı doğrulamak için aşağıdaki 6 haneli kodu kullanın.<br>
                Kod <strong style="color:#F59E0B;">10 dakika</strong> geçerlidir.
              </p>
              <div style="background:#0F172A;border:2px solid #6366F1;border-radius:16px;padding:24px 0;margin-bottom:28px;">
                <p style="color:#6366F1;font-size:11px;letter-spacing:3px;margin:0 0 8px;text-transform:uppercase;">Doğrulama Kodu</p>
                <p style="color:#E2E8F0;font-size:42px;font-weight:900;letter-spacing:12px;margin:0;">{code}</p>
              </div>
              <p style="color:#475569;font-size:12px;margin:0;">Bu maili siz istemediyseniz güvenle görmezden gelebilirsiniz.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:20px;text-align:center;border-top:1px solid #1E293B;">
              <p style="color:#334155;font-size:11px;margin:0;">© 2026 AKSA – Tüm hakları saklıdır.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""
    msg.attach(MIMEText(html, "html"))

    await aiosmtplib.send(
        msg,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_EMAIL,
        password=settings.SMTP_PASSWORD,
        start_tls=True,
    )
