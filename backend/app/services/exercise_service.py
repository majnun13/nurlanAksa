# ─────────────────────────────────────────────────────────────────────────────
#  Egzersiz Öneri Servisi (Kural Tabanlı Motor) — v2 (Wearable Entegreli)
#
#  Algoritma:
#    1. health_profiles → yaş, lifestyle, health_goal
#    2. daily_wearable_logs → adım, nabız, uyku, HRV (gerçek DB verisi)
#    3. Wearable sinyallerine göre toparlanma skoru hesapla
#    4. difficulty otomatik ayarla (uyku/HRV/nabız kötüyse → easy)
#    5. Adım sayısına göre egzersiz tipini önceliklendir
#    6. Yüksek nabız varsa yoğunluğu düşür
#    7. Haftalık planı health_goal'a göre oluştur
# ─────────────────────────────────────────────────────────────────────────────

from ..core.database import get_pool
import datetime


# ══════════════════════════════════════════════════════════════════════════════
#  KAH Hesaplama (Tanaka Formülü)
# ══════════════════════════════════════════════════════════════════════════════

def calculate_max_hr(age: int) -> int:
    return round(208 - (0.7 * age))


def calculate_hr_zones(age: int, health_goal: str) -> dict:
    max_hr = calculate_max_hr(age)
    zones = {
        "lose_weight": (0.60, 0.70),
        "maintain":    (0.65, 0.75),
        "gain_weight": (0.70, 0.85),
    }
    low_pct, high_pct = zones.get(health_goal, (0.65, 0.75))
    return {
        "min_hr":    round(max_hr * low_pct),
        "target_hr": round(max_hr * (low_pct + high_pct) / 2),
        "max_hr":    round(max_hr * high_pct),
    }


# ══════════════════════════════════════════════════════════════════════════════
#  Egzersiz Veritabanı
# ══════════════════════════════════════════════════════════════════════════════

_EX = {
    "walking": {
        "icon": "🚶", "type": "Tempolu Yürüyüş",
        "duration":  {"normal": "30 dk", "easy": "20 dk"},
        "intensity": {"normal": "Orta Yoğunluk", "easy": "Düşük Yoğunluk"},
        "desc": {
            "normal": "Hedef KAH bölgenizde tutarak tempolu bir yürüyüş. Doğada veya açık havada yapmanız ek fayda sağlar.",
            "easy":   "Bugün daha hafif tutuyoruz. Rahat bir tempoda yürüyün, nefes kesmeyin.",
        },
        "color": 0xFF0EA5E9,
    },
    "yoga": {
        "icon": "🧘", "type": "Yoga & Esneme",
        "duration":  {"normal": "20 dk", "easy": "15 dk"},
        "intensity": {"normal": "Düşük Yoğunluk", "easy": "Çok Düşük"},
        "desc": {
            "normal": "Güne yoga ve derin esneme hareketleriyle başlayın. Kas esnekliği ve stres azaltımı için idealdir.",
            "easy":   "Sadece temel esneme hareketleri. Yatakta bile yapabilirsiniz — vücudunuzu dinleyin.",
        },
        "color": 0xFF10B981,
    },
    "hiit": {
        "icon": "⚡", "type": "HIIT Kardiyo",
        "duration":  {"normal": "1 dk", "easy": "1 dk"},
        "intensity": {"normal": "Yüksek Yoğunluk", "easy": "Orta Yoğunluk"},
        "desc": {
            "normal": "Yüksek yoğunluklu interval antrenman. 40 sn çalış / 20 sn dinlen formatında.",
            "easy":   "Daha uzun dinlenme aralarıyla hafifletilmiş HIIT. 30 sn çalış / 30 sn dinlen.",
        },
        "color": 0xFFF59E0B,
    },
    "strength": {
        "icon": "💪", "type": "Güç Antrenmanı",
        "duration":  {"normal": "40 dk", "easy": "25 dk"},
        "intensity": {"normal": "Orta–Yüksek Yoğunluk", "easy": "Orta Yoğunluk"},
        "desc": {
            "normal": "Üst/alt vücut güç egzersizleri. 3 set × 10–12 tekrar hedefleyin.",
            "easy":   "Hafif dirençle veya sadece vücut ağırlığıyla temel güç hareketleri.",
        },
        "color": 0xFFEF4444,
    },
    "cycling": {
        "icon": "🚴", "type": "Bisiklet / Spinning",
        "duration":  {"normal": "35 dk", "easy": "20 dk"},
        "intensity": {"normal": "Orta Yoğunluk", "easy": "Düşük–Orta"},
        "desc": {
            "normal": "Sabit tempolu bisiklet. Eklemlere düşük yük bindirir, kardiyo kapasiteyi artırır.",
            "easy":   "Hafif bir tempoda keyifli bir bisiklet turu.",
        },
        "color": 0xFF8B5CF6,
    },
    "swimming": {
        "icon": "🏊", "type": "Yüzme",
        "duration":  {"normal": "30 dk", "easy": "20 dk"},
        "intensity": {"normal": "Orta Yoğunluk", "easy": "Düşük Yoğunluk"},
        "desc": {
            "normal": "Tüm vücut kardiyo egzersizi. Eklemlere çok düşük yük biner.",
            "easy":   "Hafif tempoda serbest stil veya sırtüstü yüzme.",
        },
        "color": 0xFF06B6D4,
    },
    "calisthenics": {
        "icon": "🤸", "type": "Kalistenik",
        "duration":  {"normal": "30 dk", "easy": "20 dk"},
        "intensity": {"normal": "Orta Yoğunluk", "easy": "Düşük Yoğunluk"},
        "desc": {
            "normal": "Şınav, mekik, squat, plank gibi vücut ağırlığı egzersizleri.",
            "easy":   "Duvar şınavı, modifiye mekik gibi başlangıç seviyesi hareketler.",
        },
        "color": 0xFFEC4899,
    },
    "rest": {
        "icon": "😴", "type": "Aktif Dinlenme",
        "duration":  {"normal": "—", "easy": "—"},
        "intensity": {"normal": "Dinlenme", "easy": "Dinlenme"},
        "desc": {
            "normal": "Bugün dinlenme günü. Kısa bir yürüyüş veya esneme yapabilirsiniz.",
            "easy":   "Kesinlikle dinlenin. Kaslarınız iyileşiyor. Bol su için ve erken uyuyun.",
        },
        "color": 0xFF6B7280,
    },
}

