from pydantic import BaseModel
from typing import List

class RationaleTag(BaseModel):
    label: str

class RationaleData(BaseModel):
    title: str
    description: str
    tags: List[RationaleTag]

class ExerciseRecommendation(BaseModel):
    icon: str
    type: str
    duration: str
    intensity: str
    desc: str
    color: int

class HRZoneData(BaseModel):
    min_hr: int
    target_hr: int
    max_hr: int

class WeeklyPlanItem(BaseModel):
    day: str
    activity: str
    done: bool

class WeeklyStats(BaseModel):
    total_active_minutes: int
    total_calories: int
    workouts_done: int
    streak_days: int = 0

class ExerciseResponse(BaseModel):
    rationale: RationaleData
    recommendations: List[ExerciseRecommendation]
    hr_zone: HRZoneData
    weekly_plan: List[WeeklyPlanItem]
    heart_rate_hourly: List[float]
    recovery_score: int = 65
    weekly_stats: WeeklyStats
