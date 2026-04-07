from fastapi import APIRouter
from app.schemas.exercise import (
    ExerciseResponse,
    RationaleData,
    RationaleTag,
    ExerciseRecommendation,
    HRZoneData,
    WeeklyPlanItem
)

router = APIRouter(
    prefix="/exercise",
    tags=["Exercise"]
)

@router.get("/summary", response_model=ExerciseResponse)
async def get_exercise_summary():
    """
    Kullanıcının Egzersiz (Exercise) ekranında gösterilecek verileri döndürür.
    Şu an için mock vari verilerle dönmektedir, ileride gerçek veritabanı yansıyacaktır.
    """
    return ExerciseResponse(
        rationale=RationaleData(
            title="AI Analizi",
            description="Adım sayınız ortalamanın altında ve uyku kaliteniz düşüktü. Bugün hafif aktivite ve esneme önerilmektedir.",
            tags=[
                RationaleTag(label="💤 Uyku Düşük"),
                RationaleTag(label="🚶 Az Adım"),
                RationaleTag(label="❤️ HR Yüksek"),
            ]
        ),
        recommendations=[
            ExerciseRecommendation(
                icon="🧘",
                type="Yoga & Esneme",
                duration="15 dk",
                intensity="Düşük Yoğunluk",
                desc="Güne başlarken kaslarınızı rahatlatmak ve stresi azaltmak için ideal başlangıç.",
                color=0xFF10B981 # AksaColors.primary
            ),
            ExerciseRecommendation(
                icon="🚶",
                type="Tempolu Yürüyüş",
                duration="30 dk",
                intensity="Orta Yoğunluk",
                desc="Hedefinize ulaşmak için öğle arasında kısa bir açık hava yürüyüşü yapabilirsiniz.",
                color=0xFF0EA5E9 # AksaColors.accent
            )
        ],
        hr_zone=HRZoneData(
            min_hr=90,
            target_hr=110,
            max_hr=130
        ),
        weekly_plan=[
            WeeklyPlanItem(day="Pzt", activity="Kardiyo & Core (30dk)", done=True),
            WeeklyPlanItem(day="Sal", activity="Üst Vücut Güç (40dk)", done=True),
            WeeklyPlanItem(day="Çar", activity="Aktif Dinlenme (Yürüyüş)", done=True),
            WeeklyPlanItem(day="Per", activity="Alt Vücut Güç (40dk)", done=True),
            WeeklyPlanItem(day="Cum", activity="HIIT Kardiyo (20dk)", done=False),
            WeeklyPlanItem(day="Cmt", activity="Hafif Esneme & Yoga", done=False),
            WeeklyPlanItem(day="Paz", activity="Tam Dinlenme", done=False),
        ],
        heart_rate_hourly=[65, 62, 60, 58, 62, 68, 75, 82, 110, 115, 95, 85, 78, 80, 75, 72, 85, 120, 125, 90, 80, 75, 70, 68]
    )
