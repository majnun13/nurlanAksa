"""
daily_wearable_logs tablosunu oluşturur ve
10 test kullanıcısına gerçekçi ama birbirinden farklı wearable verileri ekler.
"""
import asyncio
import asyncpg

DB_URL = "postgresql://yavuz@localhost:5432/aksa"

# Her kullanıcının e-postası ve o günkü wearable verisi
WEARABLE_DATA = [
    # (email, adım, ort_nabız, dinlenme_nabız, uyku_saat, uyku_skoru, hrv_ms, spo2, aktif_dk, yakılan_kcal)
    # Ahmet - Genç, orta aktif, iyi uyku → Normal plan
    ("ahmet.test@aksa.app",  7500, 73, 62, 7.5, 76, 52, 98, 45, 420),
    # Elif - Sedanter, tiroid, uykusu kötüce → Biraz zorlanıyor
    ("elif.test@aksa.app",   2800, 82, 71, 6.0, 55, 36, 97, 18, 210),
    # Mehmet - 45 yaş, diyabet+HT, az adım, yüksek nabız → EASY moda düşmeli
    ("mehmet.test@aksa.app", 1500, 96, 84, 5.5, 44, 26, 96, 10, 180),
    # Selin - Genç, aktif, mükemmel uyku → Yoğun plan, HIIT öne çıkmalı
    ("selin.test@aksa.app", 13200, 67, 55, 8.5, 90, 68, 99, 80, 680),
    # Burak - Orta aktif, kolesterol, makul uyku
    ("burak.test@aksa.app",  5500, 78, 66, 7.0, 68, 43, 98, 35, 380),
    # Zeynep - 52 yaş, osteoporoz, az adım, uyku orta → Yüzme önerilmeli
    ("zeynep.test@aksa.app", 4200, 80, 70, 6.5, 62, 38, 97, 28, 290),
    # Can - 19 yaş, çok aktif, harika uyku → Güç antrenmanı öne çıkmalı
    ("can.test@aksa.app",   11800, 65, 52, 9.0, 87, 72, 99, 75, 650),
    # Ayşe - Sedanter, anemi, çok kötü uyku, yüksek nabız → KESİNLİKLE easy
    ("ayse.test@aksa.app",   1900, 91, 80, 4.5, 36, 28, 96, 12, 160),
    # Furkan - Aktif, iyi uyku, iyi toparlanma → Normal yoğun plan
    ("furkan.test@aksa.app", 9800, 70, 58, 8.0, 82, 60, 99, 60, 560),
    # Neslihan - 60 yaş, HT+diyabet, çok az adım, kötü uyku → easy + yürüyüş
    ("neslihan.test@aksa.app",3100, 87, 76, 5.5, 48, 30, 96, 20, 240),
]


async def main():
    conn = await asyncpg.connect(DB_URL)
    print("✅ Veritabanına bağlanıldı\n")

    # Tabloyu oluştur (yoksa)
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS daily_wearable_logs (
            id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            log_date         DATE        NOT NULL DEFAULT CURRENT_DATE,
            step_count       INT         DEFAULT 0,
            avg_hr_bpm       INT,
            resting_hr_bpm   INT,
            sleep_hours      NUMERIC(4,1),
            sleep_score      INT,
            hrv_ms           INT,
            spo2_pct         INT,
            active_minutes   INT,
            calories_burned  INT,
            created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE(user_id, log_date)
        )
    """)
    print("✅ daily_wearable_logs tablosu hazır\n")

    print(f"{'Ad/E-posta':<30} {'Adım':>7} {'Nabız':>6} {'Uyku':>5} {'HRV':>5} {'Toparlanma':>11}")
    print("-" * 70)

    for (email, steps, avg_hr, rest_hr, sleep_h, sleep_sc, hrv, spo2, active_min, calories) in WEARABLE_DATA:
        # Kullanıcı ID'sini bul
        user = await conn.fetchrow("SELECT id, full_name FROM users WHERE email = $1", email)
        if not user:
            print(f"⚠️  {email} bulunamadı, atlanıyor")
            continue

        # Toparlanma skoru hesapla (önizleme için)
        hrv_score = min(100, hrv * 2)
        hr_score  = max(0, 100 - (avg_hr - 60) * 2)
        recovery  = round(sleep_sc * 0.5 + hrv_score * 0.3 + hr_score * 0.2)

        # Wearable kaydını ekle (varsa güncelle)
        await conn.execute("""
            INSERT INTO daily_wearable_logs
              (user_id, log_date, step_count, avg_hr_bpm, resting_hr_bpm,
               sleep_hours, sleep_score, hrv_ms, spo2_pct, active_minutes, calories_burned)
            VALUES ($1, CURRENT_DATE, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (user_id, log_date) DO UPDATE SET
              step_count = EXCLUDED.step_count,
              avg_hr_bpm = EXCLUDED.avg_hr_bpm,
              resting_hr_bpm = EXCLUDED.resting_hr_bpm,
              sleep_hours = EXCLUDED.sleep_hours,
              sleep_score = EXCLUDED.sleep_score,
              hrv_ms = EXCLUDED.hrv_ms,
              spo2_pct = EXCLUDED.spo2_pct,
              active_minutes = EXCLUDED.active_minutes,
              calories_burned = EXCLUDED.calories_burned
        """,
            user["id"], steps, avg_hr, rest_hr,
            sleep_h, sleep_sc, hrv, spo2, active_min, calories
        )
        print(f"{user['full_name']:<30} {steps:>7,} {avg_hr:>5}bpm {sleep_h:>4}s {hrv:>4}ms {recovery:>10}/100")

    await conn.close()
    print("\n✅ Tüm wearable verileri eklendi!")
    print("\n📊 Beklenen algoritma davranışları:")
    print("  • Mehmet, Ayşe → EASY moda geçmeli (kötü uyku + yüksek nabız)")
    print("  • Elif, Neslihan → Yürüyüş öncelikli (az adım)")
    print("  • Zeynep → Yüksek nabız nedeniyle yüzme/yoga önerilmeli")
    print("  • Selin, Can → HIIT/Güç öne çıkmalı (çok aktif + iyi toparlanma)")
    print("  • Furkan, Ahmet → Normal yoğun plan")


if __name__ == "__main__":
    asyncio.run(main())
