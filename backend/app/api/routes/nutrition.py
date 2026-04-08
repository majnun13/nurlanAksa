from fastapi import APIRouter, Header, HTTPException, UploadFile, File, Form
from ...schemas.nutrition import (
    NutritionPredictResponse,
    NutritionCalculateRequest,
    NutritionCalculateResponse,
    FoodSearchResponse,
    MealLogRequest,
    MealLogResponse,
)
from ...services import nutrition_service
from ...services import nutrition_target_service
from ...core.security import decode_access_token
from ...core.database import get_pool

router = APIRouter(prefix="/nutrition", tags=["Nutrition"])


def _get_user_id(authorization: str) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    return user_id


@router.get("/targets")
async def get_nutrition_targets(authorization: str = Header(...)):
    """
    Kullanıcının sağlık profiline göre kişiselleştirilmiş
    kalori ve makro hedeflerini döner (Mifflin-St Jeor formülü).
    """
    user_id = _get_user_id(authorization)
    targets = await nutrition_target_service.get_user_nutrition_targets(user_id)
    return targets


@router.post("/predict", response_model=NutritionPredictResponse)
async def predict_food(
    image: UploadFile = File(...),
    gram: float = Form(default=0),
    authorization: str = Header(...),
):
    """Fotoğraftan yemek tahmini yap ve (opsiyonel) besin değerlerini hesapla."""
    _get_user_id(authorization)

    image_bytes = await image.read()
    result = nutrition_service.predict_food(image_bytes)

    response = NutritionPredictResponse(
        predicted_food=result["predicted_food"],
        confidence=result["confidence"],
        top5=result["top5"],
    )

    # Gram verilmişse besin değerlerini de hesapla
    if gram > 0:
        nutrition = await nutrition_service.get_nutrition_for_food(
            result["predicted_food"], gram
        )
        if nutrition:
            response.gram = gram
            response.protein = nutrition["protein"]
            response.carbs = nutrition["carbs"]
            response.fat = nutrition["fat"]
            response.calories = nutrition["calories"]

    return response


@router.post("/calculate", response_model=NutritionCalculateResponse)
async def calculate_nutrition(
    body: NutritionCalculateRequest,
    authorization: str = Header(...),
):
    """Yemek adı ve gram miktarına göre besin değerlerini hesapla."""
    _get_user_id(authorization)

    result = await nutrition_service.get_nutrition_for_food(body.food_name, body.gram)
    if not result:
        raise HTTPException(
            status_code=404,
            detail=f"'{body.food_name}' besin tablosunda bulunamadı.",
        )

    return NutritionCalculateResponse(**result)


@router.get("/foods", response_model=FoodSearchResponse)
async def search_foods(
    q: str = "",
    authorization: str = Header(...),
):
    """Yemek adına göre arama yap."""
    _get_user_id(authorization)

    foods = await nutrition_service.search_foods(q)
    return FoodSearchResponse(foods=foods)


@router.post("/meals", response_model=MealLogResponse, status_code=201)
async def log_meal(
    body: MealLogRequest,
    authorization: str = Header(...),
):
    """Öğün kaydı oluştur."""
    user_id = _get_user_id(authorization)
    pool = await get_pool()

    row = await pool.fetchrow(
        """
        INSERT INTO meal_logs (user_id, food_name, meal_type, gram, protein, carbs, fat, calories)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id, user_id, food_name, meal_type, gram, protein, carbs, fat, calories, created_at
        """,
        user_id,
        body.food_name,
        body.meal_type,
        body.gram,
        body.protein,
        body.carbs,
        body.fat,
        body.calories,
    )

    return MealLogResponse(
        id=str(row["id"]),
        user_id=str(row["user_id"]),
        food_name=row["food_name"],
        meal_type=row["meal_type"],
        gram=float(row["gram"]),
        protein=float(row["protein"]),
        carbs=float(row["carbs"]),
        fat=float(row["fat"]),
        calories=float(row["calories"]),
        created_at=str(row["created_at"]),
    )


@router.get("/meals", response_model=list[MealLogResponse])
async def get_meals_today(
    authorization: str = Header(...),
):
    """Bugünkü öğün kayıtlarını getir."""
    user_id = _get_user_id(authorization)
    pool = await get_pool()

    rows = await pool.fetch(
        """
        SELECT id, user_id, food_name, meal_type, gram, protein, carbs, fat, calories, created_at
        FROM meal_logs
        WHERE user_id = $1 AND created_at::date = CURRENT_DATE
        ORDER BY created_at ASC
        """,
        user_id,
    )

    return [
        MealLogResponse(
            id=str(r["id"]),
            user_id=str(r["user_id"]),
            food_name=r["food_name"],
            meal_type=r["meal_type"],
            gram=float(r["gram"]),
            protein=float(r["protein"]),
            carbs=float(r["carbs"]),
            fat=float(r["fat"]),
            calories=float(r["calories"]),
            created_at=str(r["created_at"]),
        )
        for r in rows
    ]