# ══════════════════════════════════════════════════════════════════════════════
#  Egzersiz Seçimi — Lifestyle × Goal Matrisi
# ══════════════════════════════════════════════════════════════════════════════

_EXERCISE_MATRIX = {
    ("Sedanter",  "lose_weight"): ["walking",     "yoga"],
    ("Sedanter",  "maintain"):    ["walking",     "calisthenics"],
    ("Sedanter",  "gain_weight"): ["calisthenics","walking"],
    ("Orta",      "lose_weight"): ["hiit",        "cycling"],
    ("Orta",      "maintain"):    ["cycling",     "strength"],
    ("Orta",      "gain_weight"): ["strength",    "cycling"],
    ("Aktif",     "lose_weight"): ["hiit",        "strength"],
    ("Aktif",     "maintain"):    ["swimming",    "strength"],
    ("Aktif",     "gain_weight"): ["strength",    "hiit"],
}

# ══════════════════════════════════════════════════════════════════════════════
#  Medikal Kısıtlama Haritası
#  Kronik rahatsızlıklara göre hangi egzersizler kaçınılmalı / tercih edilmeli
# ══════════════════════════════════════════════════════════════════════════════

_MEDICAL_RESTRICTIONS: dict[str, dict] = {
    "hipertansiyon":    {"avoid": ["hiit"],              "prefer": ["walking", "swimming", "yoga"]},
    "kalp":             {"avoid": ["hiit", "strength"],   "prefer": ["walking", "yoga", "swimming"]},
    "infarktüsü":     {"avoid": ["hiit", "strength"],   "prefer": ["walking", "yoga"]},
    "ritim bozukluğu": {"avoid": ["hiit"],              "prefer": ["walking", "yoga", "swimming"]},
    "tip 2 diyabet":   {"avoid": [],                    "prefer": ["walking", "cycling"]},
    "tip 1 diyabet":   {"avoid": [],                    "prefer": ["walking", "cycling"]},
    "anemi":           {"avoid": ["hiit", "strength"],   "prefer": ["walking", "yoga"]},
    "osteoporoz":      {"avoid": ["hiit"],              "prefer": ["swimming", "yoga", "walking"]},
    "eklem":           {"avoid": ["hiit", "calisthenics"],"prefer": ["swimming", "cycling", "yoga"]},
    "diz":             {"avoid": ["hiit", "calisthenics"],"prefer": ["swimming", "cycling"]},
    "bırakan":          {"avoid": [],                    "prefer": ["walking"]},
    "astim":           {"avoid": ["hiit"],              "prefer": ["swimming", "walking", "yoga"]},
    "koah":            {"avoid": ["hiit", "strength"],   "prefer": ["walking", "yoga"]},
}


