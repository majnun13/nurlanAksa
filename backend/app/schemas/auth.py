from pydantic import BaseModel, EmailStr


# ── Request şemaları ──────────────────────────────────────────
class RegisterRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class VerifyEmailRequest(BaseModel):
    user_id: str
    code: str


class ResendCodeRequest(BaseModel):
    user_id: str


class GoogleLoginRequest(BaseModel):
    id_token: str


# ── Response şemaları ─────────────────────────────────────────
class UserResponse(BaseModel):
    id: str
    full_name: str
    email: str
    is_email_verified: bool
    onboarding_done: bool


class RegisterResponse(BaseModel):
    user: UserResponse
    message: str = "Doğrulama kodu e-posta adresinize gönderildi."


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class GoogleLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    is_new: bool = False


class MessageResponse(BaseModel):
    message: str
