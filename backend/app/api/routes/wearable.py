"""
/api/v1/wearable – Giyilebilir cihaz veri senkronizasyonu
Flutter → Apple HealthKit/Google Fit → buraya POST
→ daily_wearable_logs tablosuna yazar
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional
import datetime
import logging
from app.core.database import get_pool
from app.api.dependencies import get_current_user_id

router = APIRouter(prefix="/wearable", tags=["Wearable"])
_logger = logging.getLogger(__name__)

# GÜVENLİK: Dinamik SQL'e dahil edilebilecek tek geçerli sütunlar.
# Pydantic validasyon yapılıyor olsa da ek katman olarak whitelist zorunludur.
_ALLOWED_COLUMNS: set[str] = {
    "step_count", "avg_hr_bpm", "resting_hr_bpm", "calories_burned",
    "sleep_hours", "active_minutes", "sleep_score", "spo2_pct", "hrv_ms",
}


class WearableSyncPayload(BaseModel):
    step_count:      Optional[int]   = Field(None, ge=0)
    avg_hr_bpm:      Optional[int]   = Field(None, ge=20, le=250)
    resting_hr_bpm:  Optional[int]   = Field(None, ge=20, le=250)
    calories_burned: Optional[int]   = Field(None, ge=0)
    sleep_hours:     Optional[float] = Field(None, ge=0, le=24)
    active_minutes:  Optional[int]   = Field(None, ge=0)
    sleep_score:     Optional[int]   = Field(None, ge=0, le=100)
    spo2_pct:        Optional[float] = Field(None, ge=0, le=100)
    hrv_ms:          Optional[float] = Field(None, ge=0)


@router.post("/sync")
async def sync_wearable(
    payload: WearableSyncPayload,
    user_id: str = Depends(get_current_user_id),
):
    """
    Telefondaki sağlık verilerini backend'e gönderir.
    Bugün için kayıt varsa günceller (UPSERT), yoksa yeni ekler.
    """
    pool = await get_pool()
    today = datetime.date.today()

    # Sadece gelen (None olmayan) alanları güncelle
    fields = {k: v for k, v in payload.model_dump().items() if v is not None}

    if not fields:
        return {"status": "no_data", "message": "Gönderilecek veri bulunamadı."}

    # GÜVENLİK: Whitelist dışı sütun adı gelirse reddet (SQL injection koruması)
    invalid_cols = set(fields.keys()) - _ALLOWED_COLUMNS
    if invalid_cols:
        raise HTTPException(
            status_code=400,
            detail=f"Geçersiz alan(lar): {', '.join(invalid_cols)}"
        )

    # UPSERT – bugün kayıt varsa ilgili alanları güncelle
    set_clauses = ", ".join(
        f"{col} = EXCLUDED.{col}" for col in fields.keys()
    )
    columns = ", ".join(fields.keys())
    placeholders = ", ".join(f"${i+3}" for i in range(len(fields)))
    values = list(fields.values())

    sql = f"""
        INSERT INTO daily_wearable_logs (user_id, log_date, {columns})
        VALUES ($1, $2, {placeholders})
        ON CONFLICT (user_id, log_date)
        DO UPDATE SET {set_clauses}
    """

    try:
        await pool.execute(sql, user_id, today, *values)
        return {
            "status": "ok",
            "message": f"{len(fields)} alan güncellendi.",
            "synced_fields": list(fields.keys()),
        }
    except Exception as e:
        _logger.error("[WearableSync] DB hatası: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Veri kaydedilemedi.")
