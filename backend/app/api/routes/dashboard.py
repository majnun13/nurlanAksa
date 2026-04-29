from fastapi import APIRouter, Header, HTTPException
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

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


# ══════════════════════════════════════════════════════════════════════════════
#  GÜVENLİ VARSAYILAN DEĞERLER — Merkezi Null-Safety Katmanı
#  Kural: API'den veya DB'den gelen herhangi bir alan None/eksik olabilir.
#  _safe_wearable() ve _safe_profile() bu alanlara her zaman geçerli bir
#  değer kazandırır. Downstream fonksiyonlar hiçbir zaman None görmez.
# ══════════════════════════════════════════════════════════════════════════════

_WEARABLE_DEFAULTS: dict = {
    "step_count":     5000,
    "avg_hr_bpm":     72,
    "resting_hr_bpm": 65,
    "sleep_hours":    7.0,
    "sleep_score":    70,
    "hrv_ms":         45,
    "spo2_pct":       98,
    "active_minutes": 30,
    "calories_burned":300,
}

_PROFILE_DEFAULTS: dict = {
    "health_goal":          "maintain",
    "lifestyle":            "Orta",
    "medical_conditions":   [],
    "weight_kg":            70.0,
    "height_cm":            170,
    "age":                  30,
    "gender":               "erkek",
}


def _safe_wearable(raw: dict | None) -> dict:
    """
    Ham wearable verisini (DB row veya API cevabı) normalize eder.
    Eksik veya None olan her alan için _WEARABLE_DEFAULTS'tan değer kullanır.
    """
    base = dict(_WEARABLE_DEFAULTS)
    if raw:
        for k, v in raw.items():
            if v is not None:
                base[k] = v
    return base


def _safe_profile(raw: dict | None) -> dict:
    """
    Ham profil verisini normalize eder.
    Eksik veya None olan her alan için _PROFILE_DEFAULTS'tan değer kullanır.
    """
    base = dict(_PROFILE_DEFAULTS)
    if raw:
        for k, v in raw.items():
            if v is not None:
                base[k] = v
    # medical_conditions her zaman liste olsun
    if not isinstance(base.get("medical_conditions"), list):
        base["medical_conditions"] = []
    return base



def _classify_resting_hr(
    hr: int,
    age: int,
    lifestyle: str,
    conditions: list,
) -> tuple[str, str]:
    """
    Klinik bağlama duyarlı dinlenme nabzı sınıflandırması.
    Kaynak: AHA, Mayo Clinic, Cleveland Clinic kılavuzları.

    Returns:
        (label, severity)  severity: "good" | "warning" | "danger"
    """
    is_elderly   = age >= 60
    is_athlete   = lifestyle == "Aktif"
    is_sedentary = lifestyle == "Sedanter"
    has_heart_issue = any(
        kw in (c or "").lower()
        for c in (conditions or [])
        for kw in ("hipertansiyon", "kalp", "ritim", "infarkt")
    )

    # ── Tehlikeli düşük (herkes için evrensel eşik) ──────────
    if hr < 35:
        return "🚨 Tehlikeli Düşük — Doktora Gidin", "danger"

    # ── 35–49 bpm ────────────────────────────────────────────
    if hr < 50:
        if is_athlete and age < 55:
            # Genç-orta yaş aktif sporcu: olağan
            return "💪 Elit Sporcu Nabzı", "good"
        elif is_elderly or has_heart_issue:
            # Yaşlı veya kalp sorunu: bradikardi riski
            return "🔴 Bradikardi Riski — Takip Önerilir", "danger"
        else:
            # Orta yaş, orta aktif: izlenmeli
            return "⚠️ Düşük — Doktor Kontrolü Önerilir", "warning"

    # ── 50–59 bpm ────────────────────────────────────────────
    if hr < 60:
        if is_athlete and not is_elderly:
            return "🏅 Sporcu Nabzı — Çok İyi", "good"
        elif is_elderly and (is_sedentary or has_heart_issue):
            # Yaşlı + hareketsiz + düşük nabız → bradikardi değerlendirmesi
            return "⚠️ Yaş İçin Dikkat Edilmeli", "warning"
        elif is_sedentary:
            # Hareketsiz biri için 50-59 alışılmadık düşük
            return "⚠️ Hareketsiz Kişi İçin Düşük", "warning"
        else:
            # Orta aktif, orta yaş: iyiye işaret
            return "✅ İyi (Aktif Profil)", "good"

    # ── 60–75 bpm — herkes için ideal bölge ─────────────────
    if hr <= 75:
        return "✅ Normal", "good"

    # ── 76–90 bpm ────────────────────────────────────────────
    if hr <= 90:
        if has_heart_issue or is_elderly:
            return "⚠️ Dikkat — Takip Önerilir", "warning"
        return "⚠️ Normalden Yüksek", "warning"

    # ── > 90 bpm — istirahat halinde taşikardi eşiği ────────
    return "🔴 Yüksek — Doktor Önerilir", "danger"


