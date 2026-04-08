from fastapi import APIRouter, Header, HTTPException
from ...schemas.auth import (
    RegisterRequest, RegisterResponse,
    LoginRequest, LoginResponse,
    VerifyEmailRequest, ResendCodeRequest,
    GoogleLoginRequest, GoogleLoginResponse,
    MessageResponse,
)
from ...services import auth_service
from ...core.security import decode_access_token

router = APIRouter(prefix="/auth", tags=["Auth"])

def _get_user_id(authorization: str) -> str:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    return user_id

@router.post("/register", response_model=RegisterResponse, status_code=201)
async def register(body: RegisterRequest):
    """Yeni kullanıcı oluştur ve doğrulama maili gönder."""
    user = await auth_service.register_user(
        full_name=body.full_name,
        email=body.email,
        password=body.password,
    )
    return RegisterResponse(user=user)


@router.post("/login", response_model=LoginResponse)
async def login(body: LoginRequest):
    """Kullanıcı girişi — JWT access token döner."""
    token, user = await auth_service.login_user(
        email=body.email,
        password=body.password,
    )
    return LoginResponse(access_token=token, user=user)


@router.post("/verify-email", response_model=LoginResponse)
async def verify_email(body: VerifyEmailRequest):
    """6 haneli OTP kodunu doğrula ve giriş yap (Token döner)."""
    token, user = await auth_service.verify_email(
        user_id=body.user_id,
        code=body.code,
    )
    return LoginResponse(access_token=token, user=user)


@router.post("/resend-code", response_model=MessageResponse)
async def resend_code(body: ResendCodeRequest):
    """Yeni OTP kodu gönder."""
    await auth_service.resend_otp(user_id=body.user_id)
    return MessageResponse(message="Yeni doğrulama kodu gönderildi.")

@router.delete("/delete-account", response_model=MessageResponse)
async def delete_account(authorization: str = Header(...)):
    """Kullanıcının hesabını ve bağlı tüm verilerini kalıcı olarak siler."""
    user_id = _get_user_id(authorization)
    await auth_service.delete_user(user_id)
    return MessageResponse(message="Hesabınız başarıyla silindi.")


@router.post("/google", response_model=GoogleLoginResponse)
async def google_login(body: GoogleLoginRequest):
    """Google idToken ile giriş yap veya otomatik hesap oluştur."""
    token, user, is_new = await auth_service.google_login(id_token_str=body.id_token)
    return GoogleLoginResponse(access_token=token, user=user, is_new=is_new)
