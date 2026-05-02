"""
/api/v1/wearable – Giyilebilir cihaz veri senkronizasyonu
Flutter → Apple HealthKit/Google Fit → buraya POST
→ daily_wearable_logs tablosuna yazar
"""
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from app.core.database import get_pool
from app.core.security import decode_access_token

router = APIRouter(prefix="/wearable", tags=["Wearable"])


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
    authorization: str = Header(...),
):
    """
    Telefondaki sağlık verilerini backend'e gönderir.
    Bugün için kayıt varsa günceller (UPSERT), yoksa yeni ekler.
    """
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")

    pool = await get_pool()
    today = __import__("datetime").date.today()

    # Sadece gelen (None olmayan) alanları güncelle
    fields = {k: v for k, v in payload.model_dump().items() if v is not None}

    if not fields:
        return {"status": "no_data", "message": "Gönderilecek veri bulunamadı."}

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
        import logging
        logging.error(f"[WearableSync] DB hatası: {e}")
        raise HTTPException(status_code=500, detail="Veri kaydedilemedi.")
