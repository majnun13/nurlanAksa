from typing import Optional
from pydantic import BaseModel


class NutritionPredictResponse(BaseModel):
    predicted_food: str
    confidence: float
    top5: list[dict]  # [{"label": str, "confidence": float}]
    gram: Optional[float] = None
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fat: Optional[float] = None
    calories: Optional[float] = None


class NutritionCalculateRequest(BaseModel):
    food_name: str
    gram: float


class NutritionCalculateResponse(BaseModel):
    food_name: str
    gram: float
    protein: float
    carbs: float
    fat: float
    calories: float


class FoodItem(BaseModel):
    name: str
    protein_per_100g: Optional[float]
    carbs_per_100g: Optional[float]
    fat_per_100g: Optional[float]
    calories_per_100g: Optional[float]


class FoodSearchResponse(BaseModel):
    foods: list[FoodItem]


class MealLogRequest(BaseModel):
    food_name: str
    meal_type: str  # 'Kahvaltı' | 'Öğle' | 'Akşam' | 'Ara öğün'
    gram: float
    protein: float
    carbs: float
    fat: float
    calories: float


class MealLogResponse(BaseModel):
    id: str
    user_id: str
    food_name: str
    meal_type: str
    gram: float
    protein: float
    carbs: float
    fat: float
    calories: float
    created_at: str
