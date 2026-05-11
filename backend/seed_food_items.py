"""
food_items tablosunu oluştur ve CSV'den besin verilerini yükle.

Kullanım:
    python seed_food_items.py
"""

import asyncio
import csv
import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

CSV_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "lib", "yapay_zeka", "yemek_besin_tablosu(Besin Tablosu).csv"
)

SCHEMA = "nurlanAksaV1"

CREATE_TABLE_SQL = f"""
CREATE TABLE IF NOT EXISTS "{SCHEMA}".food_items (
    id              SERIAL      PRIMARY KEY,
    name            TEXT        NOT NULL UNIQUE,
    protein_per_100g   NUMERIC(7,2),
    carbs_per_100g     NUMERIC(7,2),
    fat_per_100g       NUMERIC(7,2),
    calories_per_100g  NUMERIC(7,2),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

INSERT_SQL = f"""
INSERT INTO "{SCHEMA}".food_items (name, protein_per_100g, carbs_per_100g, fat_per_100g, calories_per_100g)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (name) DO UPDATE SET
    protein_per_100g  = EXCLUDED.protein_per_100g,
    carbs_per_100g    = EXCLUDED.carbs_per_100g,
    fat_per_100g      = EXCLUDED.fat_per_100g,
    calories_per_100g = EXCLUDED.calories_per_100g;
"""


def parse_number(value: str) -> float | None:
    """Virgül/nokta karışık sayıları float'a çevir."""
    if not value or not value.strip():
        return None
    cleaned = value.strip().replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def load_csv(path: str) -> list[dict]:
    """CSV dosyasını oku ve temizlenmiş satırları döndür."""
    rows = []
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.reader(f, delimiter=";")
        header = next(reader)
        # Trailing semicolondan kaynaklanan boş sütunu temizle
        header = [h.strip().lower() for h in header if h.strip()]

        for line in reader:
            if not line or not line[0].strip():
                continue

            name = line[0].strip()
            protein = parse_number(line[1]) if len(line) > 1 else None
            carbs = parse_number(line[2]) if len(line) > 2 else None
            fat = parse_number(line[3]) if len(line) > 3 else None
            calories = parse_number(line[4]) if len(line) > 4 else None

            # Tüm besin değerleri boşsa atla
            if all(v is None for v in [protein, carbs, fat, calories]):
                print(f"  ⚠️  Atlanıyor (tüm değerler boş): {name}")
                continue

            rows.append({
                "name": name,
                "protein": protein or 0,
                "carbs": carbs or 0,
                "fat": fat or 0,
                "calories": calories or 0,
            })
    return rows


async def main():
    print(f"📂 CSV yolu: {CSV_PATH}")
    if not os.path.exists(CSV_PATH):
        print("❌ CSV dosyası bulunamadı!")
        return

    foods = load_csv(CSV_PATH)
    print(f"✅ {len(foods)} yemek CSV'den okundu.")

    # search_path olmadan bağlan — schema'yı SQL içinde açıkça belirtiyoruz
    raw_url = DATABASE_URL.split("?")[0] if "?" in DATABASE_URL else DATABASE_URL
    conn = await asyncpg.connect(raw_url)
    try:
        # search_path ayarla
        await conn.execute(f'SET search_path TO "{SCHEMA}"')

        # Tabloyu oluştur
        await conn.execute(CREATE_TABLE_SQL)
        print("✅ food_items tablosu oluşturuldu (varsa atlandı).")

        # Verileri ekle
        count = 0
        for food in foods:
            await conn.execute(
                INSERT_SQL,
                food["name"],
                food["protein"],
                food["carbs"],
                food["fat"],
                food["calories"],
            )
            count += 1

        print(f"✅ {count} yemek veritabanına yüklendi.")

        # Doğrulama
        total = await conn.fetchval("SELECT COUNT(*) FROM food_items")
        print(f"📊 Toplam food_items kayıt sayısı: {total}")

        # Örnek sorgu
        sample = await conn.fetch("SELECT name, calories_per_100g FROM food_items ORDER BY name LIMIT 5")
        print("\n🍽️  Örnek kayıtlar:")
        for row in sample:
            print(f"   {row['name']}: {row['calories_per_100g']} kcal/100g")

    finally:
        await conn.close()

    print("\n🎉 Tamamlandı!")


if __name__ == "__main__":
    asyncio.run(main())