def _apply_medical_restrictions(
    exercise_keys: list[str],
    medical_conditions: list[str],
    difficulty: str,
) -> tuple[list[str], str]:
    """
    Kronik hastalıklara göre:
    - Tehlikeli egzersizleri listeden çıkar
    - Uygun alternatifleri öne çıkar
    - Gerekirse difficulty=easy yap
    """
    if not medical_conditions:
        return exercise_keys, difficulty

    avoid_set:  set[str] = set()
    prefer_list: list[str] = []

    for condition in medical_conditions:
        cond_lower = condition.lower()
        for key, rules in _MEDICAL_RESTRICTIONS.items():
            if key in cond_lower:
                avoid_set.update(rules["avoid"])
                prefer_list.extend(rules["prefer"])
                # Kalp/hipertansiyon varsa daima easy
                if key in ("kalp", "hipertansiyon", "infarktüsü", "ritim bozukluğu", "koah"):
                    difficulty = "easy"

    # Kaçınılması gerekenler listeden çıkar
    filtered = [e for e in exercise_keys if e not in avoid_set]

    # Tercih listesinden filtre-edilmiş öğeleri öne al
    seen = set(filtered)
    for pref in prefer_list:
        if pref not in seen:
            filtered.insert(0, pref)
            seen.add(pref)
            break  # en fazla bir tane ekle

    return filtered[:2] if filtered else ["walking", "yoga"], difficulty


def _apply_age_adjustments(
    exercise_keys: list[str],
    age: int,
    difficulty: str,
) -> tuple[list[str], str]:
    """
    Yaşa göre egzersiz ayarlama:
    - 65+ → yüksek darbeli egzersizlerden kaçın
    - 70+ → difficulty daima easy
    - 50-64 → HIIT listede son sıraya al
    """
    if age >= 70:
        # Yüksek darbeli kaldır, easy moda al
        exercise_keys = [e for e in exercise_keys
                         if e not in ("hiit", "calisthenics")]
        if not exercise_keys:
            exercise_keys = ["walking", "yoga"]
        difficulty = "easy"
    elif age >= 65:
        # Yüksek darbeli çıkar, yayış / yakın alternatif ekle
        exercise_keys = [e for e in exercise_keys
                         if e not in ("hiit", "calisthenics")]
        if not exercise_keys:
            exercise_keys = ["walking", "swimming"]
    elif age >= 50:
        # HIIT öı en sona al (var sa)
        if "hiit" in exercise_keys and len(exercise_keys) > 1:
            exercise_keys = [e for e in exercise_keys if e != "hiit"] + ["hiit"]

    return exercise_keys, difficulty

# ══════════════════════════════════════════════════════════════════════════════
#  Haftalık Plan
# ══════════════════════════════════════════════════════════════════════════════

_WEEKLY_PLANS = {
    "lose_weight": [
        ("Pzt", "HIIT Kardiyo (20 dk)"),
        ("Sal", "Tempolu Yürüyüş (30 dk)"),
        ("Çar", "Güç Antrenmanı (40 dk)"),
        ("Per", "HIIT Kardiyo (20 dk)"),
        ("Cum", "Bisiklet / Spinning (35 dk)"),
        ("Cmt", "Yoga & Esneme (20 dk)"),
        ("Paz", "Aktif Dinlenme"),
    ],
    "maintain": [
        ("Pzt", "Bisiklet / Spinning (30 dk)"),
        ("Sal", "Güç Antrenmanı (35 dk)"),
        ("Çar", "Aktif Dinlenme"),
        ("Per", "Tempolu Yürüyüş (30 dk)"),
        ("Cum", "Güç Antrenmanı (35 dk)"),
        ("Cmt", "Yoga & Esneme (20 dk)"),
        ("Paz", "Aktif Dinlenme"),
    ],
    "gain_weight": [
        ("Pzt", "Güç Antrenmanı — Üst Vücut (45 dk)"),
        ("Sal", "Güç Antrenmanı — Alt Vücut (45 dk)"),
        ("Çar", "Aktif Dinlenme"),
        ("Per", "Güç Antrenmanı — Üst Vücut (45 dk)"),
        ("Cum", "Güç Antrenmanı — Alt Vücut (45 dk)"),
        ("Cmt", "Bisiklet / Spinning (20 dk)"),
        ("Paz", "Aktif Dinlenme"),
    ],
}

