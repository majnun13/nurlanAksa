from typing import Optional
from pydantic import BaseModel


class HealthProfileRequest(BaseModel):
    age: Optional[int] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    gender: Optional[str] = None
    lifestyle: Optional[str] = None       # 'Sedanter' | 'Orta' | 'Aktif'
    health_goal: Optional[str] = None     # 'lose_weight' | 'maintain' | 'gain_weight'
    dietary_restrictions: Optional[list[str]] = None
    medical_conditions: Optional[list[str]] = None
    medications: Optional[str] = None


class HealthProfileResponse(BaseModel):
    id: str
    user_id: str
    age: Optional[int]
    weight_kg: Optional[float]
    height_cm: Optional[float]
    gender: Optional[str]
    lifestyle: Optional[str]
    health_goal: Optional[str]
    dietary_restrictions: list[str]
    medical_conditions: list[str]
    medications: Optional[str] = None
