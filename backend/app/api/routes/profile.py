from fastapi import APIRouter, Header, HTTPException
from ...schemas.profile import HealthProfileRequest, HealthProfileResponse
from ...services import profile_service
from ...core.security import decode_access_token

router = APIRouter(prefix="/profile", tags=["Profile"])


def _get_user_id(authorization: str) -> str:
    """Authorization: Bearer <token> header'dan user_id çıkar."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    return user_id


@router.post("/health", response_model=HealthProfileResponse, status_code=200)
async def save_profile(
    body: HealthProfileRequest,
    authorization: str = Header(...),
):
    """Sağlık profilini oluştur veya güncelle (UPSERT)."""
    user_id = _get_user_id(authorization)
    return await profile_service.save_health_profile(user_id, body)


@router.get("/health", response_model=HealthProfileResponse)
async def get_profile(authorization: str = Header(...)):
    """Kullanıcının sağlık profilini getir."""
    user_id = _get_user_id(authorization)
    return await profile_service.get_health_profile(user_id)