_DAY_ORDER = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]


async def _build_weekly_plan(health_goal: str, user_id: str) -> list[dict]:
    """
    Haftalık plan listesi. `done` alanı DB'deki gerçek antrenman kayıtlarına göre belirlenir.
    """
    today         = datetime.date.today()
    today_weekday = today.weekday()          # Pzt=0 ... Paz=6
    week_start    = today - datetime.timedelta(days=today_weekday)

    # Hangi günlerde active_minutes > 0 var?
    try:
        pool = await get_pool()
        rows = await pool.fetch(
            """
            SELECT log_date FROM daily_wearable_logs
            WHERE user_id = $1
              AND log_date >= $2
              AND log_date <  $3
              AND active_minutes > 0
            """,
            user_id, week_start, today,   # bugünü dışla (yarım sayılmaz)
        )
        active_weekdays = {r["log_date"].weekday() for r in rows}
    except Exception:
        active_weekdays = set()

    plan_template = _WEEKLY_PLANS.get(health_goal, _WEEKLY_PLANS["maintain"])
    return [
        {"day": day, "activity": activity, "done": i in active_weekdays}
        for i, (day, activity) in enumerate(plan_template)
    ]


# ══════════════════════════════════════════════════════════════════════════════
#  Haftalık İstatistikler — DB'den Oku
# ══════════════════════════════════════════════════════════════════════════════

async def _get_weekly_stats(user_id: str) -> dict:
    """
    Bu haftaki (Pzt–bugün) toplam aktif dakika, kalori ve antrenman günü sayısı.
    Ayrıca ardışık gün serisi (streak) hesaplanır.
    """
    try:
        pool = await get_pool()
        today = datetime.date.today()
        week_start = today - datetime.timedelta(days=today.weekday())

        row = await pool.fetchrow(
            """
            SELECT
                COALESCE(SUM(active_minutes),  0)::int  AS total_minutes,
                COALESCE(SUM(calories_burned), 0)::int  AS total_calories,
                COUNT(DISTINCT log_date)::int            AS workout_days
            FROM daily_wearable_logs
            WHERE user_id = $1
              AND log_date >= $2
              AND log_date <= $3
              AND active_minutes > 0
            """,
            user_id, week_start, today,
        )

        # Streak: Bugünden geriye ardışık aktif gün sayısı
        streak_rows = await pool.fetch(
            """
            SELECT log_date FROM daily_wearable_logs
            WHERE user_id = $1 AND active_minutes > 0
            ORDER BY log_date DESC
            LIMIT 60
            """,
            user_id,
        )
        streak = 0
        check_day = today
        active_set = {r["log_date"] for r in streak_rows}
        while check_day in active_set:
            streak += 1
            check_day -= datetime.timedelta(days=1)

        if row:
            return {
                "total_active_minutes": row["total_minutes"],
                "total_calories":       row["total_calories"],
                "workouts_done":        row["workout_days"],
                "streak_days":          streak,
            }
    except Exception:
        pass
    return {"total_active_minutes": 0, "total_calories": 0, "workouts_done": 0, "streak_days": 0}


# ══════════════════════════════════════════════════════════════════════════════
#  Wearable Verileri — DB'den Oku
# ══════════════════════════════════════════════════════════════════════════════

