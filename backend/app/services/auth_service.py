import secrets
import logging

_logger = logging.getLogger(__name__)
from fastapi import HTTPException, status
from ..core.database import get_pool
from ..core.security import hash_password, verify_password, create_access_token
from ..core.config import settings
from ..schemas.auth import UserResponse
from .email_service import send_verification_email

# Google token doğrulama
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests


# ── Yardımcı: asyncpg record → dict ──────────────────────────
def _row(record) -> dict:
    return dict(record)


# ── KAYIT ─────────────────────────────────────────────────────
async def register_user(full_name: str, email: str, password: str) -> UserResponse:
    pool = await get_pool()

    # Şifre güçlülüğü kontrolü (backend katmanında da zorunlu)
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Şifre en az 8 karakter olmalıdır.")

    pw_hash = hash_password(password)
    try:
        row = await pool.fetchrow(
            """
            INSERT INTO users (full_name, email, password_hash)
            VALUES ($1, $2, $3)
            ON CONFLICT (email) DO NOTHING
            RETURNING id, full_name, email, is_email_verified, onboarding_done
            """,
            full_name.strip(),
            email.strip().lower(),
            pw_hash,
        )
    except Exception as e:
        _logger.error("register_user DB hatası: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Kullanıcı oluşturulamadı.")

    if not row:
        # ON CONFLICT → e-posta zaten kayıtlı
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu e-posta adresi zaten kayıtlı.",
        )
    user = _row(row)

    # Doğrulama kodu oluştur ve gönder
    await _send_otp(pool, str(user["id"]), email, full_name.split()[0])

    return _to_user_response(user)


