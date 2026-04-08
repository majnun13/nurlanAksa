# ─────────────────────────────────────────────────────────────
#  Kişiselleştirilmiş Kalori ve Makro Hedef Hesaplayıcı
#
#  Algoritma: Mifflin-St Jeor (1990) – BMR için en güvenilir formül
#  Kaynak: American Dietetic Association tarafından önerilendir.
#
#  BMR (Bazal Metabolizma Hızı):
#    Erkek:  10 × ağırlık(kg) + 6.25 × boy(cm) − 5 × yaş − 161 + 166
#    Kadın:  10 × ağırlık(kg) + 6.25 × boy(cm) − 5 × yaş − 161
#
#  TDEE = BMR × Aktivite Çarpanı
#  Hedef Kalori = TDEE ± hedef düzenlemesi
#
#  Makro Dağılımı (günlük kalori yüzdeleri):
#    Kilo Koruma:  Protein %25, Karb %45, Yağ %30
#    Kilo Verme:   Protein %30, Karb %40, Yağ %30
#    Kilo Alma:    Protein %25, Karb %50, Yağ %25
# ─────────────────────────────────────────────────────────────

from ..core.database import get_pool


# ── Aktivite Çarpanları (PAL – Physical Activity Level) ──────
ACTIVITY_MULTIPLIERS = {
    "Sedanter":  1.2,     # Hareketsiz yaşam, masa başı iş
    "Orta":      1.55,    # Haftada 3-5 gün orta düzey egzersiz
    "Aktif":     1.725,   # Haftada 6-7 gün yoğun egzersiz
}

# ── Hedef Ayarları (kcal farkı) ──────────────────────────────
# Tıbbi olarak güvenli kilo kaybı: haftada 0.5 kg → günde ~500 kcal açık
# Tıbbi olarak güvenli kilo alımı:  haftada 0.3-0.5 kg → günde ~350 kcal fazla
GOAL_ADJUSTMENTS = {
    "lose_weight":  -500,
    "maintain":       0,
    "gain_weight":  +350,
}

# ── Makro Yüzdeleri ──────────────────────────────────────────
MACRO_RATIOS = {
    "lose_weight":  {"protein": 0.30, "carbs": 0.40, "fat": 0.30},
    "maintain":     {"protein": 0.25, "carbs": 0.45, "fat": 0.30},
    "gain_weight":  {"protein": 0.25, "carbs": 0.50, "fat": 0.25},
}

# ── Minimum güvenli kalori sınırları (tıbbi güvenlik) ────────
MIN_CALORIES_MALE   = 1500
MIN_CALORIES_FEMALE = 1200


def calculate_bmr(weight_kg: float, height_cm: float, age: int, gender: str) -> float:
    """
    Mifflin-St Jeor denklemi ile BMR hesaplar.
    Erkek:  10W + 6.25H − 5A + 5
    Kadın:  10W + 6.25H − 5A − 161
    """
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    if gender and gender.lower() in ("erkek", "male"):
        return base + 5
    return base - 161


def calculate_tdee(bmr: float, lifestyle: str) -> float:
    """BMR'yi aktivite çarpanıyla çarparak TDEE (günlük toplam enerji harcaması) hesaplar."""
    multiplier = ACTIVITY_MULTIPLIERS.get(lifestyle, 1.4)
    return bmr * multiplier


def calculate_targets(
    weight_kg: float,
    height_cm: float,
    age: int,
    gender: str,
    lifestyle: str,
    health_goal: str,
) -> dict:
    """
    Tüm parametreleri alıp kişiselleştirilmiş kalori ve makro hedeflerini döner.

    Dönen dict:
    {
        "calorie_target": int,
        "protein_target": int,   # gram
        "carbs_target": int,     # gram
        "fat_target": int,       # gram
        "bmr": int,
        "tdee": int,
    }
    """
    bmr = calculate_bmr(weight_kg, height_cm, age, gender)
    tdee = calculate_tdee(bmr, lifestyle)

    # Hedef ayarlaması
    adjustment = GOAL_ADJUSTMENTS.get(health_goal, 0)
    calorie_target = tdee + adjustment

    # Güvenlik kontrolü – minimum sınırların altına düşmesin
    is_male = gender and gender.lower() in ("erkek", "male")
    min_cal = MIN_CALORIES_MALE if is_male else MIN_CALORIES_FEMALE
    calorie_target = max(calorie_target, min_cal)

    # Makro hesaplama
    ratios = MACRO_RATIOS.get(health_goal, MACRO_RATIOS["maintain"])

    # 1 gram protein = 4 kcal, 1 gram karbonhidrat = 4 kcal, 1 gram yağ = 9 kcal
    protein_target = (calorie_target * ratios["protein"]) / 4
    carbs_target   = (calorie_target * ratios["carbs"])   / 4
    fat_target     = (calorie_target * ratios["fat"])     / 9

    return {
        "calorie_target": round(calorie_target),
        "protein_target": round(protein_target),
        "carbs_target":   round(carbs_target),
        "fat_target":     round(fat_target),
        "bmr":            round(bmr),
        "tdee":           round(tdee),
    }


async def get_user_nutrition_targets(user_id: str) -> dict:
    """
    Veritabanından kullanıcının sağlık profilini çeker
    ve kişiselleştirilmiş beslenme hedeflerini hesaplar.
    Profil yoksa veya eksikse makul varsayılan değerler döner.
    """
    pool = await get_pool()
    row = await pool.fetchrow(
        """
        SELECT age, weight_kg, height_cm, gender, lifestyle, health_goal
        FROM health_profiles
        WHERE user_id = $1
        LIMIT 1
        """,
        user_id,
    )

    if not row:
        # Profil bulunamadıysa genel varsayılan
        return {
            "calorie_target": 2000,
            "protein_target": 100,
            "carbs_target": 225,
            "fat_target": 67,
            "bmr": 0,
            "tdee": 0,
        }

    # Eksik alanlar varsa varsayılan değerler kullanalım
    age       = row["age"]       or 25
    weight_kg = float(row["weight_kg"]) if row["weight_kg"] else 70.0
    height_cm = float(row["height_cm"]) if row["height_cm"] else 170.0
    gender    = row["gender"]    or "Erkek"
    lifestyle = row["lifestyle"] or "Orta"
    goal      = row["health_goal"] or "maintain"

    return calculate_targets(weight_kg, height_cm, age, gender, lifestyle, goal)