def _calc_recovery(
    sleep_score: int,
    hrv: int,
    avg_hr: int,
    age: int,
    prev_active_minutes: int | None,
) -> int:
    """
    Geliştirilmiş toparlanma skoru (0–100).

    Akademik dayanaklar:
    ────────────────────────────────────────
    * Uyku (45 %): Walker 2017 — uyku kas sentezi ve kortizol baskılaması için kritik.
    * HRV — yaşa normalize (40 %): Shaffer & Ginsberg 2017 — yaşla birlikte HRV düşer;
      kilit karşılaştırma kişinin kendi başlangıcıyla olmalı.
      Referans medyan değerler (ms): 20-29=55, 30-39=45, 40-49=35, 50-59=28, 60+=22
    * Dinlenme nabız (15 %): Düşük RHR iyi toparlanma göstergesi.
    * Önceki gün yüku penaltısı: Banister Fitness-Fatigue modeli — bir önceki günün
      aktifliği bugünün yorgunluğuna doğrudan katkı yapar.
      Veri yoksa (None) → penaltı 0 (tarafsız).
    """
    # 1. Yaşa normalize HRV skoru
    hrv_baseline = max(15.0, 60.0 - max(0, age - 20) * 0.9)
    hrv_norm = min(100, int((hrv / hrv_baseline) * 75))

    # 2. Dinlenme nabız skoru
    hr_score = max(0, min(100, 100 - (avg_hr - 55) * 2))

    # 3. Önceki gün yüku penaltısı (Banister Fitness-Fatigue)
    if prev_active_minutes is None:
        fatigue_penalty = 0    # Veri yok → tarafsız
    elif prev_active_minutes < 30:
        fatigue_penalty = 0    # Hafif gün
    elif prev_active_minutes < 60:
        fatigue_penalty = 5    # Orta hafif
    elif prev_active_minutes < 90:
        fatigue_penalty = 12   # Orta
    elif prev_active_minutes < 120:
        fatigue_penalty = 18   # Yoğun
    else:
        fatigue_penalty = 25   # Çok yoğun

    # 4. Ağırlıklı toplam (WHOOP/Oura ilhamı)
    raw = sleep_score * 0.45 + hrv_norm * 0.40 + hr_score * 0.15

    # 5. Yorgunluk penaltısını düş
    return max(0, min(100, round(raw - fatigue_penalty)))


async def _get_wearable_context(user_id: str, age: int = 30) -> dict:
    """
    Son iki günün wearable verisini çeker.
    Bugünün verisi → günlük sinyaller.
    Dünün verisi → yorgunluk penaltısı için.
    Kayıt yoksa güvenli varsayılan değerler döner.
    """
    pool  = await get_pool()
    today = datetime.date.today()
    yesterday = today - datetime.timedelta(days=1)

    row = await pool.fetchrow(
        """
        SELECT step_count, avg_hr_bpm, resting_hr_bpm, sleep_hours,
               sleep_score, hrv_ms, active_minutes, calories_burned
        FROM daily_wearable_logs
        WHERE user_id = $1
        ORDER BY log_date DESC
        LIMIT 1
        """,
        user_id,
    )

    # Dünün aktiflik verisi (yorgunluk penaltısı için)
    prev_row = await pool.fetchrow(
        "SELECT active_minutes FROM daily_wearable_logs "
        "WHERE user_id = $1 AND log_date = $2",
        user_id, yesterday,
    )
    prev_active: int | None = (
        prev_row["active_minutes"] if prev_row and prev_row["active_minutes"] else None
    )

    if row:
        sleep_score = row["sleep_score"] or 70
        hrv         = row["hrv_ms"]      or 45
        avg_hr      = row["avg_hr_bpm"]  or 72
        return {
            "step_count":     row["step_count"]     or 5000,
            "avg_hr_today":   avg_hr,
            "resting_hr":     row["resting_hr_bpm"] or 65,
            "sleep_score":    sleep_score,
            "sleep_hours":    float(row["sleep_hours"] or 7.0),
            "hrv":            hrv,
            "active_minutes": row["active_minutes"]  or 30,
            "calories_burned":row["calories_burned"] or 300,
            "recovery_score": _calc_recovery(
                sleep_score, hrv, avg_hr, age, prev_active
            ),
            "has_real_data":  True,
        }
    else:
        return {
            "step_count": 5000, "avg_hr_today": 72, "resting_hr": 65,
            "sleep_score": 70,  "sleep_hours": 7.0, "hrv": 45,
            "active_minutes": 30, "calories_burned": 300,
            "recovery_score": _calc_recovery(70, 45, 72, age, None),
            "has_real_data": False,
        }


