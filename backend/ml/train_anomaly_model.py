"""
WESAD Dataset ile Anomali Tespiti - Eğitim Script'i (Gelişmiş Versiyon)
==========================================================
Pencere: 10 Saniye
Özellikler: Eğimler (Slope) dahil
Kontaminasyon: %15
"""

import os
import pickle
import json
import numpy as np
import pandas as pd
from scipy import signal as scipy_signal
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import IsolationForest
import joblib

# ─── Sabitler ────────────────────────────────────────────────────────────────
WESAD_PATH     = "/Users/guliyevs13/Downloads/WESAD"
SUBJECTS       = ["S2","S3","S4","S5","S6","S7","S8","S9",
                  "S10","S11","S13","S14","S15","S16","S17"]
WINDOW_SEC     = 10  # 60 saniyeden 10 saniyeye düşürüldü
BVP_HZ         = 64
EDA_HZ         = 4
ACC_HZ         = 32
CHEST_HZ       = 700
BASELINE_LABEL = 1
OUTPUT_DIR     = "backend/ml/models"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Yeni Özellikler eklendi
FEATURES       = ["hr", "hrv", "eda_mean", "eda_std", "eda_slope", "temp_mean", "temp_slope", "activity"]

def compute_hr_hrv(bvp_win: np.ndarray) -> tuple:
    b, a = scipy_signal.butter(2, [0.5, 4.0], btype='bandpass', fs=BVP_HZ)
    filt = scipy_signal.filtfilt(b, a, bvp_win)
    peaks, _ = scipy_signal.find_peaks(filt, distance=int(BVP_HZ * 0.4))
    if len(peaks) < 2:
        return 72.0, 45.0
    rr  = np.diff(peaks) / BVP_HZ * 1000
    hr  = float(np.clip(60000 / np.mean(rr), 30, 200))
    hrv = float(np.clip(np.sqrt(np.mean(np.diff(rr) ** 2)), 0, 200))
    return hr, hrv

def calc_slope(series: np.ndarray) -> float:
    """Sinyalin genel eğimini bulur (Artış/Azalış hızı)"""
    if len(series) < 2: return 0.0
    x = np.arange(len(series))
    slope, _ = np.polyfit(x, series, 1)
    return float(slope)

def extract_windows(subject_id: str) -> list:
    path = f"{WESAD_PATH}/{subject_id}/{subject_id}.pkl"
    with open(path, "rb") as f:
        data = pickle.load(f, encoding="latin1")

    bvp          = data["signal"]["wrist"]["BVP"].flatten()
    eda          = data["signal"]["wrist"]["EDA"].flatten()
    temp         = data["signal"]["wrist"]["TEMP"].flatten()
    acc          = data["signal"]["wrist"]["ACC"]
    chest_labels = data["label"]

    win_bvp = WINDOW_SEC * BVP_HZ
    win_eda = WINDOW_SEC * EDA_HZ
    win_acc = WINDOW_SEC * ACC_HZ

    n = min(len(bvp) // win_bvp, len(eda) // win_eda, len(acc) // win_acc)
    rows = []

    for i in range(n):
        bvp_w  = bvp[i*win_bvp  : (i+1)*win_bvp]
        eda_w  = eda[i*win_eda  : (i+1)*win_eda]
        temp_w = temp[i*win_eda : (i+1)*win_eda]
        acc_w  = acc[i*win_acc  : (i+1)*win_acc]

        l0 = int(i * WINDOW_SEC * CHEST_HZ)
        l1 = l0 + WINDOW_SEC * CHEST_HZ
        if l1 > len(chest_labels):
            break
        dominant = int(np.bincount(chest_labels[l0:l1].astype(int)).argmax())
        if dominant != BASELINE_LABEL:
            continue

        hr, hrv    = compute_hr_hrv(bvp_w)
        activity   = float(np.std(acc_w))
        eda_mean   = float(np.mean(eda_w))
        eda_std    = float(np.std(eda_w))
        eda_slope  = calc_slope(eda_w) * EDA_HZ  # Saniyedeki değişim hızına oranla
        t_mean     = float(np.mean(temp_w))
        t_slope    = calc_slope(temp_w) * EDA_HZ

        rows.append([hr, hrv, eda_mean, eda_std, eda_slope, t_mean, t_slope, activity])

    return rows


# ─── Veri Yükleme ────────────────────────────────────────────────────────────
print("📥 WESAD verisi yükleniyor (Gelişmiş)...")
all_rows = []

for subj in SUBJECTS:
    if not os.path.exists(f"{WESAD_PATH}/{subj}/{subj}.pkl"):
        print(f"  ⚠️  {subj} bulunamadı, atlandı.")
        continue
    try:
        rows = extract_windows(subj)
        all_rows.extend(rows)
        print(f"  ✅ {subj}: {len(rows)} pencere (10s)")
    except Exception as e:
        print(f"  ❌ {subj} hata: {e}")

print(f"\n📊 Toplam Baseline pencere: {len(all_rows)}")
if not all_rows:
    raise ValueError("Hiç pencere yüklenemedi!")

df = pd.DataFrame(all_rows, columns=FEATURES)
print("\nİstatistikler:")
print(df.describe().round(4))

# ─── Normalizasyon ────────────────────────────────────────────────────────────
X = df.values
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)
joblib.dump(scaler, f"{OUTPUT_DIR}/anomaly_scaler.pkl")
print(f"\n💾 Scaler kaydedildi.")

# ─── IsolationForest ─────────────────────────────────────────────────────────
print("🏋️ IsolationForest eğitiliyor (Contamination=0.15)...")
# Contamination 0.05 -> 0.15'e çıkarıldı ki stresli durumları daha iyi yakalasın
model = IsolationForest(n_estimators=200, contamination=0.15, random_state=42, n_jobs=-1)
model.fit(X_scaled)
joblib.dump(model, f"{OUTPUT_DIR}/anomaly_model.pkl")
print(f"💾 Model kaydedildi.")

# ─── Eşik Hesapla ────────────────────────────────────────────────────────────
scores      = model.score_samples(X_scaled)
score_min   = float(np.min(scores))
score_max   = float(np.max(scores))
normalized  = ((scores - score_max) / (score_min - score_max) * 100).clip(0, 100)

threshold_info = {
    "score_min": score_min,
    "score_max": score_max,
    "p85":       float(np.percentile(normalized, 85)),
    "p95":       float(np.percentile(normalized, 95)),
    "p97":       float(np.percentile(normalized, 97)),
    "p99":       float(np.percentile(normalized, 99)),
    "critical":  90.0,
    "features":  FEATURES,
}

with open(f"{OUTPUT_DIR}/anomaly_threshold.json", "w") as f:
    json.dump(threshold_info, f, indent=2)
print(f"💾 Eşik kaydedildi.")

print("\n✅ Yeni Eğitim tamamlandı!")
print("=" * 50)
for k, v in threshold_info.items():
    if k not in ("features",):
        print(f"  {k}: {v}")
