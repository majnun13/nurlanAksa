"""
🎓 SUNUM DEMO KULLANICISI — Barış Koç
Tüm uygulama özelliklerini sergileyebilecek zengin verili bir demo hesap.

Kullanım:
    cd backend
    python seed_demo_baris.py

Giriş Bilgileri:
    E-posta : baris.koc@aksa.app
    Şifre   : Demo1234!
"""

import asyncio
import asyncpg
import bcrypt
import os
import uuid
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

load_dotenv()
DB_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:Aksa123@localhost:5432/postgres")

SCHEMA = "nurlanAksaV1"

# ── Barış Koç Profili ─────────────────────────────────────────
DEMO_USER = {
    "full_name": "Barış Koç",
    "email": "baris.koc@aksa.app",
    "password": "Demo1234!",
    "profile": {
        "age": 26,
        "weight_kg": 81.0,
        "height_cm": 179.0,
        "gender": "Erkek",
        "lifestyle": "Orta",           # Orta aktif bir üniversite öğrencisi
        "health_goal": "maintain",     # Kilosunu korumak istiyor
        "dietary_restrictions": [],
        "medical_conditions": [],
        "medications": None,
    },
}

# ── 14 Günlük Wearable Verileri ──────────────────────────────
# Gerçekçi bir hikaye: Barış normalde aktif ama hafta içi sınavlar yüzünden
# stresliydi, uyku kalitesi düştü, sonra hafta sonu toparladı.
# (gün_offset, adım, ort_nabız, dinlenme, uyku_saat, uyku_skoru, hrv, spo2, aktif_dk, kalori, sıcaklık)
WEARABLE_14_DAYS = [
    # --- 2 hafta öncesi (Pzt-Cum: sınav haftası, stresli) ---
    (-13,  3200, 88, 72, 5.0, 42, 28, 97, 15, 220, 36.9),   # Pzt - sınav stresi
    (-12,  2800, 91, 75, 4.5, 38, 25, 96, 12, 200, 37.0),   # Sal - çok az uyku
    (-11,  4100, 85, 70, 5.5, 48, 32, 97, 22, 260, 36.8),   # Çar - biraz düzeldi
    (-10,  3600, 87, 73, 5.0, 44, 29, 97, 18, 240, 36.9),   # Per - yine stresli
    (-9,   2500, 93, 78, 4.0, 35, 22, 96, 10, 190, 37.1),   # Cum - en kötü gün

    # --- Hafta sonu: dinlenme + toparlanma ---
    (-8,   7800, 74, 63, 8.0, 72, 48, 98, 45, 420, 36.5),   # Cmt - güzel uyku
    (-7,   8500, 72, 61, 8.5, 78, 52, 99, 50, 450, 36.4),   # Paz - iyice toparlama

    # --- Geçen hafta (normal yaşam) ---
    (-6,   6200, 76, 64, 7.0, 68, 45, 98, 38, 370, 36.6),   # Pzt
    (-5,   7400, 74, 62, 7.5, 73, 50, 98, 42, 400, 36.5),   # Sal
    (-4,   8900, 71, 59, 8.0, 80, 55, 99, 55, 480, 36.4),   # Çar - spor günü
    (-3,   5800, 77, 65, 7.0, 66, 42, 98, 35, 360, 36.6),   # Per
    (-2,   9500, 70, 58, 8.0, 82, 58, 99, 60, 510, 36.4),   # Cum - spor günü
    (-1,  10200, 68, 56, 8.5, 85, 62, 99, 65, 540, 36.3),   # Cmt - en iyi gün
    (0,    7600, 73, 61, 7.5, 76, 51, 98, 48, 430, 36.5),   # BUGÜN
]

