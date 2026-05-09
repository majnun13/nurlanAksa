-- Migration: daily_wearable_logs tablosuna temp_celsius sütunu ekle
-- Bu migrasyon, mevcut veritabanına uygulanmalıdır.
-- schema.sql sıfırdan oluşturuyorsa zaten dahildir.

SET search_path TO "nurlanAksaV1";

ALTER TABLE daily_wearable_logs
ADD COLUMN IF NOT EXISTS temp_celsius NUMERIC(4,1);

COMMENT ON COLUMN daily_wearable_logs.temp_celsius IS 'Vücut sıcaklığı (°C) – Apple Watch Series 8+ veya Samsung Galaxy Watch 5+ gerektirir';
