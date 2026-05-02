"""
WESAD Dataset Anomali Modeli Değerlendirme Script'i
==========================================================
Pencere: 10 Saniye
"""

import os
import pickle
import json
import numpy as np
import pandas as pd
from scipy import signal as scipy_signal
import joblib

# ─── Sabitler ────────────────────────────────────────────────────────────────
WESAD_PATH     = "/Users/guliyevs13/Downloads/WESAD"
SUBJECTS       = ["S2","S3","S4"] # Hızlı test için 3 denek
WINDOW_SEC     = 10
BVP_HZ         = 64
EDA_HZ         = 4
ACC_HZ         = 32
CHEST_HZ       = 700
BASELINE_LABEL = 1
STRESS_LABEL   = 2
OUTPUT_DIR     = "backend/ml/models"

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
    if len(series) < 2: return 0.0
    x = np.arange(len(series))
    slope, _ = np.polyfit(x, series, 1)
    return float(slope)

def extract_test_windows(subject_id: str) -> dict:
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
    
    baseline_rows = []
    stress_rows = []

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
        
        if dominant != BASELINE_LABEL and dominant != STRESS_LABEL:
            continue

        hr, hrv    = compute_hr_hrv(bvp_w)
        activity   = float(np.std(acc_w))
        eda_mean   = float(np.mean(eda_w))
        eda_std    = float(np.std(eda_w))
        eda_slope  = calc_slope(eda_w) * EDA_HZ
        t_mean     = float(np.mean(temp_w))
        t_slope    = calc_slope(temp_w) * EDA_HZ

        row = [hr, hrv, eda_mean, eda_std, eda_slope, t_mean, t_slope, activity]
        
        if dominant == BASELINE_LABEL:
            baseline_rows.append(row)
        elif dominant == STRESS_LABEL:
            stress_rows.append(row)

    return {"baseline": baseline_rows, "stress": stress_rows}

print("📥 Test verisi yükleniyor (S2, S3, S4)...")
all_baseline = []
all_stress = []

for subj in SUBJECTS:
    if not os.path.exists(f"{WESAD_PATH}/{subj}/{subj}.pkl"):
        continue
    res = extract_test_windows(subj)
    all_baseline.extend(res["baseline"])
    all_stress.extend(res["stress"])

print(f"📊 Toplam Baseline pencere: {len(all_baseline)}")
print(f"📊 Toplam Stres pencere: {len(all_stress)}")

# Modeli ve Scaler'ı yükle
scaler = joblib.load(f"{OUTPUT_DIR}/anomaly_scaler.pkl")
model = joblib.load(f"{OUTPUT_DIR}/anomaly_model.pkl")
with open(f"{OUTPUT_DIR}/anomaly_threshold.json", "r") as f:
    thresholds = json.load(f)

# Eşik esnekliğini artırmak için p85 seviyesini deniyoruz ki gerçek stresleri kaçırmayalım
# Çünkü modeli Contamination 0.15 ile eğittik.
def evaluate_data(data_rows, label_name):
    if not data_rows:
        return 0, 0
    X = np.array(data_rows)
    X_scaled = scaler.transform(X)
    
    scores = model.score_samples(X_scaled)
    s_min = thresholds["score_min"]
    s_max = thresholds["score_max"]
    normalized  = ((scores - s_max) / (s_min - s_max) * 100).clip(0, 100)
    
    # Daha esnek Anomali eşiği (p85) kullanıyoruz çünkü contamination=0.15
    threshold = thresholds.get("p85", thresholds["p95"])
    
    anomalies = np.sum(normalized > threshold)
    total = len(normalized)
    
    return anomalies, total

# Baseline testi (True Negative bulma - Normalin ne kadarını normal buldu)
b_anomalies, b_total = evaluate_data(all_baseline, "Baseline")
b_correct = b_total - b_anomalies

# Stress testi (True Positive bulma - Anomalinin ne kadarını anomali buldu)
s_anomalies, s_total = evaluate_data(all_stress, "Stress")
s_correct = s_anomalies

print("\n📈 YENİ DEĞERLENDİRME SONUÇLARI 📈")
print("=" * 50)
print(f"✅ Baseline (Normal Durum) Başarısı: %{(b_correct/b_total)*100:.1f} ({b_correct}/{b_total})")
print(f"🚨 Stres (Anomali Durumu) Başarısı:  %{(s_correct/s_total)*100:.1f} ({s_correct}/{s_total})")
print(f"\nGenel Doğruluk (Accuracy): %{((b_correct + s_correct) / (b_total + s_total))*100:.1f}")