# ── Yemek Kayıtları (bugün + dün) ────────────────────────────
# (gün_offset, yemek_adı, öğün_tipi, gram, protein, karb, yağ, kalori)
MEAL_LOGS = [
    # --- DÜN ---
    (-1, "haslanmis-yumurta", "Kahvaltı", 120, 14.88, 0.80, 12.96, 178.80),
    (-1, "ekmek",             "Kahvaltı",  60,  4.86, 31.68,  0.54, 153.60),
    (-1, "cay",               "Kahvaltı", 200,  0.20,  0.00,  0.00,   0.00),
    (-1, "yogurt",            "Kahvaltı", 150,  4.50,  7.35,  5.10,  93.00),

    (-1, "pilav",             "Öğle",     200,  4.80, 54.67, 10.18, 332.80),
    (-1, "tavuk-sote",        "Öğle",     180, 30.06,  8.12, 16.02, 304.20),
    (-1, "coban-salatasi",    "Öğle",     150,  2.10, 11.33,  2.55,  78.00),
    (-1, "ayran",             "Öğle",     200,  3.96,  5.42,  4.00,  74.66),

    (-1, "mercimek-corbasi",  "Akşam",    300,  7.50, 24.84,  0.60, 138.00),
    (-1, "salcali-makarna",   "Akşam",    250,  8.75, 62.05,  2.25, 300.00),

    (-1, "muz",               "Ara Öğün", 120,  0.72, 21.17,  0.36,  92.40),

    # --- BUGÜN ---
    (0, "omlet",             "Kahvaltı", 150, 18.30,  3.45, 21.60, 276.00),
    (0, "ekmek",             "Kahvaltı",  80,  6.48, 42.24,  0.72, 204.80),
    (0, "cay",               "Kahvaltı", 200,  0.20,  0.00,  0.00,   0.00),
    (0, "siyah-zeytin",      "Kahvaltı",  40,  0.34,  2.42,  4.36,  46.96),

    (0, "doner",             "Öğle",     200, 24.00, 45.00, 22.60, 478.00),
    (0, "cacik",             "Öğle",     150,  3.00,  4.73,  3.15,  61.50),

    (0, "mercimek-koftesi",  "Ara Öğün", 100,  4.00, 16.93,  4.50, 130.00),
]


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


