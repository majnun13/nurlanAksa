-- ─────────────────────────────────────────────────────────────
--  OTP Brute Force Koruması için Gerekli Tablo
--  auth_service.py'de verify_email() fonksiyonunda kullanılıyor.
--  Bu migration'ı çalıştırmadan OTP rate limiting çalışmaz.
-- ─────────────────────────────────────────────────────────────

SET search_path TO "nurlanAksaV1";

CREATE TABLE IF NOT EXISTS otp_attempts (
    id           BIGSERIAL PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index: user_id + attempted_at üzerinde hızlı sorgu için
CREATE INDEX IF NOT EXISTS idx_otp_attempts_user_time
    ON otp_attempts (user_id, attempted_at DESC);

-- Otomatik temizleme (opsiyonel): 24 saatten eski kayıtları sil
-- pg_cron veya manuel çalıştırılabilir:
-- DELETE FROM otp_attempts WHERE attempted_at < NOW() - INTERVAL '24 hours';


