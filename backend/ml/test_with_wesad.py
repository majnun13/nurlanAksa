"""
WESAD Veri Seti ile Aksa Risk Modeli Deneme Scripti
====================================================
WESAD'ın E4_Data klasöründeki CSV'leri kullanarak:
  HR   → avg_hr_bpm
  IBI  → hrv_ms (kalp ritim değişkenliği)
  TEMP → temp_celsius
alanlarını çıkarır ve modelimizi bu verilerle test eder.

Kullanım:
  python backend/ml/test_with_wesad.py
"""

import os
import sys
import zipfile
import numpy as np
import pandas as pd
import joblib
import io
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score

ARCHIVE_PATH = "/Users/yavuz/Desktop/archive.zip"
MODEL_DIR    = os.path.join(os.path.dirname(__file__), "models")
MODEL_PATH   = os.path.join(MODEL_DIR, "anomaly_model.pkl")

# WESAD katılımcı ID'leri
SUBJECTS = ["S2","S3","S4","S5","S6","S7","S8","S9","S10","S11","S13","S14","S15","S16","S17"]

# ── 1. WESAD CSV'lerinden veri çek ────────────────────────────────────────────
def extract_wesad_features() -> pd.DataFrame:
    rows = []
    print(f"📦 Zip açılıyor: {ARCHIVE_PATH}")

    with zipfile.ZipFile(ARCHIVE_PATH, "r") as zf:
        all_names = zf.namelist()

        for subj in SUBJECTS:
            prefix = f"WESAD/{subj}/{subj}_E4_Data/"
            hr_file   = prefix + "HR.csv"
            ibi_file  = prefix + "IBI.csv"
            temp_file = prefix + "TEMP.csv"

            # Dosya var mı kontrol et
            missing = [f for f in [hr_file, ibi_file, temp_file] if f not in all_names]
            if missing:
                print(f"  ⚠️  {subj}: Eksik dosya {missing}, atlanıyor.")
                continue

            try:
                # HR — ilk satır başlangıç zamanı+örnekleme hızı, ikinci satır'dan veri
                with zf.open(hr_file) as f:
                    hr_raw = pd.read_csv(f, header=None, skiprows=2, names=["hr"])
                avg_hr = float(hr_raw["hr"].mean())

                # IBI — sütunlar: zaman(s), IBI(s)  → HRV = std(IBI)*1000 ms
                with zf.open(ibi_file) as f:
                    ibi_raw = pd.read_csv(f, header=None, skiprows=1, names=["t","ibi"])
                ibi_ms = ibi_raw["ibi"] * 1000  # saniyeden ms'ye
                hrv_ms = float(ibi_ms.std())    # RMSSD yerine std (yaklaşık)

                # TEMP — ilk satır meta, ikinciden veri
                with zf.open(temp_file) as f:
                    temp_raw = pd.read_csv(f, header=None, skiprows=2, names=["temp"])
                avg_temp = float(temp_raw["temp"].mean())

                # Özellikler hazır — yaş/BMI/profil bilgisi yok, NaN olarak işaretle
                row = {
                    "avg_hr_bpm": avg_hr,
                    "hrv_ms": hrv_ms,
                    "step_count": np.nan,        # WESAD'da yok
                    "sleep_score": np.nan,       # WESAD'da yok
                    "spo2_pct": np.nan,          # WESAD'da yok
                    "temp_celsius": avg_temp,
                    "age": np.nan,               # WESAD'da yok
                    "bmi": np.nan,               # WESAD'da yok
                    "has_heart_disease": 0,      # sağlıklı gönüllüler
                    "chronic_conditions_count": 0,
                    "subject": subj,
                }
                rows.append(row)
                print(f"  ✅ {subj}: HR={avg_hr:.1f} bpm | HRV={hrv_ms:.1f} ms | Temp={avg_temp:.2f}°C")

            except Exception as e:
                print(f"  ❌ {subj}: {e}")
                continue

    df = pd.DataFrame(rows)
    print(f"\n📊 Toplam {len(df)} katılımcı verisi yüklendi.\n")
    return df


# ── 2. Risk skoru tahmin ve değerlendirme ────────────────────────────────────
def evaluate():
    print("=" * 60)
    print("  WESAD ↔ Aksa Risk Modeli Deneme Testi")
    print("=" * 60)

    # Mevcut model var mı?
    if not os.path.exists(MODEL_PATH):
        print(f"❌ Model bulunamadı: {MODEL_PATH}")
        print("   Önce 'python backend/ml/train_anomaly_model.py' çalıştırın.")
        sys.exit(1)

    model = joblib.load(MODEL_PATH)
    print(f"✅ Model yüklendi: {MODEL_PATH}\n")

    # WESAD verisi yükle
    df = extract_wesad_features()

    if df.empty:
        print("❌ Hiç veri çıkarılamadı. Zip dosyasını kontrol edin.")
        sys.exit(1)

    # Feature sırası — model bununla eğitildi
    FEATURES = [
        "avg_hr_bpm", "hrv_ms", "step_count", "sleep_score",
        "spo2_pct", "temp_celsius", "age", "bmi",
        "has_heart_disease", "chronic_conditions_count",
    ]
    X = df[FEATURES].values

    # ── Tahmin ──────────────────────────────────────────────────────────────
    scores = model.predict(X)
    scores = np.clip(scores, 0, 100)

    print("─" * 60)
    print(f"{'Katılımcı':<12} {'HR (bpm)':<12} {'HRV (ms)':<12} {'Temp (°C)':<12} {'Risk Skoru'}")
    print("─" * 60)

    for i, row in df.iterrows():
        s = scores[i]
        level = "🟢 Düşük" if s < 30 else "🟡 Orta" if s < 70 else "🔴 Yüksek"
        print(
            f"{row['subject']:<12} "
            f"{row['avg_hr_bpm']:<12.1f} "
            f"{row['hrv_ms']:<12.1f} "
            f"{row['temp_celsius']:<12.2f} "
            f"{s:.1f}/100  {level}"
        )

    print("─" * 60)
    print(f"\n📈 Özet İstatistikler:")
    print(f"   Ortalama Risk Skoru : {scores.mean():.1f}")
    print(f"   Min Risk            : {scores.min():.1f}  ({df.iloc[scores.argmin()]['subject']})")
    print(f"   Max Risk            : {scores.max():.1f}  ({df.iloc[scores.argmax()]['subject']})")
    print(f"   Std Sapma           : {scores.std():.1f}")

    # Risk dağılımı
    low  = (scores < 30).sum()
    mid  = ((scores >= 30) & (scores < 70)).sum()
    high = (scores >= 70).sum()
    total = len(scores)
    print(f"\n🎯 Risk Dağılımı:")
    print(f"   🟢 Düşük  (<30):   {low}/{total} katılımcı (%{low/total*100:.0f})")
    print(f"   🟡 Orta   (30-70): {mid}/{total} katılımcı (%{mid/total*100:.0f})")
    print(f"   🔴 Yüksek (>70):   {high}/{total} katılımcı (%{high/total*100:.0f})")

    # WESAD sağlıklı gönüllüler olduğu için beklenti: çoğu düşük/orta risk
    print("\n💡 Not: WESAD katılımcıları sağlıklı gönüllülerdir.")
    print("   Beklenti: çoğunluğu Düşük veya Orta risk bölgesinde olmalı.")
    print("   Yüksek çıkarsa → model sadece HR/HRV/Temp ile çalışıyor,")
    print("   yaş/BMI/hastalık bilgisi olmadığı için skoru hafif şişirebilir.")
    print("=" * 60)


if __name__ == "__main__":
    evaluate()