async def main():
    raw_url = DB_URL.split("?")[0] if "?" in DB_URL else DB_URL
    conn = await asyncpg.connect(raw_url)
    await conn.execute(f'SET search_path TO "{SCHEMA}"')
    print("✅ Veritabanına bağlanıldı\n")

    email = DEMO_USER["email"]
    today = datetime.now(timezone.utc).date()

    # ── 1. Kullanıcıyı oluştur ───────────────────────────────
    existing = await conn.fetchrow("SELECT id FROM users WHERE email = $1", email)
    if existing:
        user_id = str(existing["id"])
        print(f"⚠️  {email} zaten var (id={user_id[:8]}…), veriler güncelleniyor...")
        # Eski verileri temizle
        await conn.execute("DELETE FROM meal_logs WHERE user_id = $1", existing["id"])
        await conn.execute("DELETE FROM daily_wearable_logs WHERE user_id = $1", existing["id"])
        await conn.execute("DELETE FROM health_profiles WHERE user_id = $1", existing["id"])
    else:
        user_id = str(uuid.uuid4())
        pw_hash = hash_password(DEMO_USER["password"])
        await conn.execute(
            """
            INSERT INTO users (id, full_name, email, password_hash, is_active, is_email_verified, onboarding_done)
            VALUES ($1, $2, $3, $4, TRUE, TRUE, TRUE)
            """,
            user_id, DEMO_USER["full_name"], email, pw_hash,
        )
        print(f"✅ Kullanıcı oluşturuldu: {DEMO_USER['full_name']}")

    # ── 2. Sağlık profili ─────────────────────────────────────
    p = DEMO_USER["profile"]
    await conn.execute(
        """
        INSERT INTO health_profiles
          (user_id, age, weight_kg, height_cm, gender, lifestyle, health_goal,
           dietary_restrictions, medical_conditions, medications)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
        ON CONFLICT (user_id) DO UPDATE SET
          age = EXCLUDED.age,
          weight_kg = EXCLUDED.weight_kg,
          height_cm = EXCLUDED.height_cm,
          gender = EXCLUDED.gender,
          lifestyle = EXCLUDED.lifestyle,
          health_goal = EXCLUDED.health_goal,
          dietary_restrictions = EXCLUDED.dietary_restrictions,
          medical_conditions = EXCLUDED.medical_conditions,
          medications = EXCLUDED.medications
        """,
        user_id,
        p["age"], p["weight_kg"], p["height_cm"],
        p["gender"], p["lifestyle"], p["health_goal"],
        p["dietary_restrictions"], p["medical_conditions"],
        p["medications"],
    )
    bmi = p["weight_kg"] / ((p["height_cm"] / 100) ** 2)
    print(f"✅ Sağlık profili eklendi: {p['age']} yaş, {p['weight_kg']}kg, {p['height_cm']}cm, BMI={bmi:.1f}")

    # ── 3. 14 Günlük Wearable Verileri ────────────────────────
    print(f"\n📊 Wearable verileri ekleniyor (14 gün)...")
    print(f"{'Tarih':<12} {'Adım':>6} {'Nabız':>6} {'Uyku':>5} {'HRV':>4} {'SpO2':>5} {'Sıcaklık':>9}")
    print("-" * 55)

    for (offset, steps, avg_hr, rest_hr, sleep_h, sleep_sc, hrv, spo2, active_min, cal, temp) in WEARABLE_14_DAYS:
        log_date = today + timedelta(days=offset)
        await conn.execute(
            """
            INSERT INTO daily_wearable_logs
              (user_id, log_date, step_count, avg_hr_bpm, resting_hr_bpm,
               sleep_hours, sleep_score, hrv_ms, spo2_pct, active_minutes, calories_burned, temp_celsius)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (user_id, log_date) DO UPDATE SET
              step_count = EXCLUDED.step_count, avg_hr_bpm = EXCLUDED.avg_hr_bpm,
              resting_hr_bpm = EXCLUDED.resting_hr_bpm, sleep_hours = EXCLUDED.sleep_hours,
              sleep_score = EXCLUDED.sleep_score, hrv_ms = EXCLUDED.hrv_ms,
              spo2_pct = EXCLUDED.spo2_pct, active_minutes = EXCLUDED.active_minutes,
              calories_burned = EXCLUDED.calories_burned, temp_celsius = EXCLUDED.temp_celsius
            """,
            user_id, log_date, steps, avg_hr, rest_hr,
            sleep_h, sleep_sc, hrv, spo2, active_min, cal, temp,
        )
        marker = " ← BUGÜN" if offset == 0 else ""
        print(f"{log_date}  {steps:>6,} {avg_hr:>5}bpm {sleep_h:>4}s {hrv:>4}ms {spo2:>4}% {temp:>8.1f}°C{marker}")

    print(f"✅ {len(WEARABLE_14_DAYS)} gün wearable verisi eklendi")

    # ── 4. Yemek Kayıtları ────────────────────────────────────
    print(f"\n🍽️  Yemek kayıtları ekleniyor...")

    meal_count = 0
    for (offset, food_name, meal_type, gram, protein, carbs, fat, calories) in MEAL_LOGS:
        # Saat ayarla — kahvaltı 08:00, öğle 13:00, akşam 19:30, ara öğün 16:00
        hour_map = {"Kahvaltı": 8, "Öğle": 13, "Akşam": 19, "Ara Öğün": 16}
        hour = hour_map.get(meal_type, 12)
        created_at = datetime(today.year, today.month, today.day, hour, 30, 0, tzinfo=timezone.utc) + timedelta(days=offset)

        await conn.execute(
            """
            INSERT INTO meal_logs (user_id, food_name, meal_type, gram, protein, carbs, fat, calories, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            """,
            user_id, food_name, meal_type, gram, protein, carbs, fat, calories, created_at,
        )
        meal_count += 1

    print(f"✅ {meal_count} yemek kaydı eklendi")

    # ── 5. Özet ───────────────────────────────────────────────
    total_meals_today = sum(1 for m in MEAL_LOGS if m[0] == 0)
    total_cal_today = sum(m[7] for m in MEAL_LOGS if m[0] == 0)

    await conn.close()

    print("\n" + "=" * 55)
    print("🎓 SUNUM DEMO HESABI HAZIR!")
    print("=" * 55)
    print(f"  👤 Ad Soyad   : {DEMO_USER['full_name']}")
    print(f"  📧 E-posta    : {email}")
    print(f"  🔑 Şifre      : {DEMO_USER['password']}")
    print(f"  🎂 Yaş        : {p['age']}")
    print(f"  ⚖️  Kilo/Boy   : {p['weight_kg']}kg / {p['height_cm']}cm (BMI: {bmi:.1f})")
    print(f"  🏃 Yaşam Tarzı: {p['lifestyle']}")
    print(f"  🎯 Hedef      : {p['health_goal']}")
    print(f"  📊 Wearable   : {len(WEARABLE_14_DAYS)} gün veri")
    print(f"  🍽️  Bugün Öğün : {total_meals_today} öğün ({total_cal_today:.0f} kcal)")
    print("=" * 55)
    print("\n💡 Sunumda gösterebileceğin şeyler:")
    print("  • Dashboard: 14 günlük adım/nabız/uyku grafikleri")
    print("  • Sınav haftası stresi → düşük HRV, kötü uyku → sonra toparlanma")
    print("  • Anomali tespiti: Sınav haftasında uyarı verecek")
    print("  • Yemek kayıtları: Bugün + dün detaylı öğünler")
    print("  • Egzersiz önerileri: Orta aktif profile göre plan")
    print("  • AI Chat: Barış'ın profiline göre kişisel öneriler")


if __name__ == "__main__":
    asyncio.run(main())
