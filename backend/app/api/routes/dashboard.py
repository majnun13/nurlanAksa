from fastapi import APIRouter, Header, HTTPException, Depends
import logging
import traceback
from app.core.database import get_pool
from app.api.dependencies import get_current_user_id

from app.schemas.dashboard import (
    DashboardResponse,
    AnomalyData,
    RiskData,
    ActivityData,
    SleepHeartData,
    VitalsData,
    WeeklyChartData,
    RecommendationItem,
)
from app.services.anomaly_service import anomaly_service

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
    
    # ML Anomali Skoru Katkısı (Modül 3 Fusion)
    # Anomali servisinden dönen 0-100 arası skoru %25 ağırlıkla ekle
    anom_res = anomaly_service.evaluate_wearable_data(wearable, profile)
    ml_anomaly_score = anom_res.get("score", 0.0)
    
    score += ml_anomaly_score * 0.25

    return max(0, min(100, int(score)))


def _build_recommendations(wearable: dict, profile: dict, steps_goal: int) -> list:
    recs = []

    # ── Wearable Verileri ────────────────────────────────────────────
    steps    = wearable.get("step_count")    or 5000
    sleep_sc = wearable.get("sleep_score")   or 70
    avg_hr   = wearable.get("avg_hr_bpm")    or 72
    hrv      = wearable.get("hrv_ms")        or 45
    sleep_h  = float(wearable.get("sleep_hours") or 7.0)
    # SpO2: Cihaz ölçemiyorsa None kalır — eksik veri varsayım yapılmaz
    spo2_raw = wearable.get("spo2_pct")
    spo2     = float(spo2_raw) if spo2_raw is not None and float(spo2_raw) > 0 else None


    # ── Profil Verileri ──────────────────────────────────────────────
    goal       = profile.get("health_goal")           or "maintain"
    lifestyle  = profile.get("lifestyle")             or "Orta"
    conditions = profile.get("medical_conditions")    or []
    diet       = profile.get("dietary_restrictions")  or []
    weight_kg  = float(profile.get("weight_kg")       or 70.0)
    height_cm  = float(profile.get("height_cm")       or 170.0)
    age        = int(profile.get("age")               or 30)
    gender     = (profile.get("gender") or "erkek").lower()

    bmi = weight_kg / ((height_cm / 100) ** 2)

    # Hastalık bayrakları
    has_heart   = any(k in (c or "").lower() for c in conditions for k in ("kalp", "hipertansiyon", "ritim", "damar"))
    has_diabetes = any(k in (c or "").lower() for c in conditions for k in ("diyabet", "şeker"))
    has_thyroid  = any("tiroid" in (c or "").lower() for c in conditions)
    has_anemia   = any("anemi" in (c or "").lower() for c in conditions)

    # ── 1. KAN OKSİJENİ (Varsa — Cihaz Destekliyorsa) ──────────────
    if spo2 is not None and spo2 < 94:
        recs.append(RecommendationItem(type="sleep",
            text=f"⚠️ Kan oksijeniniz %{spo2:.0f} ile düşük seyrediyor. Derin nefes egzersizleri yapın ve havadar bir ortamda dinlenin."))

    # ── 2. HRV — Stres / Toparlanma ─────────────────────────────────
    if hrv < 25:
        recs.append(RecommendationItem(type="sleep",
            text=f"Kalp değişkenliğiniz (HRV: {hrv:.0f} ms) düşük — vücudunuz ciddi stres altında. Bugün ağır egzersizden kaçının, derin nefes veya meditasyon deneyin."))
    elif hrv < 35:
        recs.append(RecommendationItem(type="sleep",
            text=f"HRV değeriniz ({hrv:.0f} ms) biraz düşük. Kısa bir şekerleme veya yatmadan önce 10 dakikalık gevşeme size iyi gelebilir."))

    # ── 3. NABIZ ─────────────────────────────────────────────────────
    hr_limit = 85 if has_heart else 100
    if avg_hr > hr_limit:
        if has_heart:
            recs.append(RecommendationItem(type="exercise",
                text=f"💓 Kalp durumunuz göz önüne alındığında {avg_hr:.0f} bpm oldukça yüksek. Lütfen yoğun aktivitelerden kaçının ve gerekirse doktorunuzu arayın."))
        else:
            recs.append(RecommendationItem(type="exercise",
                text=f"Nabzınız ({avg_hr:.0f} bpm) normalin üzerinde. Bugün düşük tempolu yürüyüş veya esneme egzersizleri tercih edin."))
    elif avg_hr < 50 and not lifestyle == "Aktif":
        recs.append(RecommendationItem(type="exercise",
            text=f"Dinlenme nabzınız ({avg_hr:.0f} bpm) oldukça düşük. Kendinizi iyi hissediyorsanız sorun yok; ancak baş dönmesi yaşıyorsanız doktora danışın."))

    # ── 4. ADIM ──────────────────────────────────────────────────────
    if steps < steps_goal * 0.4:
        if has_heart or age > 60:
            recs.append(RecommendationItem(type="exercise",
                text=f"Bugün {steps:,} adım attınız. Sağlık durumunuza uygun tempolu, kısa yürüyüşlerle hedefinize yaklaşabilirsiniz."))
        else:
            recs.append(RecommendationItem(type="exercise",
                text=f"Bugün sadece {steps:,} adım attınız. {steps_goal:,} hedefinize ulaşmak için 20-30 dakikalık bir yürüyüş harika olur! 🚶"))
    elif steps >= steps_goal:
        recs.append(RecommendationItem(type="exercise",
            text=f"🎉 Tebrikler! Bugün {steps:,} adım atarak {steps_goal:,} hedefini aştınız. Harika bir gün!"))

    # ── 5. UYKU ──────────────────────────────────────────────────────
    if sleep_sc < 40 or sleep_h < 5.0:
        recs.append(RecommendationItem(type="sleep",
            text=f"Uyku kaliteniz çok düşük ({sleep_h:.1f} sa). Bu gece ekranları bir saat önce kapatın, oda ısısını 18-20°C'ye getirin."))
    elif sleep_sc < 60 or sleep_h < 6.5:
        recs.append(RecommendationItem(type="sleep",
            text="Uyku kaliteniz yetersiz. Yatmadan önce kafein tüketimini azaltın ve düzenli uyku saati belirlemeye çalışın."))
    elif sleep_sc > 85 and sleep_h >= 7.5:
        recs.append(RecommendationItem(type="sleep",
            text=f"Uyku kaliteniz mükemmel ({sleep_h:.1f} sa). Bu düzeni korumak bağışıklık sisteminizi güçlendirir. 😴"))

    # ── 6. SAĞLIK HEDEFİ + KİLO/BMI ─────────────────────────────────
    if goal == "lose_weight":
        if bmi > 30:
            recs.append(RecommendationItem(type="nutrition",
                text=f"VKİ'niz {bmi:.1f} ile obezite sınırında. Yüksek lifli gıdalar (sebze, baklagil) tercih edin ve şekerli içecekleri tamamen bırakın."))
        else:
            recs.append(RecommendationItem(type="nutrition",
                text="Kilo vermek için günlük kalori açığınızı 300-500 kcal arasında tutun. Protein ağırlıklı beslenme kas kaybını önler."))
    elif goal == "gain_weight":
        prot = round(weight_kg * 1.8, 0)
        recs.append(RecommendationItem(type="nutrition",
            text=f"Kas kazanımı için günde {prot:.0f}g protein (ağırlığınızın 1.8 katı) hedefleyin. Egzersiz sonrası 30 dk içinde protein alın."))
    elif goal == "maintain":
        recs.append(RecommendationItem(type="nutrition",
            text="Kilonuzu korumak için tabağınızın yarısını sebze, çeyreğini protein, çeyreğini tam tahıl ile doldurun."))

    # ── 7. KRONİK HASTALIK BAZLI ────────────────────────────────────
    if has_diabetes:
        recs.append(RecommendationItem(type="nutrition",
            text="Diyabetiniz için glisemik indeksi düşük gıdalar (yulaf, mercimek, yeşil sebzeler) tercih edin. Öğünleri küçük ve sık tutun."))
    if has_thyroid:
        recs.append(RecommendationItem(type="nutrition",
            text="Tiroid sağlığı için iyot açısından zengin gıdalar (deniz ürünleri, yumurta) tüketin. Çiğ lahana ve brokoli tüketimini sınırlayın."))
    if has_anemia:
        recs.append(RecommendationItem(type="nutrition",
            text="Aneminiz için demir açısından zengin gıdalar (kırmızı et, ıspanak, mercimek) tüketin. C vitamini ile birlikte alınca emilim artar."))

    # ── 8. DİYET KISITLAMASI ────────────────────────────────────────
    if "Glütensiz" in diet:
        recs.append(RecommendationItem(type="nutrition",
            text="Glüten intoleransınız için pirinç, kinoa, mısır ve patates gibi doğal glütensiz alternatifler zengin besin kaynağıdır."))
    if "Laktoz İntoleransı" in diet:
        recs.append(RecommendationItem(type="nutrition",
            text="Kalsiyum ihtiyacınız için badem sütü, yeşil yapraklı sebzeler ve tofu gibi laktozsuz kaynakları tercih edin."))
    if "Vejeteryan" in diet or "Vegan" in diet:
        recs.append(RecommendationItem(type="nutrition",
            text="Bitkisel beslenmenizde B12 ve D vitamini, demir ve çinko eksikliğine dikkat edin. Düzenli kan testi yaptırmanız önerilir."))

    # ── 9. YAŞ VE CİNSİYET ──────────────────────────────────────────
    if age > 60:
        recs.append(RecommendationItem(type="exercise",
            text="60+ yaşta denge ve esneklik egzersizleri düşme riskini azaltır. Haftada 2-3 kez hafif kuvvet antrenmanı kemik yoğunluğunu korur."))
    elif age < 25 and gender == "erkek":
        recs.append(RecommendationItem(type="exercise",
            text="Genç yaşta yapılan düzenli egzersiz metabolizma hızınızı kalıcı olarak artırır. Haftada en az 150 dk orta yoğunluklu aktivite hedefleyin."))

    # ── En fazla 4 öneri döndür ──────────────────────────────────────
    return recs[:4]



