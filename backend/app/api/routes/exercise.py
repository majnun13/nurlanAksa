from fastapi import APIRouter, Header, HTTPException, Query
from pydantic import BaseModel
from ...schemas.exercise import ExerciseResponse
from ...services import exercise_service
from ...core.security import decode_access_token
from ...core.database import get_pool
import datetime

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


def _get_user_id(authorization: str) -> str:
    """Authorization: Bearer <token> header'dan user_id çıkar."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    return user_id


@router.get("/summary", response_model=ExerciseResponse)
async def get_exercise_summary(
    authorization: str = Header(...),
    difficulty: str = Query(
        default="normal",
        pattern="^(normal|easy)$",
        description="Zorluk seviyesi: 'normal' veya 'easy' (Bugün Yorgunum).",
    ),
):
    """
    Kullanıcının sağlık profiline göre kişiselleştirilmiş egzersiz planını döner.

    - **difficulty=normal** : Standart plan (varsayılan)
    - **difficulty=easy**   : Hafifletilmiş plan (kullanıcı yorgun / wearable verisi kötü)

    Token zorunludur — profil veritabanından kullanıcıya özel çekilir.
    """
    user_id = _get_user_id(authorization)
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
    authorization: str = Header(...),
):
    """
    Kullanıcı antrenmanı tamamladığında veya yarıda bıraktığında çağrılır.
    Kalori, egzersiz tipine göre backend'de hesaplanır (tip bazlı kcal/dk).
    daily_wearable_logs tablosundaki active_minutes ve calories_burned güncellenir.
    """
    user_id = _get_user_id(authorization)
    pool    = await get_pool()
    today   = datetime.date.today()

    duration_minutes = max(1, body.duration_seconds // 60)

    # Tip bazlı kalori hesabı — frontend kaba tahmininden daha doğru
    kcal_per_min  = _KCAL_PER_MIN.get(body.exercise_name, 5)
    computed_kcal = duration_minutes * kcal_per_min
    # Frontend değeri 0 ise backend değerini, değilse ikisinin büyüğünü al
    final_kcal = max(body.calories_burned, computed_kcal)

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

    status = "tamamlandı" if body.completed else "yarıda bırakıldı"
    return CompleteSessionResponse(
        success=True,
        message=f"'{body.exercise_name}' antrenmanı {status} ve kaydedildi.",
        total_active_minutes_today=new_minutes,
        total_calories_today=new_calories,
    )
