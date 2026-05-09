from fastapi import APIRouter, HTTPException, Depends
from ...schemas.profile import HealthProfileRequest, HealthProfileResponse
from ...services import profile_service
from ..dependencies import get_current_user_id

router = APIRouter(prefix="/profile", tags=["Profile"])


@router.post("/health", response_model=HealthProfileResponse, status_code=200)
async def save_profile(
    body: HealthProfileRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Sağlık profilini oluştur veya güncelle (UPSERT)."""
    return await profile_service.save_health_profile(user_id, body)


@router.get("/health", response_model=HealthProfileResponse)
async def get_profile(user_id: str = Depends(get_current_user_id)):
    """Kullanıcının sağlık profilini getir."""
    return await profile_service.get_health_profile(user_id)
