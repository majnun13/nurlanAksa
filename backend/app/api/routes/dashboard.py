from fastapi import APIRouter
from typing import List

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
async def get_dashboard_summary():
    """
    Kullanıcının ana ekranında (Dashboard) gösterilecek tüm özet verileri döndürür.
    Şu an için mock vari statik verilerle dönmektedir, ileride veritabanından çekilecektir.
    """
    
    # Kullanıcı adını current_user sözlüğünden (token datasından) al (eğer yoksa 'Kullanıcı' de)
    user_name = "Kullanıcı"

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
