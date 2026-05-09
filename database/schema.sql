-- ============================================================
--  AKSA – PostgreSQL Veritabanı Şeması
--  Versiyon : 1.1.0
--  Güncelleme : 2026-04-07
--
--  Çalıştırma:
--    DBeaver'da kullanacağınız veritabanını seçin,
--    bu dosyayı SQL Editor'e yapıştırın ve F5'e basın.
--    Tablolar "nurlanAksaV1" şemasının içine kurulacaktır.
-- ============================================================

-- ─── Şema (Schema) Ayarı ────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS "nurlanAksaV1";
SET search_path TO "nurlanAksaV1";

-- ─── Uzantılar ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid() için

-- ─── Temizleme (Eski tabloları sil) ─────────────────────────
DROP TABLE IF EXISTS daily_wearable_logs CASCADE;
DROP TABLE IF EXISTS meal_logs CASCADE;
DROP TABLE IF EXISTS health_profiles CASCADE;
DROP TABLE IF EXISTS email_verification_tokens CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS otp_attempts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ─── users ──────────────────────────────────────────────────
-- Temel kimlik doğrulama tablosu.
-- Sonradan eklenecek tüm tablolar (health_profiles, meals, vb.)
-- bu tablonun "id" sütununa foreign key ile bağlanacak.
CREATE TABLE IF NOT EXISTS users (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Kimlik bilgileri
    full_name        TEXT        NOT NULL,
    email            TEXT        NOT NULL UNIQUE,
    password_hash    TEXT        NOT NULL,          -- bcrypt hash, asla plain-text değil

    -- Hesap durumu
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    is_email_verified BOOLEAN    NOT NULL DEFAULT FALSE,

    -- Zaman damgaları
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at    TIMESTAMPTZ,

    -- İleride kullanım için ayrılmış (şimdilik NULL kalabilir)
    -- Onboarding tamamlandı mı?
    onboarding_done  BOOLEAN     NOT NULL DEFAULT FALSE,
    -- Google / Apple OAuth için
    oauth_provider   TEXT,                          -- 'google' | 'apple' | NULL
    oauth_uid        TEXT                           -- provider tarafındaki uid
);

-- ─── İndeksler ─────────────────────────────────────────────
-- Email ile hızlı arama (login)
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- ─── Otomatik updated_at güncelleme fonksiyonu ─────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── sessions ──────────────────────────────────────────────
-- Oturum / token yönetimi için temel tablo.
-- (JWT kullanacaksanız bu tablo blacklist / refresh_token olarak kullanılır)
CREATE TABLE IF NOT EXISTS sessions (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token  TEXT        NOT NULL UNIQUE,
    expires_at     TIMESTAMPTZ NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_info    TEXT                             -- "iPhone 15 / iOS 17" vb.
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id      ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_token ON sessions (refresh_token);

-- ─── email_verification_tokens ─────────────────────────────
-- 6 haneli OTP kodları burada saklanır.
-- Kod kullanıldıktan veya süresi dolduktan sonra silinir.
CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       CHAR(6)     NOT NULL,           -- 6 haneli OTP
    expires_at  TIMESTAMPTZ NOT NULL,            -- 10 dakika geçerli
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_evt_user_id ON email_verification_tokens (user_id);

-- ─── health_profiles ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_profiles (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    age                   INT,
    weight_kg             NUMERIC(5,2),
    height_cm             NUMERIC(5,1),
    gender                TEXT,
    lifestyle             TEXT,           -- 'Sedanter' | 'Orta' | 'Aktif'
    health_goal           TEXT,           -- 'lose_weight' | 'maintain' | 'gain_weight'
    dietary_restrictions  TEXT[] DEFAULT '{}',
    medical_conditions    TEXT[] DEFAULT '{}',
    medications           TEXT,           -- Kullanılan ilaçlar (serbest metin)
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER trg_health_profiles_updated_at
BEFORE UPDATE ON health_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── meal_logs ─────────────────────────────────────────────
-- Kullanıcının eklediği öğün kayıtları
CREATE TABLE IF NOT EXISTS meal_logs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    food_name   TEXT        NOT NULL,
    meal_type   TEXT        NOT NULL,     -- 'Kahvaltı' | 'Öğle' | 'Akşam' | 'Ara öğün'
    gram        NUMERIC(7,2) NOT NULL,
    protein     NUMERIC(7,2) NOT NULL DEFAULT 0,
    carbs       NUMERIC(7,2) NOT NULL DEFAULT 0,
    fat         NUMERIC(7,2) NOT NULL DEFAULT 0,
    calories    NUMERIC(7,2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meal_logs_user_id ON meal_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_meal_logs_date ON meal_logs (user_id, ((created_at AT TIME ZONE 'UTC')::date));

-- ─── daily_wearable_logs ───────────────────────────────────────
-- Günlük giyilebilir cihaz verileri (adım, nabız, uyku vb.)
-- Şu an seed scripti ile dolduruluyor.
-- İleride HealthKit / Google Fit API entegrasyonuyla otomatik dolacak.
CREATE TABLE IF NOT EXISTS daily_wearable_logs (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    log_date         DATE        NOT NULL DEFAULT CURRENT_DATE,

    step_count       INT         DEFAULT 0,          -- Günlük adım sayısı
    avg_hr_bpm       INT,                             -- Ortalama kalp atış hızı (bpm)
    resting_hr_bpm   INT,                             -- Dinlenme kalp atış hızı (bpm)
    sleep_hours      NUMERIC(4,1),                    -- Uyku süresi (saat)
    sleep_score      INT,                             -- Uyku kalitesi 0-100
    hrv_ms           INT,                             -- Kalp atış değişkenliği (ms)
    spo2_pct         INT,                             -- Kan oksijen satürasyon yüzdesi
    active_minutes   INT,                             -- Aktif dakika sayısı
    calories_burned  INT,                             -- Yakılan kalori

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, log_date)                         -- Günde bir kayıt
);

CREATE INDEX IF NOT EXISTS idx_wearable_user_date ON daily_wearable_logs (user_id, log_date DESC);
