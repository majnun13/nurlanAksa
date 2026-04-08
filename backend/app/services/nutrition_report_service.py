# ─────────────────────────────────────────────────────────────
#  Beslenme Rapor Servisi
#
#  Haftalık / Aylık raporlar ve kişiye özel akıllı öneriler.
#  Kullanıcının meal_logs verileri + health_profiles hedefleri
#  karşılaştırılarak senaryoya uygun öneriler üretilir.
# ─────────────────────────────────────────────────────────────

from datetime import date, timedelta
from ..core.database import get_pool
from .nutrition_target_service import get_user_nutrition_targets


# ═══════════════════════════════════════════════════════════════
#  VERİ SORGULARI
# ═══════════════════════════════════════════════════════════════

async def get_meals_by_date(user_id: str, target_date: date) -> list[dict]:
    """Belirli bir güne ait tüm öğünleri döner."""
    pool = await get_pool()
    rows = await pool.fetch(
        """
        SELECT id, food_name, meal_type, gram, protein, carbs, fat, calories, created_at
        FROM meal_logs
        WHERE user_id = $1 AND created_at::date = $2
        ORDER BY created_at ASC
        """,
        user_id, target_date,
    )
    return [
        {
            "id": str(r["id"]),
            "food_name": r["food_name"],
            "meal_type": r["meal_type"],
            "gram": float(r["gram"]),
            "protein": float(r["protein"]),
            "carbs": float(r["carbs"]),
            "fat": float(r["fat"]),
            "calories": float(r["calories"]),
            "created_at": str(r["created_at"]),
        }
        for r in rows
    ]


async def _get_daily_summaries(user_id: str, days: int) -> list[dict]:
    """
    Son N günün gün bazlı toplam kalori, protein, karb, yağ ve öğün sayısını döner.
    Öğün girişi olmayan günler de 0 değerleriyle listede yer alır.
    """
    pool = await get_pool()
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)

    rows = await pool.fetch(
        """
        SELECT
            created_at::date AS day,
            COALESCE(SUM(calories), 0) AS total_calories,
            COALESCE(SUM(protein), 0)  AS total_protein,
            COALESCE(SUM(carbs), 0)    AS total_carbs,
            COALESCE(SUM(fat), 0)      AS total_fat,
            COUNT(*)                   AS meal_count
        FROM meal_logs
        WHERE user_id = $1
          AND created_at::date >= $2
          AND created_at::date <= $3
        GROUP BY created_at::date
        ORDER BY created_at::date ASC
        """,
        user_id, start_date, end_date,
    )

    # Veritabanı sonuçlarını dict'e çevir
    db_data = {}
    for r in rows:
        db_data[r["day"]] = {
            "date": str(r["day"]),
            "total_calories": round(float(r["total_calories"])),
            "total_protein": round(float(r["total_protein"]), 1),
            "total_carbs": round(float(r["total_carbs"]), 1),
            "total_fat": round(float(r["total_fat"]), 1),
            "meal_count": int(r["meal_count"]),
        }

    # Boş günleri de 0 ile doldur
    result = []
    for i in range(days):
        d = start_date + timedelta(days=i)
        if d in db_data:
            result.append(db_data[d])
        else:
            result.append({
                "date": str(d),
                "total_calories": 0,
                "total_protein": 0,
                "total_carbs": 0,
                "total_fat": 0,
                "meal_count": 0,
            })

    return result


# ═══════════════════════════════════════════════════════════════
#  RAPOR ÜRETİCİ
# ═══════════════════════════════════════════════════════════════

async def get_weekly_report(user_id: str) -> dict:
    """Son 7 günün raporu + ortalamalar + öneriler."""
    daily = await _get_daily_summaries(user_id, 7)
    targets = await get_user_nutrition_targets(user_id)
    profile = await _get_user_profile(user_id)

    # Sadece öğün girişi olan günleri ortalamaya al
    active_days = [d for d in daily if d["meal_count"] > 0]
    averages = _calc_averages(active_days)

    recommendations = generate_recommendations(
        averages=averages,
        targets=targets,
        health_goal=profile.get("health_goal", "maintain"),
        period_label="hafta",
    )

    return {
        "period": "weekly",
        "start_date": daily[0]["date"],
        "end_date": daily[-1]["date"],
        "daily_data": daily,
        "active_days": len(active_days),
        "averages": averages,
        "targets": targets,
        "recommendations": recommendations,
    }


