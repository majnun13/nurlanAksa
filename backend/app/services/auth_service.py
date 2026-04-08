import random
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

    # E-posta zaten var mı?
    existing = await pool.fetchrow(
        "SELECT id FROM users WHERE email = $1", email.lower()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu e-posta adresi zaten kayıtlı.",
        )

    pw_hash = hash_password(password)
    row = await pool.fetchrow(
        """
        INSERT INTO users (full_name, email, password_hash)
        VALUES ($1, $2, $3)
        RETURNING id, full_name, email, is_email_verified, onboarding_done
        """,
        full_name.strip(),
        email.strip().lower(),
        pw_hash,
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
        raise HTTPException(status_code=400, detail="Geçersiz veya süresi dolmuş kod.")

    await pool.execute(
        "UPDATE users SET is_email_verified = TRUE, last_login_at = NOW() WHERE id = $1", user_id
    )
    await pool.execute(
        "DELETE FROM email_verification_tokens WHERE user_id = $1", user_id
    )
    
    # Güncel kullanıcı bilgilerini çek
    user_row = await pool.fetchrow(
        "SELECT id, full_name, email, is_email_verified, onboarding_done FROM users WHERE id = $1",
        user_id
    )
    user = _row(user_row)
    token = create_access_token(str(user["id"]))
    
    return token, _to_user_response(user)


# ── OTP TEKRAR GÖNDER ─────────────────────────────────────────
async def resend_otp(user_id: str) -> None:
    pool = await get_pool()
    row = await pool.fetchrow(
        "SELECT email, full_name FROM users WHERE id = $1", user_id
    )
    if not row:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")
    user = _row(row)
    await _send_otp(pool, user_id, user["email"], user["full_name"].split()[0])


# ── İÇSEL: OTP oluştur, kaydet, gönder ───────────────────────
async def _send_otp(pool, user_id: str, email: str, first_name: str) -> None:
    code = str(random.SystemRandom().randint(100000, 999999))

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
    # CASCADE tanimli oldugu icin users'dan silmek her seyi siler
    await pool.execute("DELETE FROM users WHERE id = $1", user_id)


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
            INSERT INTO users (full_name, email, password_hash, is_email_verified, oauth_provider, oauth_uid)
            VALUES ($1, $2, $3, TRUE, 'google', $4)
            RETURNING id, full_name, email, is_email_verified, onboarding_done
            """,
            name, email, "GOOGLE_OAUTH_NO_PASSWORD", google_uid,
        )
        user = _row(row)
        is_new = True

    token = create_access_token(str(user["id"]))
    return token, _to_user_response(user), is_new