def _risk_label(score: int) -> str:
    if score < 30:  return "Düşük Risk"
    if score < 60:  return "Orta Risk"
    return "Yüksek Risk"


def _calc_risk_score(wearable: dict, profile: dict) -> int:
    """
    Basit kural tabanlı risk skoru (0–100).
    Wearable + sağlık profili verilerinden hesaplanır.
    """
    score = 20  # baz skor

    # Adım sayısı (az hareket = yüksek risk)
    steps = wearable.get("step_count") or 5000
    if steps < 3000:   score += 20
    elif steps < 6000: score += 10
    elif steps > 10000: score -= 5

    # Uyku kalitesi
    sleep_sc = wearable.get("sleep_score") or 70
    if sleep_sc < 40:  score += 20
    elif sleep_sc < 60: score += 10
    elif sleep_sc > 80: score -= 5

    # Nabız
    avg_hr = wearable.get("avg_hr_bpm") or 72
    if avg_hr > 95:    score += 20
    elif avg_hr > 85:  score += 10
    elif avg_hr < 70:  score -= 5

    # HRV
    hrv = wearable.get("hrv_ms") or 45
    if hrv < 25:   score += 15
    elif hrv < 35: score += 8
    elif hrv > 55: score -= 5

    # Kronik hastalık
    conditions = profile.get("medical_conditions") or []
    score += min(len(conditions) * 8, 20)

    return max(0, min(100, score))


def _build_recommendations(wearable: dict, profile: dict) -> list:
    recs = []
    steps    = wearable.get("step_count")    or _WEARABLE_DEFAULTS["step_count"]
    sleep_sc = wearable.get("sleep_score")   or _WEARABLE_DEFAULTS["sleep_score"]
    avg_hr   = wearable.get("avg_hr_bpm")    or _WEARABLE_DEFAULTS["avg_hr_bpm"]
    hrv      = wearable.get("hrv_ms")        or _WEARABLE_DEFAULTS["hrv_ms"]
    goal     = profile.get("health_goal")    or _PROFILE_DEFAULTS["health_goal"]

    if steps < 5000:
        recs.append(RecommendationItem(type="exercise",
            text=f"Bugün sadece {steps:,} adım attınız. Hedef 10.000 için kısa bir yürüyüş yapın."))
    elif steps > 10000:
        recs.append(RecommendationItem(type="exercise",
            text=f"Harika! Bugün {steps:,} adım attınız. Aktif kalmaya devam edin! 🎉"))
    else:
        recs.append(RecommendationItem(type="exercise",
            text=f"Bugün {steps:,} adım attınız. Hedefinize ulaşmak için biraz daha yürüyün."))

    if sleep_sc < 50:
        recs.append(RecommendationItem(type="sleep",
            text="Uyku kaliteniz düşük. Bu gece erken yatın ve ekranlardan uzak durun."))
    elif sleep_sc > 80:
        recs.append(RecommendationItem(type="sleep",
            text="Uyku kaliteniz mükemmel! Bu düzeni korumaya devam edin. 😴"))
    else:
        recs.append(RecommendationItem(type="sleep",
            text="Uyku kalitenizi artırmak için yatmadan önce hafif esneme yapabilirsiniz."))

    if avg_hr > 90:
        recs.append(RecommendationItem(type="exercise",
            text=f"Nabzınız ({avg_hr} bpm) yüksek seyrediyor. Bugün düşük yoğunluklu egzersiz tercih edin."))
    elif hrv < 30:
        recs.append(RecommendationItem(type="sleep",
            text="HRV değeriniz düşük — vücudunuz stres altında. Derin nefes egzersizleri deneyin."))
    else:
        if goal == "lose_weight":
            recs.append(RecommendationItem(type="nutrition",
                text="Kilo hedefiniz için günlük kalori açığını koruyun ve su tüketimine dikkat edin."))
        elif goal == "gain_weight":
            recs.append(RecommendationItem(type="nutrition",
                text="Kas kazanımı için yeterli protein (vücut ağırlığının 1.6-2g/kg) almaya özen gösterin."))
        else:
            recs.append(RecommendationItem(type="nutrition",
                text="Günün geri kalanında su tüketiminize ve dengeli beslenmeye dikkat edin."))

    return recs[:3]