async def get_monthly_report(user_id: str) -> dict:
    """Son 30 günün raporu + ortalamalar + öneriler."""
    daily = await _get_daily_summaries(user_id, 30)
    targets = await get_user_nutrition_targets(user_id)
    profile = await _get_user_profile(user_id)

    active_days = [d for d in daily if d["meal_count"] > 0]
    averages = _calc_averages(active_days)

    recommendations = generate_recommendations(
        averages=averages,
        targets=targets,
        health_goal=profile.get("health_goal", "maintain"),
        period_label="ay",
    )

    # Hafta bazlı gruplu özet
    weekly_groups = []
    for i in range(0, 30, 7):
        week_data = daily[i:i+7]
        week_active = [d for d in week_data if d["meal_count"] > 0]
        weekly_groups.append({
            "week_label": f"Hafta {len(weekly_groups) + 1}",
            "start_date": week_data[0]["date"],
            "end_date": week_data[-1]["date"],
            "averages": _calc_averages(week_active),
            "active_days": len(week_active),
        })

    return {
        "period": "monthly",
        "start_date": daily[0]["date"],
        "end_date": daily[-1]["date"],
        "daily_data": daily,
        "weekly_groups": weekly_groups,
        "active_days": len(active_days),
        "averages": averages,
        "targets": targets,
        "recommendations": recommendations,
    }


# ═══════════════════════════════════════════════════════════════
#  YARDIMCI FONKSİYONLAR
# ═══════════════════════════════════════════════════════════════

def _calc_averages(active_days: list[dict]) -> dict:
    """Aktif günlerin ortalamalarını hesaplar."""
    if not active_days:
        return {
            "avg_calories": 0,
            "avg_protein": 0,
            "avg_carbs": 0,
            "avg_fat": 0,
            "avg_meals": 0,
        }
    n = len(active_days)
    return {
        "avg_calories": round(sum(d["total_calories"] for d in active_days) / n),
        "avg_protein": round(sum(d["total_protein"] for d in active_days) / n, 1),
        "avg_carbs": round(sum(d["total_carbs"] for d in active_days) / n, 1),
        "avg_fat": round(sum(d["total_fat"] for d in active_days) / n, 1),
        "avg_meals": round(sum(d["meal_count"] for d in active_days) / n, 1),
    }


async def _get_user_profile(user_id: str) -> dict:
    """Kullanıcının sağlık profilini getirir."""
    pool = await get_pool()
    row = await pool.fetchrow(
        "SELECT health_goal, lifestyle, gender FROM health_profiles WHERE user_id = $1",
        user_id,
    )
    if not row:
        return {"health_goal": "maintain", "lifestyle": "Orta", "gender": "Erkek"}
    return {
        "health_goal": row["health_goal"] or "maintain",
        "lifestyle": row["lifestyle"] or "Orta",
        "gender": row["gender"] or "Erkek",
    }


# ═══════════════════════════════════════════════════════════════
#  AKILLI ÖNERİ MOTORU
#
#  Her makro bileşen + kalori için ayrı analiz
#  Her hedef tipi (kilo ver / koru / al) için ayrı öneriler
#  Eşik: hedefin %80'i altı = düşük, %120'si üstü = yüksek
# ═══════════════════════════════════════════════════════════════

# ── Öneri Veritabanı ─────────────────────────────────────────
# Her tuple: (emoji, başlık, açıklama)