def _anomaly_from_wearable(wearable: dict, profile: dict) -> AnomalyData:
    # Eski kural tabanlı yapıyı yeni ML servisine yönlendir
    result = anomaly_service.evaluate_wearable_data(wearable, profile)
    return AnomalyData(
        has_anomaly=result["has_anomaly"],
        level=result["level"],
        message=result["message"]
    )


def _build_vitals(raw_wearable: dict) -> VitalsData:
    """
    Ham wearable verisinden VitalsData oluşturur.
    Cihaz desteklemiyorsa (None) → "Veri alınamadı" etiketi kalır.
    """
    # SpO2
    spo2_raw = raw_wearable.get("spo2_pct")
    spo2 = float(spo2_raw) if spo2_raw is not None else None
    if spo2 is not None:
        if spo2 >= 95:
            spo2_label = "Normal"
        elif spo2 >= 90:
            spo2_label = "Düşük"
        else:
            spo2_label = "Tehlikeli Düşük"
    else:
        spo2_label = "Veri alınamadı"

    # HRV
    hrv_raw = raw_wearable.get("hrv_ms")
    hrv = float(hrv_raw) if hrv_raw is not None else None
    if hrv is not None:
        if hrv >= 50:
            hrv_label = "Çok İyi"
        elif hrv >= 35:
            hrv_label = "Normal"
        elif hrv >= 25:
            hrv_label = "Düşük"
        else:
            hrv_label = "Stres Altında"
    else:
        hrv_label = "Veri alınamadı"

    # Vücut Sıcaklığı
    temp_raw = raw_wearable.get("temp_celsius")
    temp = float(temp_raw) if temp_raw is not None else None
    if temp is not None:
        if 36.1 <= temp <= 37.2:
            temp_label = "Normal"
        elif temp > 37.2 and temp <= 38.0:
            temp_label = "Hafif Ateş"
        elif temp > 38.0:
            temp_label = "Yüksek Ateş"
        else:
            temp_label = "Düşük"
    else:
        temp_label = "Veri alınamadı"

    return VitalsData(
        spo2_pct=spo2,
        hrv_ms=hrv,
        temp_celsius=temp,
        spo2_label=spo2_label,
        hrv_label=hrv_label,
        temp_label=temp_label,
    )