def _anomaly_from_wearable(wearable: dict) -> AnomalyData:
    avg_hr   = wearable.get("avg_hr_bpm")  or _WEARABLE_DEFAULTS["avg_hr_bpm"]
    sleep_sc = wearable.get("sleep_score") or _WEARABLE_DEFAULTS["sleep_score"]
    hrv      = wearable.get("hrv_ms")      or _WEARABLE_DEFAULTS["hrv_ms"]
    spo2     = wearable.get("spo2_pct")    or _WEARABLE_DEFAULTS["spo2_pct"]

    if spo2 < 94:
        return AnomalyData(has_anomaly=True, level="Yüksek",
            message=f"Kan oksijen seviyeniz ({spo2}%) düşük. Bir sağlık uzmanına danışın.")
    if avg_hr > 100:
        return AnomalyData(has_anomaly=True, level="Orta",
            message=f"Bugünkü ortalama nabzınız ({avg_hr} bpm) yüksek. Dinlenin ve bol su için.")
    if sleep_sc < 35:
        return AnomalyData(has_anomaly=True, level="Orta",
            message="Uyku kaliteniz kritik seviyede düşük. Bu gece erken uyumayı öneririz.")
    if hrv < 25:
        return AnomalyData(has_anomaly=True, level="Düşük",
            message="HRV değeriniz düşük, vücudunuz yorgun. Bugün hafif aktiviteler tercih edin.")

    return AnomalyData(has_anomaly=False, level="Düşük",
        message="Her şey yolunda görünüyor. Kalp ritminiz ve uyku düzeniniz stabil.")


