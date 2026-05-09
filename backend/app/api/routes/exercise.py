from fastapi import APIRouter, Header, HTTPException, Query, Depends
import logging
from pydantic import BaseModel
from ...schemas.exercise import ExerciseResponse
from ...services import exercise_service
from ...core.database import get_pool
from ..dependencies import get_current_user_id
import datetime

_logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/exercise",
    tags=["Exercise"]
)

# Egzersiz tipine göre kcal/dakika katsayısı — tip bazlı doğru kalori hesabı
_KCAL_PER_MIN: dict[str, int] = {
    "HIIT Kardiyo":        12,
    "Güç Antrenmanı":       8,
    "Bisiklet / Spinning":  7,
    "Yüzme":                9,
    "Kalistenik":           6,
    "Tempolu Yürüyüş":      4,
    "Yoga & Esneme":        3,
    "Aktif Dinlenme":       1,
}


@router.get("/summary", response_model=ExerciseResponse)
async def get_exercise_summary(
    user_id: str = Depends(get_current_user_id),
    difficulty: str = Query(
        default="normal",
        pattern="^(normal|easy)$",
        description="Zorluk seviyesi: 'normal' veya 'easy' (Bugün Yorgunum).",
    ),
):
    """
    Kullanıcının sağlık profiline göre kişisel leştirilmiş egzersiz planını döner.

    - **difficulty=normal** : Standart plan (varsayılan)
    - **difficulty=easy**   : Hafifletilmiş plan (kullanıcı yorgun / wearable verisi kötü)

    Token zorunludur — profil veritabanından kullanıcıya özel çekilir.
    """
    data = await exercise_service.get_user_exercise_plan(user_id, difficulty=difficulty)
    return ExerciseResponse(**data)


# ─────────────────────────────────────────────────────────────────────────────
#  Antrenman Tamamlama / Kaydetme
# ─────────────────────────────────────────────────────────────────────────────

class CompleteSessionRequest(BaseModel):
    exercise_name: str
    duration_seconds: int
    calories_burned: int       # frontend tahmini (fallback olarak kullanılır)
    completed: bool            # True → tam tamamlandı, False → yarıda bırakıldı
    marked_too_hard: bool = False


class CompleteSessionResponse(BaseModel):
    success: bool
    message: str
    total_active_minutes_today: int
    total_calories_today: int


@router.post("/complete-session", response_model=CompleteSessionResponse)
async def complete_workout_session(
    body: CompleteSessionRequest,
    user_id: str = Depends(get_current_user_id),
):
    """
    Kullanıcı antrenmanı tamamladığında veya yarıda bıraktığında çağrılır.
    Kalori, egzersiz tipine göre backend'de hesaplanır (tip bazlı kcal/dk).
    daily_wearable_logs tablosundaki active_minutes ve calories_burned güncellenir.
    """
    pool  = await get_pool()
    today = datetime.date.today()

    duration_minutes = max(1, body.duration_seconds // 60)

    # B21: Kullanıcı ağırlığını çek — MET tabanlı kalori hesabı
    # kcal = MET × kg × saat (standart spor fizyoloji formülü)
    weight_row = await pool.fetchrow(
        "SELECT weight_kg FROM health_profiles WHERE user_id = $1 LIMIT 1", user_id
    )
    weight_kg = float(weight_row["weight_kg"]) if weight_row and weight_row["weight_kg"] else 70.0

    # MET değerleri (tip başına kcal/dk/kg × 60 yerine MET değeri)
    _MET_VALUES: dict[str, float] = {
        "HIIT Kardiyo":        10.0,
        "Güç Antrenmanı":       6.0,
        "Bisiklet / Spinning":  7.0,
        "Yüzme":                8.0,
        "Kalistenik":           5.0,
        "Tempolu Yürüyüş":      3.5,
        "Yoga & Esneme":        2.5,
        "Aktif Dinlenme":       1.5,
    }
    met = _MET_VALUES.get(body.exercise_name, 4.0)
    # Formul: kcal = MET × kg × (süre / 60)
    computed_kcal = round(met * weight_kg * (duration_minutes / 60))

    # Frontend değeri 0 ise backend değerini, değilse ikisinin büyüğünü al
    final_kcal = max(body.calories_burned, computed_kcal)

    try:
        # UPSERT — günlük toplam üzerine ekle
        await pool.execute(
            """
            INSERT INTO daily_wearable_logs (user_id, log_date, active_minutes, calories_burned)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (user_id, log_date) DO UPDATE
            SET active_minutes  = daily_wearable_logs.active_minutes  + EXCLUDED.active_minutes,
                calories_burned = daily_wearable_logs.calories_burned + EXCLUDED.calories_burned
            """,
            user_id, today, duration_minutes, final_kcal,
        )

        # Güncel toplam değerleri al (response için)
        row = await pool.fetchrow(
            "SELECT active_minutes, calories_burned FROM daily_wearable_logs "
            "WHERE user_id=$1 AND log_date=$2",
            user_id, today,
        )
        new_minutes  = int(row["active_minutes"])  if row else duration_minutes
        new_calories = int(row["calories_burned"]) if row else final_kcal

    except Exception as e:
        _logger.error("[Exercise] complete-session DB hatası: %s", e, exc_info=True)
        raise HTTPException(status_code=503, detail="Antrenman kaydedilemedi, lütfen tekrar deneyin.")

    session_status = "tamamlandı" if body.completed else "yarıda bırakıldı"
    return CompleteSessionResponse(
        success=True,
        message=f"'{body.exercise_name}' antrenmanı {session_status} ve kaydedildi.",
        total_active_minutes_today=new_minutes,
        total_calories_today=new_calories,
    )