# ══════════════════════════════════════════════════════════════════════════════
#  Wearable Verilerine Göre Egzersiz Ayarlama  (YENİ)
# ══════════════════════════════════════════════════════════════════════════════

def _apply_wearable_adjustments(
    exercise_keys: list[str],
    wearable: dict,
    difficulty: str,
) -> tuple[list[str], str]:
    """
    Wearable sinyallerine göre:
    - difficulty'yi otomatik easy'e çeker
    - Adım sayısına göre egzersiz tipini önceliklendirir
    - Yüksek nabızda yüzme/yoga öne çıkar
    - İyi toparlanmada yoğun egzersizi öne çıkar
    """
    steps    = wearable["step_count"]
    avg_hr   = wearable["avg_hr_today"]
    recovery = wearable["recovery_score"]
    sleep_sc = wearable["sleep_score"]
    hrv      = wearable["hrv"]
    sleep_h  = wearable["sleep_hours"]

    # ── 1. Difficulty Override ────────────────────────────────
    if difficulty == "normal":
        bad = 0
        if sleep_sc < 45:   bad += 2   # çok kötü uyku
        if avg_hr  > 92:    bad += 2   # yüksek nabız
        if hrv     < 28:    bad += 2   # çok düşük HRV
        if recovery < 38:   bad += 1
        if sleep_h < 5.0:   bad += 2
        if bad >= 3:
            difficulty = "easy"

    # ── 2. Adım Sayısına Göre Önceliklendirme ────────────────
    # Az adım → yürüyüşü öne al (kardiyo alışkanlığı kazandır)
    if steps < 3000 and "walking" not in exercise_keys:
        exercise_keys = ["walking"] + [e for e in exercise_keys if e != "walking"][:1]

    # Çok adım + iyi toparlanma → HIIT veya güç öne çık
    if steps > 11000 and recovery > 78 and difficulty == "normal":
        for preferred in ["hiit", "strength"]:
            if preferred in exercise_keys:
                exercise_keys = [preferred] + [e for e in exercise_keys if e != preferred]
                break

    # ── 3. Yüksek Nabız → Düşük Darbeli Egzersiz ────────────
    # avg_hr > 88 iken normal moddaysa son egzersizi yüzme/yoga yap
    if avg_hr > 88 and difficulty == "normal" and exercise_keys:
        low_impact = "swimming" if "swimming" not in exercise_keys else "yoga"
        if low_impact not in exercise_keys:
            exercise_keys[-1] = low_impact

    return exercise_keys, difficulty


# ══════════════════════════════════════════════════════════════════════════════
#  Rationale Kartı
# ══════════════════════════════════════════════════════════════════════════════

_RATIONALE_MAP = {
    ("Sedanter",  "lose_weight",  "normal"): (
        "Başlangıç Seviyesi Plan",
        "Hareketsiz yaşam tarzınız göz önüne alınarak hafif ama etkili bir kilo verme planı oluşturuldu.",
        ["🚶 Düşük Başlangıç", "🔥 Kalori Yakımı", "❤️ Kalp Sağlığı"],
    ),
    ("Sedanter",  "maintain",    "normal"): (
        "Aktifliği Koruma Planı",
        "Günlük hareket miktarınızı artırmak için yürüyüş ve kalistenik kombinasyonu.",
        ["⚖️ Denge", "🚶 Hareket", "💪 Tonus"],
    ),
    ("Sedanter",  "gain_weight", "normal"): (
        "Güvenli Kilo Alma Planı",
        "Kilo almak için yeterli kalori + güç antrenmanı şart.",
        ["💪 Kas", "📈 Kilo Artışı", "🍽️ Kalori Artır"],
    ),
    ("Orta",      "lose_weight",  "normal"): (
        "Yoğun Kilo Verme Programı",
        "Orta aktiflik seviyeniz HIIT ve bisiklet antrenmanlarına hazır.",
        ["⚡ HIIT", "🔥 Yüksek Yakım", "💧 Hidrasyon"],
    ),
    ("Orta",      "maintain",    "normal"): (
        "Denge & Dayanıklılık Planı",
        "Sağlıklı kilonuzu korumak için kardiyo ve güç antrenmanı dengesi.",
        ["🏃 Kardiyo", "💪 Güç", "⚖️ Denge"],
    ),
    ("Orta",      "gain_weight", "normal"): (
        "Kas Geliştirme Programı",
        "Güç antrenmanı odaklı bir plan. Yeterli protein alımıyla birleştirince kas kazanımı hızlanır.",
        ["💪 Güç", "📈 Hacim", "🥩 Protein"],
    ),
    ("Aktif",     "lose_weight",  "normal"): (
        "Elit Yağ Yakma Programı",
        "Yüksek aktiflik seviyeniz HIIT + güç kombinasyonuna hazır.",
        ["⚡ Yüksek Yoğunluk", "🔥 Maksimum Yakım", "🏆 Performans"],
    ),
    ("Aktif",     "maintain",    "normal"): (
        "Elit Dayanıklılık Planı",
        "Yüksek fitness seviyenizi korumak için çeşitli antrenman modaliteleri.",
        ["🏊 Dayanıklılık", "💪 Güç", "🧬 Sağlık"],
    ),
    ("Aktif",     "gain_weight", "normal"): (
        "Maksimum Kas Geliştirme",
        "Yoğun güç antrenmanı ve hacim odaklı program.",
        ["💪 Maksimum Güç", "📈 Hipertrofi", "🔄 Periodizasyon"],
    ),
}

