"""
10 farklı test kullanıcısını veritabanına ekler.
Her birinin sağlık profili, adım sayısı ve nabız verileri farklıdır.
"""
import asyncio
import asyncpg
import bcrypt
import uuid
from datetime import datetime, timezone

DB_URL = "postgresql://yavuz@localhost:5432/aksa"

# ── 10 Farklı Test Kullanıcısı ────────────────────────────────
TEST_USERS = [
    {
        "full_name": "Ahmet Yılmaz",
        "email": "ahmet.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 28, "weight_kg": 78.5, "height_cm": 178,
            "gender": "Erkek", "lifestyle": "Orta",
            "health_goal": "maintain",
            "dietary_restrictions": [],
            "medical_conditions": [],
        }
    },
    {
        "full_name": "Elif Kaya",
        "email": "elif.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 34, "weight_kg": 62.0, "height_cm": 165,
            "gender": "Kadın", "lifestyle": "Sedanter",
            "health_goal": "lose_weight",
            "dietary_restrictions": ["Glütensiz"],
            "medical_conditions": ["Tiroid"],
        }
    },
    {
        "full_name": "Mehmet Demir",
        "email": "mehmet.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 45, "weight_kg": 95.0, "height_cm": 182,
            "gender": "Erkek", "lifestyle": "Sedanter",
            "health_goal": "lose_weight",
            "dietary_restrictions": [],
            "medical_conditions": ["Tip 2 Diyabet", "Hipertansiyon"],
        }
    },
    {
        "full_name": "Selin Arslan",
        "email": "selin.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 22, "weight_kg": 55.0, "height_cm": 162,
            "gender": "Kadın", "lifestyle": "Aktif",
            "health_goal": "gain_weight",
            "dietary_restrictions": ["Vejetaryen"],
            "medical_conditions": [],
        }
    },
    {
        "full_name": "Burak Çelik",
        "email": "burak.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 38, "weight_kg": 88.0, "height_cm": 176,
            "gender": "Erkek", "lifestyle": "Orta",
            "health_goal": "lose_weight",
            "dietary_restrictions": [],
            "medical_conditions": ["Yüksek Kolesterol"],
        }
    },
    {
        "full_name": "Zeynep Şahin",
        "email": "zeynep.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 52, "weight_kg": 70.0, "height_cm": 160,
            "gender": "Kadın", "lifestyle": "Orta",
            "health_goal": "maintain",
            "dietary_restrictions": [],
            "medical_conditions": ["Osteoporoz"],
        }
    },
    {
        "full_name": "Can Öztürk",
        "email": "can.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 19, "weight_kg": 68.0, "height_cm": 180,
            "gender": "Erkek", "lifestyle": "Aktif",
            "health_goal": "gain_weight",
            "dietary_restrictions": [],
            "medical_conditions": [],
        }
    },
    {
        "full_name": "Ayşe Koç",
        "email": "ayse.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 41, "weight_kg": 82.0, "height_cm": 168,
            "gender": "Kadın", "lifestyle": "Sedanter",
            "health_goal": "lose_weight",
            "dietary_restrictions": ["Laktoz İntoleransı"],
            "medical_conditions": ["Anemi"],
        }
    },
    {
        "full_name": "Furkan Aktaş",
        "email": "furkan.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 30, "weight_kg": 73.0, "height_cm": 175,
            "gender": "Erkek", "lifestyle": "Aktif",
            "health_goal": "maintain",
            "dietary_restrictions": [],
            "medical_conditions": [],
        }
    },
    {
        "full_name": "Neslihan Yıldız",
        "email": "neslihan.test@aksa.app",
        "password": "Test1234!",
        "profile": {
            "age": 60, "weight_kg": 67.0, "height_cm": 158,
            "gender": "Kadın", "lifestyle": "Sedanter",
            "health_goal": "maintain",
            "dietary_restrictions": [],
            "medical_conditions": ["Hipertansiyon", "Tip 2 Diyabet"],
        }
    },
]


async def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


async def main():
    conn = await asyncpg.connect(DB_URL)
    print("✅ Veritabanına bağlanıldı\n")

    created = []

    for user_data in TEST_USERS:
        email = user_data["email"]

        # Zaten varsa atla
        existing = await conn.fetchrow("SELECT id FROM users WHERE email = $1", email)
        if existing:
            print(f"⚠️  {email} zaten mevcut, atlanıyor...")
            continue

        # Şifreyi hashle
        pw_hash = await hash_password(user_data["password"])
        user_id = str(uuid.uuid4())

        # Kullanıcıyı ekle
        await conn.execute(
            """
            INSERT INTO users (id, full_name, email, password_hash, is_active, is_email_verified, onboarding_done)
            VALUES ($1, $2, $3, $4, TRUE, TRUE, TRUE)
            """,
            user_id, user_data["full_name"], email, pw_hash
        )

        # Sağlık profilini ekle
        p = user_data["profile"]
        await conn.execute(
            """
            INSERT INTO health_profiles
              (user_id, age, weight_kg, height_cm, gender, lifestyle, health_goal,
               dietary_restrictions, medical_conditions)
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
            """,
            user_id,
            p["age"], p["weight_kg"], p["height_cm"],
            p["gender"], p["lifestyle"], p["health_goal"],
            p["dietary_restrictions"], p["medical_conditions"]
        )

        print(f"✅ {user_data['full_name']} ({email}) eklendi")
        created.append(user_data)

    await conn.close()

    # Özet tablo
    print("\n" + "="*70)
    print(f"{'Ad Soyad':<22} {'E-posta':<30} {'Şifre'}")
    print("="*70)
    for u in created:
        print(f"{u['full_name']:<22} {u['email']:<30} {u['password']}")
    print("="*70)
    print(f"\nToplam {len(created)} kullanıcı eklendi.")


if __name__ == "__main__":
    asyncio.run(main())
