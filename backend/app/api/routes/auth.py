from fastapi import APIRouter
from ...schemas.auth import (
    RegisterRequest, RegisterResponse,
    LoginRequest, LoginResponse,
    VerifyEmailRequest, ResendCodeRequest,
    MessageResponse,
)
from ...services import auth_service

router = APIRouter(prefix="/auth", tags=["Auth"])


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
