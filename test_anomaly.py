import sys
sys.path.insert(0, "backend")
from app.services.anomaly_service import anomaly_service

scenarios = {
    "Normal (İyi Gün)":    {"avg_hr_bpm": 68, "hrv_ms": 55, "sleep_score": 82, "spo2_pct": 99, "step_count": 9500},
    "Orta Stres":          {"avg_hr_bpm": 83, "hrv_ms": 30, "sleep_score": 50, "spo2_pct": 97, "step_count": 4000},
    "Kötü Gün":            {"avg_hr_bpm": 95, "hrv_ms": 18, "sleep_score": 30, "spo2_pct": 96, "step_count": 1500},
    "Kritik (Düşük SpO2)": {"avg_hr_bpm": 105, "hrv_ms": 14, "sleep_score": 20, "spo2_pct": 91, "step_count": 800},
}

for name, data in scenarios.items():
    r = anomaly_service.evaluate_wearable_data(data)
    print(f"[{name}] Seviye={r['level']} Skor={r['score']} Anomali={r['has_anomaly']}")
    print(f"  -> {r['message']}\n")
