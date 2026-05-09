from pydantic import BaseModel
from typing import List, Optional

class AnomalyData(BaseModel):
    has_anomaly: bool
    level: str
    message: str

class ActivityData(BaseModel):
    steps_today: int
    steps_goal: int
    calories_burned: int
    calories_goal: int
    active_minutes: int
    active_minutes_goal: int
    distance_km: float

class SleepHeartData(BaseModel):
    sleep_hours: float
    sleep_quality: float
    resting_hr: int
    avg_hr: int = 0               # Günlük ortalama nabız
    resting_hr_label: str = "Normal"
    resting_hr_severity: str = "good"  # "good" | "warning" | "danger"

class WeeklyChartData(BaseModel):
    days: List[str]
    steps: List[int]

class RecommendationItem(BaseModel):
    type: str # 'nutrition', 'exercise', 'sleep'
    text: str

class RiskData(BaseModel):
    score: int
    trend: int
    label: str
    top_factors: List[dict]

class VitalsData(BaseModel):
    spo2_pct: Optional[float] = None       # Kan oksijeni % (null = veri yok)
    hrv_ms: Optional[float] = None         # Kalp atış değişkenliği ms (null = veri yok)
    temp_celsius: Optional[float] = None   # Vücut sıcaklığı °C (null = veri yok)
    spo2_label: str = "Veri alınamadı"
    hrv_label: str = "Veri alınamadı"
    temp_label: str = "Veri alınamadı"

class DashboardResponse(BaseModel):
    user_name: str
    anomaly: AnomalyData
    risk: RiskData
    activity: ActivityData
    sleep_heart: SleepHeartData
    vitals: VitalsData
    weekly_chart: WeeklyChartData
    recommendations: List[RecommendationItem]