# ── GİRİŞ ─────────────────────────────────────────────────────
async def login_user(email: str, password: str) -> tuple[str, UserResponse]:
    pool = await get_pool()

    row = await pool.fetchrow(
        """
        SELECT id, full_name, email, is_active, is_email_verified,
               onboarding_done, password_hash
        FROM users WHERE email = $1 LIMIT 1
        """,
        email.strip().lower(),
    )

    if not row:
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")

    user = _row(row)
    if not verify_password(password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")
    if not user["is_active"]:
        raise HTTPException(status_code=403, detail="Hesabınız devre dışı bırakılmış.")
    if not user["is_email_verified"]:
        raise HTTPException(
            status_code=403,
            detail="E-posta adresinizi doğrulayın. Lütfen gönderdiğimiz kodu girin.",
        )

    # last_login_at güncelle
    await pool.execute(
        "UPDATE users SET last_login_at = NOW() WHERE id = $1", user["id"]
    )

    token = create_access_token(str(user["id"]))
    return token, _to_user_response(user)


# ── E-POSTA DOĞRULAMA ─────────────────────────────────────────
async def verify_email(user_id: str, code: str) -> tuple[str, UserResponse]:
    pool = await get_pool()

    # OTP brute force koruması: 15 dakikada max 5 deneme
    attempt_row = await pool.fetchrow(
        """
        SELECT COUNT(*) AS cnt
        FROM otp_attempts
        WHERE user_id = $1 AND attempted_at > NOW() - INTERVAL '15 minutes'
        """,
        user_id,
    )
    if attempt_row and attempt_row["cnt"] >= 5:
        raise HTTPException(
            status_code=429,
            detail="Çok fazla deneme yapıldı. Lütfen 15 dakika bekleyin."
        )

    # B8: Yalnızca başarısız denemeler sayılmalı; önce token doğrula, sonra kaydet
    row = await pool.fetchrow(
        """
        SELECT id FROM email_verification_tokens
        WHERE user_id = $1 AND token = $2 AND expires_at > NOW()
        LIMIT 1
        """,
        user_id,
        code,
    )
    if not row:
        # Başarısız denemeyi kaydet
        await pool.execute(
            "INSERT INTO otp_attempts (user_id, attempted_at) VALUES ($1, NOW())",
            user_id,
        )
        raise HTTPException(status_code=400, detail="Geçersiz veya süresi dolmuş kod.")

    # Başarılı doğrulama — deneme kayıtlarını temizle
    await pool.execute(
        "DELETE FROM otp_attempts WHERE user_id = $1", user_id
    )
    await pool.execute(
        "UPDATE users SET is_email_verified = TRUE, last_login_at = NOW() WHERE id = $1", user_id
    )
    await pool.execute(
        "DELETE FROM email_verification_tokens WHERE user_id = $1", user_id
    )

    # B3: user_row None olabilir (kullanıcı arada silinmişse)
    user_row = await pool.fetchrow(
        "SELECT id, full_name, email, is_email_verified, onboarding_done FROM users WHERE id = $1",
        user_id
    )
    if not user_row:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")
    user = _row(user_row)
    token = create_access_token(str(user["id"]))

    return token, _to_user_response(user)


# ── OTP TEKRAR GÖNDER ─────────────────────────────────────────
async def resend_otp(user_id: str) -> None:
    pool = await get_pool()
    row = await pool.fetchrow(
        "SELECT email, full_name, is_email_verified FROM users WHERE id = $1", user_id
    )
    if not row:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")
    user = _row(row)
    # GÜVENLİK: Zaten doğrulanmış hesaplara tekrar OTP gönderilmez (mail bombing önleme)
    if user.get("is_email_verified"):
        raise HTTPException(status_code=400, detail="E-posta adresiniz zaten doğrulanmış.")
    await _send_otp(pool, user_id, user["email"], user["full_name"].split()[0])


# ── İÇSEL: OTP oluştur, kaydet, gönder ───────────────────────
async def _send_otp(pool, user_id: str, email: str, first_name: str) -> None:
    # B9: secrets modülü cryptographically secure rastgele sayı üretir
    code = str(secrets.randbelow(900000) + 100000)

    await pool.execute(
        "DELETE FROM email_verification_tokens WHERE user_id = $1", user_id
    )
    await pool.execute(
        """
        INSERT INTO email_verification_tokens (user_id, token, expires_at)
        VALUES ($1, $2, NOW() + INTERVAL '10 minutes')
        """,
        user_id,
        code,
    )
    await send_verification_email(
        to_email=email,
        user_name=first_name,
        code=code,
    )


# ── Yardımcı ─────────────────────────────────────────────────
def _to_user_response(user: dict) -> UserResponse:
    return UserResponse(
        id=str(user["id"]),
        full_name=user["full_name"],
        email=user["email"],
        is_email_verified=user.get("is_email_verified", False),
        onboarding_done=user.get("onboarding_done", False),
    )

async def delete_user(user_id: str) -> None:
    pool = await get_pool()
    try:
        # B10: CASCADE tanımlı olduğu için users'dan silmek her şeyi siler
        await pool.execute("DELETE FROM users WHERE id = $1", user_id)
    except Exception as e:
        _logger.error("delete_user DB hatası user_id=%s: %s", user_id, e, exc_info=True)
        raise HTTPException(status_code=500, detail="Hesap silinirken bir hata oluştu.")


async def google_login(id_token_str: str) -> tuple[str, UserResponse, bool]:
    """
    Google idToken'ı doğrular, kullanıcı yoksa otomatik oluşturur.
    Döner: (jwt_token, user, is_new_user)
    """
    # 1) Google token doğrulama
    try:
        idinfo = google_id_token.verify_oauth2_token(
            id_token_str,
            google_requests.Request(),
            settings.GOOGLE_CLIENT_ID,
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Geçersiz Google token.")

    email = idinfo.get("email", "").lower()
    name = idinfo.get("name", "Google Kullanıcı")
    google_uid = idinfo.get("sub")

    if not email:
        raise HTTPException(status_code=400, detail="Google hesabından e-posta alınamadı.")

    pool = await get_pool()

    # 2) Mevcut kullanıcıyı kontrol et
    row = await pool.fetchrow(
        "SELECT id, full_name, email, is_active, is_email_verified, onboarding_done FROM users WHERE email = $1",
        email,
    )

    is_new = False

    if row:
        # Var olan kullanıcı
        user = _row(row)
        if not user["is_active"]:
            raise HTTPException(status_code=403, detail="Hesabınız devre dışı.")
        # oauth bilgilerini güncelle
        await pool.execute(
            "UPDATE users SET oauth_provider='google', oauth_uid=$2, is_email_verified=TRUE, last_login_at=NOW() WHERE id = $1",
            user["id"], google_uid,
        )
    else:
        # Yeni kullanıcı oluştur (şifresiz, email doğrulanmış)
        row = await pool.fetchrow(
            """
            INSERT INTO users (full_name, email, password_hash, is_email_verified, oauth_provider, oauth_uid, is_active)
            VALUES ($1, $2, $3, TRUE, 'google', $4, TRUE)
            RETURNING id, full_name, email, is_email_verified, onboarding_done
            """,
            name, email, "GOOGLE_OAUTH_NO_PASSWORD", google_uid,
        )
        user = _row(row)
        is_new = True

    token = create_access_token(str(user["id"]))
    return token, _to_user_response(user), is_new
