"""
WESAD Stres Etiketi ↔ Aksa Risk Modeli Anlamlı Doğruluk Testi
=============================================================
WESAD pkl dosyasından:
  - Label=1 (Baseline)  → model DÜŞÜK risk vermeli  (< 40)
  - Label=2 (Stres)     → model YÜKSEK/ORTA risk vermeli  (> 30)

Bu iki grubun risk ortalamasına bakarak modelin
"stresin farkına varıp varmadığını" ölçeriz.
"""

import os
import sys
import pickle
import numpy as np
import joblib

ARCHIVE_PATH = "/Users/yavuz/Desktop/archive.zip"
MODEL_PATH   = os.path.join(os.path.dirname(__file__), "models", "anomaly_model.pkl")

# Sadece S2'yi deneyelim (ilk katılımcı, ~800MB pkl)
# pkl içinde: {'signal': {...}, 'label': array([1,1,2,2,1,...,3,...])}
SUBJECT_PKL = "/tmp/S2_test.pkl"  # önce zip'ten çıkaracağız

def run():
    print("=" * 65)
    print("  WESAD Stres Etiketi → Aksa Risk Modeli Anlamlı Doğruluk Testi")
    print("=" * 65)

    if not os.path.exists(MODEL_PATH):
        print(f"❌ Model bulunamadı: {MODEL_PATH}")
        sys.exit(1)

    model = joblib.load(MODEL_PATH)
    print("✅ Model yüklendi\n")

    # pkl'yi zip'ten çıkar (sadece bir kere)
    import zipfile
    pkl_name = "WESAD/S2/S2.pkl"
    if not os.path.exists(SUBJECT_PKL):
        print(f"📦 {pkl_name} çıkarılıyor (bu biraz sürebilir ~800MB)...")
        with zipfile.ZipFile(ARCHIVE_PATH, "r") as zf:
            with zf.open(pkl_name) as src, open(SUBJECT_PKL, "wb") as dst:
                dst.write(src.read())
        print("✅ Çıkarıldı\n")
    else:
        print(f"✅ Zaten mevcut: {SUBJECT_PKL}\n")

    print("📂 pkl okunuyor...")
    with open(SUBJECT_PKL, "rb") as f:
        data = pickle.load(f, encoding="latin1")

    labels = data["label"]           # shape: (4255300,) — 700 Hz aligned
    signal = data["signal"]["wrist"]

    bvp_signal  = signal["BVP"].flatten()    # 64 Hz, shape (N,)
    temp_signal = signal["TEMP"].flatten()   # 4 Hz,  shape (M,)

    # BVP label eşlemesi: label 700 Hz, BVP 64 Hz → ratio = 64/700
    BVP_HZ  = 64
    LABEL_HZ = 700
    TEMP_HZ  = 4
    WINDOW_SEC = 11   # ~11 saniyelik pencere

    bvp_win  = BVP_HZ  * WINDOW_SEC   # 704 örnek
    label_win = LABEL_HZ * WINDOW_SEC  # 7700 örnek
    temp_win  = TEMP_HZ  * WINDOW_SEC  # 44 örnek

    n_windows = min(
        len(bvp_signal) // bvp_win,
        len(labels)     // label_win,
        len(temp_signal) // temp_win,
    )

    print(f"🔢 Toplam {n_windows} pencere analiz edilecek ({WINDOW_SEC}s aralık)")

    baseline_scores = []
    stress_scores   = []

    for i in range(n_windows):
        bvp_start   = i * bvp_win
        bvp_end     = bvp_start + bvp_win
        label_start = i * label_win
        label_end   = label_start + label_win
        temp_start  = i * temp_win
        temp_end    = temp_start + temp_win

        window_bvp = bvp_signal[bvp_start:bvp_end]

        # Bu penceredeki en sık etiketi al
        label_window = labels[label_start:label_end]
        unique, counts = np.unique(label_window, return_counts=True)
        label = unique[counts.argmax()]

        if label not in (1, 2):  # sadece baseline (1) ve stres (2)
            continue

        # HR tahmini: BVP sıfır geçiş sayısından
        bvp_norm = window_bvp - window_bvp.mean()
        crossings = np.where(np.diff(np.sign(bvp_norm)))[0]
        beats = len(crossings) // 2
        duration_min = bvp_win / BVP_HZ / 60
        est_hr = float(np.clip(beats / duration_min if duration_min > 0 else 72, 40, 180))

        # HRV tahmini: BVP std (stres sırasında daha düşük olur)
        hrv_est = float(np.clip(np.std(window_bvp) * 8, 10, 150))

        # Sıcaklık
        avg_temp = float(np.mean(temp_signal[temp_start:temp_end])) if temp_end <= len(temp_signal) else 33.0

        row = np.array([[
            est_hr,    # avg_hr_bpm
            hrv_est,   # hrv_ms
            np.nan,    # step_count
            np.nan,    # sleep_score
            np.nan,    # spo2_pct
            avg_temp,  # temp_celsius
            np.nan,    # age
            np.nan,    # bmi
            0,         # has_heart_disease
            0,         # chronic_conditions_count
        ]])

        score = float(np.clip(model.predict(row)[0], 0, 100))

        if label == 1:
            baseline_scores.append(score)
        elif label == 2:
            stress_scores.append(score)

    # ── Sonuçlar ──────────────────────────────────────────────────────────
    print("\n" + "─" * 65)
    print(f"{'Durum':<20} {'Pencere Sayısı':<18} {'Ort. Risk':<14} {'Min':<8} {'Max'}")
    print("─" * 65)

    if baseline_scores:
        print(f"{'🔵 Baseline (dinlenme)':<20} {len(baseline_scores):<18} "
              f"{np.mean(baseline_scores):<14.1f} {min(baseline_scores):<8.1f} {max(baseline_scores):.1f}")
    if stress_scores:
        print(f"{'🔴 Stres':<20} {len(stress_scores):<18} "
              f"{np.mean(stress_scores):<14.1f} {min(stress_scores):<8.1f} {max(stress_scores):.1f}")

    print("─" * 65)

    if baseline_scores and stress_scores:
        base_mean   = np.mean(baseline_scores)
        stress_mean = np.mean(stress_scores)
        diff        = stress_mean - base_mean
        direction_ok = stress_mean > base_mean

        print(f"\n📊 Stres farkı: {diff:+.1f} puan")
        print(f"✅ Model stres durumunu {'FARK ETTİ' if direction_ok else 'FARK ETMEDİ'}")

        # Basit doğruluk: baseline < 40 doğru mu? stres > baseline doğru mu?
        base_correct   = sum(s < 40 for s in baseline_scores)
        stress_correct = sum(s > base_mean for s in stress_scores)

        base_acc   = base_correct / len(baseline_scores) * 100
        stress_acc = stress_correct / len(stress_scores) * 100
        overall    = (base_correct + stress_correct) / (len(baseline_scores) + len(stress_scores)) * 100

        print(f"\n🎯 Yön Doğruluğu (Stres > Baseline mi?):")
        print(f"   Baseline pencereler doğru sınıflandırıldı : %{base_acc:.1f}")
        print(f"   Stres pencereler doğru sınıflandırıldı    : %{stress_acc:.1f}")
        print(f"   Genel doğruluk                            : %{overall:.1f}")
        print()
        if overall >= 70:
            print("✅ Model WESAD gerçek verisinde anlamlı şekilde çalışıyor!")
        elif overall >= 50:
            print("⚠️  Model kısmen çalışıyor — daha fazla gerçek veriyle eğitilmeli.")
        else:
            print("❌ Model stres-dinlenme ayrımını yapmakta zorlanıyor.")
            print("   → WESAD ile yeniden eğitim faydalı olur.")

    print("=" * 65)

if __name__ == "__main__":
    run()
