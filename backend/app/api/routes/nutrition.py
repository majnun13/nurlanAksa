from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
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
from ...services import nutrition_report_service
from ...core.database import get_pool
from ..dependencies import get_current_user_id
from datetime import date
import asyncio

router = APIRouter(prefix="/nutrition", tags=["Nutrition"])


# ─────────────────────────────────────────────────────────────────────────────
#  Hedefler & Raporlar
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/targets")
async def get_nutrition_targets(user_id: str = Depends(get_current_user_id)):
    """Kişiselleştirilmiş kalori ve makro hedeflerini döner."""
    return await nutrition_target_service.get_user_nutrition_targets(user_id)


@router.get("/meals/history")
async def get_meals_history(
    target_date: str,
    user_id: str = Depends(get_current_user_id),
):
    """Belirli bir güne ait tüm öğünleri döner. Format: YYYY-MM-DD"""
    try:
        d = date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz tarih formatı. YYYY-MM-DD kullanın.")
    return await nutrition_report_service.get_meals_by_date(user_id, d)


@router.get("/report/weekly")
async def get_weekly_report(user_id: str = Depends(get_current_user_id)):
    """Son 7 günün raporu + ortalamalar + akıllı öneriler."""
    return await nutrition_report_service.get_weekly_report(user_id)


@router.get("/report/monthly")
async def get_monthly_report(user_id: str = Depends(get_current_user_id)):
    """Son 30 günün raporu + ortalamalar + akıllı öneriler."""
    return await nutrition_report_service.get_monthly_report(user_id)


# ─────────────────────────────────────────────────────────────────────────────
#  AI Yemek Tanıma
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/predict", response_model=NutritionPredictResponse)
async def predict_food(
    image: UploadFile = File(...),
    gram: float = Form(default=0),
    user_id: str = Depends(get_current_user_id),
):
    """Fotoğraftan yemek tahmini yap ve (opsiyonel) besin değerlerini hesapla."""
    image_bytes = await image.read()
    # GÜVENLİK: predict_food senkron (ML model) — event loop'u bloke etmemek için executor kullan
    # B7: get_running_loop() kullan (get_event_loop deprecate Python 3.10+)
    loop = asyncio.get_running_loop()
    result = await loop.run_in_executor(None, nutrition_service.predict_food, image_bytes)

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


# ─────────────────────────────────────────────────────────────────────────────
#  Manuel Hesaplama & Arama
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/calculate", response_model=NutritionCalculateResponse)
async def calculate_nutrition(
    body: NutritionCalculateRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Yemek adı ve gram miktarına göre besin değerlerini hesapla."""
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
    user_id: str = Depends(get_current_user_id),
):
    """Yemek adına göre arama yap."""
    foods = await nutrition_service.search_foods(q)
    return FoodSearchResponse(foods=foods)


# ─────────────────────────────────────────────────────────────────────────────
#  Öğün Günlüğü
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/meals", response_model=MealLogResponse, status_code=201)
async def log_meal(
    body: MealLogRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Öğün kaydı oluştur."""
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
    user_id: str = Depends(get_current_user_id),
):
    """Bugünkü öğün kayıtlarını getir."""
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