@router.get("/summary", response_model=DashboardResponse)
async def get_dashboard_summary(user_id: str = Depends(get_current_user_id)):

    """
    Kullanıcının ana ekranında gösterilecek özet verileri döndürür.
    Eksik/None veri durumunda güvenli varsayılan değerler kullanılır.
    """
    try:
        pool = await get_pool()

        # ── Kullanıcı adı ─────────────────────────────────────────
        user_row = await pool.fetchrow("SELECT full_name FROM users WHERE id = $1", user_id)
        user_name = "Kullanıcı"
        if user_row and user_row["full_name"]:
            user_name = user_row["full_name"].split()[0]

        # ── Sağlık profili ── _safe_profile ile normalize ─────────
        profile_row = await pool.fetchrow(
            "SELECT health_goal, lifestyle, medical_conditions, weight_kg, height_cm, age, gender FROM health_profiles WHERE user_id = $1",
            user_id,
        )
        profile = _safe_profile(dict(profile_row) if profile_row else None)

        # ── Günlük wearable verisi ── _safe_wearable ile normalize ─
        wearable_row = await pool.fetchrow(
            """
            SELECT step_count, avg_hr_bpm, resting_hr_bpm, sleep_hours,
                   sleep_score, hrv_ms, spo2_pct, active_minutes, calories_burned,
                   temp_celsius
            FROM daily_wearable_logs
            WHERE user_id = $1
            ORDER BY log_date DESC
            LIMIT 1
            """,
            user_id,
        )
        # Ham DB verisini sakla (null/None olanlar vitals kartlarında "Veri alınamadı" olacak)
        raw_wearable = dict(wearable_row) if wearable_row else {}
        wearable = _safe_wearable(raw_wearable)

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

        day_names = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
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
        steps_goal     = {"Sedanter": 5000, "Orta": 7000, "Aktif": 10000}.get(lifestyle, 7000)
        calories_goal  = {"Sedanter": 300,  "Orta": 500,  "Aktif": 700}.get(lifestyle, 500)
        active_goal    = {"Sedanter": 20,   "Orta": 30,   "Aktif": 45}.get(lifestyle, 30)

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
            anomaly=_anomaly_from_wearable(wearable, profile),
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
                avg_hr=int(wearable.get("avg_hr_bpm") or resting_hr),
                resting_hr_label=hr_label,
                resting_hr_severity=hr_severity,
            ),
            vitals=_build_vitals(raw_wearable),
            weekly_chart=WeeklyChartData(
                days=weekly_days,
                steps=weekly_steps,
            ),
            recommendations=_build_recommendations(wearable, profile, steps_goal),
        )

    except HTTPException:
        raise
    except Exception as e:
        logging.error("[Dashboard] Beklenmedik hata: %s\n%s", e, traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail="Dashboard verileri şu an alınamıyor. Lütfen tekrar deneyin.",
        )
