from fastapi import APIRouter, Header, HTTPException
from typing import List
from app.core.database import get_pool
from app.core.security import decode_access_token

from app.schemas.dashboard import (
    DashboardResponse,
    AnomalyData,
    RiskData,
    ActivityData,
    SleepHeartData,
    WeeklyChartData,
    RecommendationItem,
)

router = APIRouter(
    prefix="/dashboard",
    tags=["Dashboard"]
)

@router.get("/summary", response_model=DashboardResponse)
async def get_dashboard_summary(authorization: str = Header(...)):
    """
    Kullanıcının ana ekranında (Dashboard) gösterilecek tüm özet verileri döndürür.
    Şu an için mock vari statik verilerle dönmektedir, ileride tam entegre olacaktır.
    """
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")

    pool = await get_pool()
    user_name = "Kullanıcı"
    
    # Kullanıcı adını veritabanından öğren
    row = await pool.fetchrow("SELECT full_name FROM users WHERE id = $1", user_id)
    if row and row['full_name']:
        full_name = row['full_name']
        user_name = full_name.split()[0]  # Sadece ilk ismi al

    return DashboardResponse(
        user_name=user_name,
        anomaly=AnomalyData(
            has_anomaly=False,
            level="Düşük",
            message="Her şey yolunda görünüyor. Kalp ritminiz ve uyku düzeniniz stabil."
        ),
        risk=RiskData(
            score=24,
            trend=-5,
            label="Düşük Risk",
            top_factors=[
                {"icon": "💧", "name": "İyi Hidrasyon"},
                {"icon": "🏃", "name": "Düzenli Egzersiz"},
                {"icon": "🥗", "name": "Dengeli Beslenme"},
            ]
        ),
        activity=ActivityData(
            steps_today=8500,
            steps_goal=10000,
            calories_burned=620,
            calories_goal=700,
            active_minutes=45,
            active_minutes_goal=60,
            distance_km=6.2
        ),
        sleep_heart=SleepHeartData(
            sleep_hours=7.5,
            sleep_quality=0.85,
            resting_hr=64
        ),
        weekly_chart=WeeklyChartData(
            days=["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"],
            steps=[3000, 8000, 7500, 9200, 8100, 8500, 0]
        ),
        recommendations=[
             RecommendationItem(type="sleep", text="Uyku kaliteniz harika! Bu düzeni korumaya çalışın."),
             RecommendationItem(type="exercise", text="Günlük adım hedefinize ulaşmanıza çok az kaldı, kısa bir yürüyüş yapın."),
             RecommendationItem(type="nutrition", text="Günün geri kalanında su tüketiminize dikkat etmeyi unutmayın.")
        ]
    )