_RATIONALE_EASY = (
    "Bugün Dinlenme Modu",
    "Bugün vücudunuzun daha fazla dinlenmeye ihtiyacı var. Hafifletilmiş egzersizler seçtik.",
    ["😴 Dinlenme", "💆 Toparlanma", "💧 Hidrasyon"],
)


def _build_rationale(lifestyle: str, health_goal: str, difficulty: str, wearable: dict) -> dict:
    if difficulty == "easy":
        title, desc, tag_labels = _RATIONALE_EASY
        # Wearable sinyaline göre ek açıklama
        if wearable["sleep_score"] < 45:
            desc += " Uyku kaliteniz düşük — vücudunuzu dinlendirin."
        elif wearable["avg_hr_today"] > 90:
            desc += " Nabzınız yüksek seyrediyor, bugün düşük yoğunluklu hareketler yapın."
        elif wearable["hrv"] < 30:
            desc += " HRV değeriniz düşük; stres yüksek. Hafif egzersiz ve nefes egzersizleri öneririz."
    else:
        key = (lifestyle, health_goal, difficulty)
        title, desc, tag_labels = _RATIONALE_MAP.get(
            key,
            ("Kişisel Egzersiz Planı", "Profilinize göre oluşturulmuş kişisel egzersiz önerileri.", ["💪 Aktif", "❤️ Sağlıklı"]),
        )
        # Adım sayısına göre ek bilgi
        steps = wearable["step_count"]
        if steps < 3000:
            desc += f" Bugün yalnızca {steps:,} adım attınız — yürüyüş öncelikli plan hazırlandı."
        elif steps > 10000:
            desc += f" Bugün {steps:,} adım ile çok aktifsiniz! Toparlanma skoru: {wearable['recovery_score']}/100."

    return {
        "title":       title,
        "description": desc,
        "tags":        [{"label": lbl} for lbl in tag_labels],
    }


def _build_recommendations(exercise_keys: list[str], difficulty: str) -> list[dict]:
    result = []
    for ek in exercise_keys:
        ex = _EX[ek]
        result.append({
            "icon":      ex["icon"],
            "type":      ex["type"],
            "duration":  ex["duration"][difficulty],
            "intensity": ex["intensity"][difficulty],
            "desc":      ex["desc"][difficulty],
            "color":     ex["color"],
        })
    return result


# ══════════════════════════════════════════════════════════════════════════════
#  24 Saatlik KAH Simülasyonu
# ══════════════════════════════════════════════════════════════════════════════

def _simulate_heart_rate_hourly(resting_hr: int) -> list[float]:
    pattern = [
        0.88, 0.85, 0.82, 0.80, 0.82, 0.90,
        1.05, 1.15, 1.35, 1.40, 1.25, 1.15,
        1.10, 1.12, 1.08, 1.05, 1.10, 1.50,
        1.55, 1.30, 1.15, 1.05, 0.98, 0.92,
    ]
    return [round(resting_hr * p, 1) for p in pattern]


# ══════════════════════════════════════════════════════════════════════════════
#  Ana Servis Fonksiyonu
# ══════════════════════════════════════════════════════════════════════════════