RECOMMENDATIONS_DB = {
    # ── PROTEİN DÜŞÜK ─────────────────────────────────────
    ("protein", "low", "lose_weight"): (
        "🥩", "Protein Yetersiz",
        "Kilo verirken kas kaybını önlemek için protein hayati önem taşır. "
        "Yumurta, tavuk göğsü, yoğurt ve baklagil tüketimini artırın. "
        "Her öğüne bir avuç protein kaynağı ekleyin."
    ),
    ("protein", "low", "maintain"): (
        "🥚", "Protein Artırın",
        "Dengeli beslenme için protein oranınızı artırmanız gerekiyor. "
        "Baklagiller, balık ve süt ürünleri iyi kaynaktır. "
        "Ara öğünlerde yoğurt veya peynir tercih edin."
    ),
    ("protein", "low", "gain_weight"): (
        "💪", "Protein Şart!",
        "Kas geliştirmek için proteini mutlaka artırmalısınız. "
        "Her öğüne bir protein kaynağı (et, balık, yumurta) ekleyin. "
        "Antrenman sonrası protein açısından zengin bir atıştırmalık yapın."
    ),

    # ── PROTEİN YÜKSEK ────────────────────────────────────
    ("protein", "high", "lose_weight"): (
        "✅", "Protein İyi",
        "Protein alımınız yeterli, bu kilo verme sürecinizi destekliyor. "
        "Böbrek sağlığı için aşırıya kaçmamaya dikkat edin ve su tüketiminizi artırın."
    ),
    ("protein", "high", "maintain"): (
        "⚖️", "Protein Dengesi",
        "Protein fazlası var, biraz karbonhidrat ve sebze ile dengeyi koruyun. "
        "Çeşitlilik sağlamak için bitkisel protein kaynaklarına da yer verin."
    ),
    ("protein", "high", "gain_weight"): (
        "👍", "Protein Tamam",
        "Protein iyi durumda! Fazla protein kas yapımını hızlandırmaz, "
        "bu yüzden karbonhidrat ve sağlıklı yağlarla dengeyi koruyun."
    ),

    # ── KARBONHİDRAT DÜŞÜK ────────────────────────────────
    ("carbs", "low", "lose_weight"): (
        "🌾", "Karb Dengesi",
        "Düşük karbonhidrat kilo vermeye yardımcı olabilir ama enerji için "
        "tam tahılları (yulaf, bulgur) ihmal etmeyin. Aşırı kısıtlama yorgunluk yapar."
    ),
    ("carbs", "low", "maintain"): (
        "⚡", "Enerji Düşük",
        "Enerji seviyenizi korumak için yulaf, bulgur, kepekli ekmek gibi "
        "kompleks karbonhidratlar ekleyin. Öğün atlamaktan kaçının."
    ),
    ("carbs", "low", "gain_weight"): (
        "🍚", "Karb Artırın!",
        "Kilo almak istiyorsanız karbonhidratı artırmalısınız. "
        "Pirinç, makarna, patates, muz gibi yoğun enerji kaynaklarını öğünlere ekleyin."
    ),

    # ── KARBONHİDRAT YÜKSEK ───────────────────────────────
    ("carbs", "high", "lose_weight"): (
        "🚫", "Karbı Azaltın",
        "Karbonhidrat fazlası kilo vermenizi zorlaştırır. "
        "Beyaz ekmek, şekerli içecekler ve hamur işlerinden kaçının. "
        "Bunları sebze ve protein ile değiştirin."
    ),
    ("carbs", "high", "maintain"): (
        "🔄", "Karb Kalitesi",
        "Karbonhidrat biraz fazla. Rafine şekerler yerine tam tahılları tercih edin. "
        "Meyve ve sebze ile doğal karbonhidrat alın."
    ),
    ("carbs", "high", "gain_weight"): (
        "📊", "Karb Kontrolü",
        "Karbonhidrat hedefin üzerinde ama kilo almak için faydalı. "
        "Kaliteli kaynaklardan (yulaf, tatlı patates) aldığınızdan emin olun."
    ),

    # ── YAĞ DÜŞÜK ─────────────────────────────────────────
    ("fat", "low", "lose_weight"): (
        "🥑", "Sağlıklı Yağ",
        "Yağ düşük – kilo verme için iyi ama vitamin emilimi için "
        "zeytinyağı, avokado ve ceviz gibi sağlıklı yağları tamamen kesmeyın."
    ),
    ("fat", "low", "maintain"): (
        "🫒", "Yağ Ekleyin",
        "Az yağ vitamin emilimini (A, D, E, K) azaltır. "
        "Günlük 1-2 yemek kaşığı zeytinyağı veya bir avuç badem ekleyin."
    ),
    ("fat", "low", "gain_weight"): (
        "🥜", "Yağ Artırın",
        "Kilo almak için fıstık ezmesi, avokado, kuruyemiş gibi "
        "yüksek kalorili sağlıklı yağları öğünlerinize ekleyin."
    ),

    # ── YAĞ YÜKSEK ────────────────────────────────────────
    ("fat", "high", "lose_weight"): (
        "🍳", "Yağı Azaltın",
        "Yağ oranınız yüksek – kızartma yerine fırında veya ızgara pişirme "
        "yöntemlerini tercih edin. Doymuş yağları (tereyağı, sucuk, sosis) sınırlayın."
    ),
    ("fat", "high", "maintain"): (
        "⚠️", "Yağ Dengesi",
        "Yağ fazlası var. Doymuş yağları (tereyağı, kırmızı et yağı) azaltıp "
        "doymamış yağlara (balık, zeytinyağı) yönelin."
    ),
    ("fat", "high", "gain_weight"): (
        "🐟", "Yağ Kalitesi",
        "Yağ biraz fazla ama kilo almak için sorun değil. "
        "Kaliteli kaynaklardan (balık yağı, zeytinyağı, avokado) aldığınızdan emin olun."
    ),

    # ── KALORİ DÜŞÜK ──────────────────────────────────────
    ("calories", "low", "lose_weight"): (
        "⚠️", "Çok Az Kalori!",
        "Hedefinizin çok altında kalıyorsunuz. Aşırı agresif kalori kısıtlaması "
        "kas kaybına ve metabolizma yavaşlamasına yol açar. Güvenli bir açık hedefleyin."
    ),
    ("calories", "low", "maintain"): (
        "🍽️", "Yeterli Yemiyorsunuz",
        "Yeterli kalori almıyorsunuz. Öğün atlamaktan kaçının ve "
        "dengeli 3 ana + 2 ara öğün planı yapın."
    ),
    ("calories", "low", "gain_weight"): (
        "📈", "Kalori Artırın!",
        "Kilo almak için kalori artırmalısınız. Ara öğünler, smoothie'ler "
        "ve yoğun enerji içeren atıştırmalıklar (kuruyemiş, kuru meyve) yardımcı olacaktır."
    ),

    # ── KALORİ YÜKSEK ─────────────────────────────────────
    ("calories", "high", "lose_weight"): (
        "🔴", "Kalori Fazlası",
        "Kalori hedefinizi aşıyorsunuz. Porsiyon kontrolüne dikkat edin, "
        "tabağınızın yarısını sebze ile doldurun ve şekerli içeceklerden kaçının."
    ),
    ("calories", "high", "maintain"): (
        "📉", "Porsiyon Kontrolü",
        "Kalori fazlası uzun vadede istenmeyen kilo alımına sebep olabilir. "
        "Porsiyon boyutlarını kontrol edin ve yavaş yemeye özen gösterin."
    ),
    ("calories", "high", "gain_weight"): (
        "🟢", "İyi Gidiyorsunuz!",
        "Kalori hedefinizin biraz üzerinde olmanız kilo alma hedefiniz için faydalı. "
        "Kaliteli besinlerden aldığınızdan emin olun."
    ),
}