@router.get("/summary", response_model=DashboardResponse)
async def get_dashboard_summary(authorization: str = Header(...)):
    """
    Kullanıcının ana ekranında gösterilecek özet verileri döndürür.
    Eksik/None veri durumunda güvenli varsayılan değerler kullanılır.
    """
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")

    try:
        pool = await get_pool()

        # ── Kullanıcı adı ─────────────────────────────────────────
        user_row = await pool.fetchrow("SELECT full_name FROM users WHERE id = $1", user_id)
        user_name = "Kullanıcı"
        if user_row and user_row["full_name"]:
            user_name = user_row["full_name"].split()[0]

        # ── Sağlık profili ── _safe_profile ile normalize ─────────
        profile_row = await pool.fetchrow(
            "SELECT health_goal, lifestyle, medical_conditions, weight_kg, height_cm, age FROM health_profiles WHERE user_id = $1",
            user_id,
        )
        profile = _safe_profile(dict(profile_row) if profile_row else None)

        # ── Günlük wearable verisi ── _safe_wearable ile normalize ─
        wearable_row = await pool.fetchrow(
            """
            SELECT step_count, avg_hr_bpm, resting_hr_bpm, sleep_hours,
                   sleep_score, hrv_ms, spo2_pct, active_minutes, calories_burned
            FROM daily_wearable_logs
            WHERE user_id = $1
            ORDER BY log_date DESC
            LIMIT 1
            """,
            user_id,
        )
        wearable = _safe_wearable(dict(wearable_row) if wearable_row else None)

        # ── Son 7 günün adım verisi ───────────────────────────────
        week_rows = await pool.fetch(
            """
            SELECT log_date, step_count
            FROM daily_wearable_logs
            WHERE user_id = $1
            ORDER BY log_date DESC
            LIMIT 7
            """,
            user_id,
        )

        day_names = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
        weekly_days   = []
        weekly_steps  = []
        for r in reversed(week_rows):
            weekly_days.append(day_names[r["log_date"].weekday()])
            weekly_steps.append(r["step_count"] or 0)

        # 7 günden az veri varsa boşlukları sıfırla
        while len(weekly_days) < 7:
            weekly_days.insert(0, "—")
            weekly_steps.insert(0, 0)

        # ── Risk skoru hesapla ────────────────────────────────────
        risk_score = _calc_risk_score(wearable, profile)
        risk_trend = -3 if risk_score < 40 else (5 if risk_score > 60 else 0)

        risk_factors = []
        steps      = wearable["step_count"]
        sleep_sc   = wearable["sleep_score"]
        avg_hr     = wearable["avg_hr_bpm"]
        conditions = profile["medical_conditions"]

        if steps > 8000:   risk_factors.append({"icon": "🏃", "name": "Aktif Yaşam"})
        if sleep_sc > 70:  risk_factors.append({"icon": "😴", "name": "İyi Uyku"})
        if avg_hr < 75:    risk_factors.append({"icon": "❤️", "name": "Sağlıklı Nabız"})
        if steps < 3000:   risk_factors.append({"icon": "⚠️", "name": "Az Hareket"})
        if sleep_sc < 50:  risk_factors.append({"icon": "😰", "name": "Kötü Uyku"})
        if avg_hr > 90:    risk_factors.append({"icon": "💓", "name": "Yüksek Nabız"})
        if len(conditions) > 0:
            risk_factors.append({"icon": "🏥", "name": conditions[0]})
        if not risk_factors:
            risk_factors = [{"icon": "✅", "name": "İyi Genel Sağlık"}]

        # ── Adım hedefi (lifestyle'a göre) ───────────────────────
        lifestyle      = profile["lifestyle"]
        steps_goal     = {"Sedanter": 7500, "Orta": 10000, "Aktif": 12000}.get(lifestyle, 10000)
        calories_goal  = {"Sedanter": 400,  "Orta": 600,   "Aktif": 800}.get(lifestyle, 600)
        active_goal    = {"Sedanter": 30,   "Orta": 45,    "Aktif": 60}.get(lifestyle, 45)

        step_count      = wearable["step_count"]
        distance_km     = round(step_count * 0.0007, 1)
        calories_burned = wearable["calories_burned"]
        active_minutes  = wearable["active_minutes"]
        sleep_hours     = float(wearable["sleep_hours"])
        sleep_score     = wearable["sleep_score"]
        resting_hr      = wearable["resting_hr_bpm"]

        age        = profile["age"]
        hr_label, hr_severity = _classify_resting_hr(resting_hr, age, lifestyle, conditions)

        return DashboardResponse(
            user_name=user_name,
            anomaly=_anomaly_from_wearable(wearable),
            risk=RiskData(
                score=risk_score,
                trend=risk_trend,
                label=_risk_label(risk_score),
                top_factors=risk_factors[:3],
            ),
            activity=ActivityData(
                steps_today=step_count,
                steps_goal=steps_goal,
                calories_burned=calories_burned,
                calories_goal=calories_goal,
                active_minutes=active_minutes,
                active_minutes_goal=active_goal,
                distance_km=distance_km,
            ),
            sleep_heart=SleepHeartData(
                sleep_hours=sleep_hours,
                sleep_quality=round(sleep_score / 100, 2),
                resting_hr=resting_hr,
                resting_hr_label=hr_label,
                resting_hr_severity=hr_severity,
            ),
            weekly_chart=WeeklyChartData(
                days=weekly_days,
                steps=weekly_steps,
            ),
            recommendations=_build_recommendations(wearable, profile),
        )

    except HTTPException:
        raise
    except Exception as e:
        import traceback, logging
        logging.error(f"[Dashboard] Beklenmedik hata: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail="Dashboard verileri şu an alınamıyor. Lütfen tekrar deneyin.",
        )