async def get_user_exercise_plan(user_id: str, difficulty: str = "normal") -> dict:
    """
    Kullanıcı için kişiselleştirilmiş egzersiz planı oluşturur.
    Hem health_profiles hem daily_wearable_logs verilerini kullanır.
    Herhangi bir veri eksikliğinde güvenli varsayılan değerler devreye girer.
    """
    try:
        # 1. Kullanıcı profilini çek
        pool = await get_pool()
        row = await pool.fetchrow(
            "SELECT age, weight_kg, height_cm, gender, lifestyle, health_goal, medical_conditions FROM health_profiles WHERE user_id = $1 LIMIT 1",
            user_id,
        )

        if not row:
            age, lifestyle, health_goal, gender = 30, "Orta", "maintain", "erkek"
            medical_conditions: list[str] = []
        else:
            age                = row["age"]        or 30
            lifestyle          = row["lifestyle"]  or "Orta"
            health_goal        = row["health_goal"] or "maintain"
            gender             = (row["gender"] or "erkek").lower()
            medical_conditions = list(row["medical_conditions"] or [])

        resting_hr = 62 if gender in ("erkek", "male") else 68

        # 2. Wearable verisini DB'den çek
        wearable = await _get_wearable_context(user_id, age=age)

        # 3. Haftalık istatistikleri çek
        weekly_stats = await _get_weekly_stats(user_id)

        # Gerçek resting_hr varsa onu kullan
        if wearable.get("resting_hr"):
            resting_hr = wearable["resting_hr"]

        # 4. Temel egzersiz listesini lifestyle×goal matrisinden al
        base_keys = list(_EXERCISE_MATRIX.get((lifestyle, health_goal), ["walking", "yoga"]))

        # 5. Yaşa göre egzersiz ayarla
        base_keys, difficulty = _apply_age_adjustments(base_keys, age, difficulty)

        # 6. Medikal kısıtlamalara göre filtrele
        base_keys, difficulty = _apply_medical_restrictions(base_keys, medical_conditions, difficulty)

        # 7. Wearable verilerine göre egzersiz listesini ve difficulty'yi ayarla
        adjusted_keys, difficulty = _apply_wearable_adjustments(base_keys, wearable, difficulty)

        # 8. Bileşenleri oluştur
        hr_zones        = calculate_hr_zones(age, health_goal)
        recommendations = _build_recommendations(adjusted_keys, difficulty)
        weekly_plan     = await _build_weekly_plan(health_goal, user_id)
        rationale       = _build_rationale(lifestyle, health_goal, difficulty, wearable)
        hr_hourly       = _simulate_heart_rate_hourly(resting_hr)

        return {
            "rationale":         rationale,
            "recommendations":   recommendations,
            "hr_zone":           hr_zones,
            "weekly_plan":       weekly_plan,
            "heart_rate_hourly": hr_hourly,
            "recovery_score":    wearable["recovery_score"],
            "weekly_stats":      weekly_stats,
        }

    except Exception as e:
        import traceback, logging
        logging.error(f"[ExerciseService] Beklenmedik hata: {e}\n{traceback.format_exc()}")

        # Haftalık planı güvenle oluşturmayı dene (user_id hâlâ erişilebilir)
        try:
            fallback_plan = await _build_weekly_plan("maintain", user_id)
        except Exception:
            # DB de erişilemiyorsa statik şablon kullan
            fallback_plan = [
                {"day": d, "activity": a, "done": False}
                for d, a in _WEEKLY_PLANS["maintain"]
            ]

        return {
            "rationale": {
                "title": "Kişisel Egzersiz Planı",
                "description": "Verileriniz yüklenirken genel bir plan oluşturuldu.",
                "tags": [{"label": "💪 Aktif"}, {"label": "❤️ Sağlıklı"}],
            },
            "recommendations":   _build_recommendations(["walking", "yoga"], "normal"),
            "hr_zone":           calculate_hr_zones(30, "maintain"),
            "weekly_plan":       fallback_plan,
            "heart_rate_hourly": _simulate_heart_rate_hourly(65),
            "recovery_score":    50,
            "weekly_stats": {
                "total_active_minutes": 0,
                "total_calories":       0,
                "workouts_done":        0,
                "streak_days":          0,
            },
        }