def generate_recommendations(
    averages: dict,
    targets: dict,
    health_goal: str,
    period_label: str,
) -> list[dict]:
    """
    Kullanıcının dönemsel ortalamaları ile hedeflerini karşılaştırarak
    kişiye özel beslenme önerileri üretir.

    Eşikler:
      - Hedefin %80'inin altı → "düşük"
      - Hedefin %120'sinin üzeri → "yüksek"
      - Arada → "normal" (öneri üretmez)
    """
    if averages["avg_calories"] == 0:
        return [{
            "emoji": "📝",
            "title": "Veri Yetersiz",
            "description": f"Bu {period_label} içinde yeterli öğün kaydı bulunamadı. "
                          "Düzenli kayıt tutmak daha doğru öneriler almamızı sağlar.",
        }]

    recs = []
    checks = [
        ("calories", averages["avg_calories"], targets["calorie_target"]),
        ("protein",  averages["avg_protein"],  targets["protein_target"]),
        ("carbs",    averages["avg_carbs"],     targets["carbs_target"]),
        ("fat",      averages["avg_fat"],       targets["fat_target"]),
    ]

    for macro, avg_val, target_val in checks:
        if target_val <= 0:
            continue

        ratio = avg_val / target_val

        if ratio < 0.80:
            level = "low"
        elif ratio > 1.20:
            level = "high"
        else:
            continue  # Normal aralıkta, öneri gerekmez

        key = (macro, level, health_goal)
        if key in RECOMMENDATIONS_DB:
            emoji, title, desc = RECOMMENDATIONS_DB[key]
            # Yüzde bilgisi ekle
            pct = round(ratio * 100)
            desc_with_pct = f"Bu {period_label} ortalama {macro_label(macro)}: " \
                           f"hedefin %{pct}'i. " + desc
            recs.append({
                "emoji": emoji,
                "title": title,
                "description": desc_with_pct,
            })

    # Eğer hiç öneri yoksa tebrik mesajı
    if not recs:
        recs.append({
            "emoji": "🎉",
            "title": "Harika Gidiyorsunuz!",
            "description": f"Bu {period_label} tüm beslenme hedeflerinize uyumlu bir "
                          "şekilde beslendiniz. Böyle devam edin!",
        })

    return recs


def macro_label(key: str) -> str:
    """Makro adını Türkçe karşılığına çevirir."""
    labels = {
        "calories": "kalori alımınız",
        "protein": "protein alımınız",
        "carbs": "karbonhidrat alımınız",
        "fat": "yağ alımınız",
    }
    return labels.get(key, key)
