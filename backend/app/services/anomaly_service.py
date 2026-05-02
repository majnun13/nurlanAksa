import os
import json
import logging
import numpy as np
import joblib

logger = logging.getLogger(__name__)

# Model Yolları
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "ml", "models")
MODEL_PATH = os.path.join(MODEL_DIR, "anomaly_model.pkl")
SCALER_PATH = os.path.join(MODEL_DIR, "anomaly_scaler.pkl")
THRESHOLDS_PATH = os.path.join(MODEL_DIR, "anomaly_threshold.json")

class AnomalyService:
    def __init__(self):
        self.model = None
        self.scaler = None
        self.thresholds = {}
        self.is_ready = False
        self._load_models()

    def _load_models(self):
        try:
            if not os.path.exists(MODEL_PATH):
                logger.warning("Anomali modeli bulunamadı. Lütfen önce modeli eğitin.")
                return

            self.model = joblib.load(MODEL_PATH)
            self.scaler = joblib.load(SCALER_PATH)
            
            with open(THRESHOLDS_PATH, "r") as f:
                self.thresholds = json.load(f)
                
            self.is_ready = True
            logger.info("Anomali modelleri başarıyla yüklendi.")
        except Exception as e:
            logger.error(f"Anomali modelleri yüklenirken hata: {e}")

    def evaluate_wearable_data(self, wearable_data: dict) -> dict:
        """
        Gelen günlük giyilebilir veri özelliklerini alır ve anomali skoru hesaplar.
        """
        # Model eğitilmediyse basit kural tabanlı yedeğe dön (Fallback)
        if not self.is_ready:
            return self._fallback_anomaly(wearable_data)

        try:
            # Gerekli özellikleri çıkar (Eğer veri eksikse varsayılan kullan)
            hr = float(wearable_data.get("avg_hr_bpm", 72.0))
            hrv = float(wearable_data.get("hrv_ms", 45.0))
            
            # Giyilebilir cihaz verilerinden ML modeline uygun EDA/TEMP üretimi
            # Not: Gerçek saatte bu veriler yoksa, nabız/hrv'den dolaylı tahmin (veya sentetik) gönderilebilir
            # Şimdilik stabil kalması için varsayılan normal EDA/TEMP değerleri kullanıyoruz
            eda_mean = 1.3
            eda_std = 0.04
            eda_slope = 0.0
            temp_mean = 33.3
            temp_slope = 0.0
            
            # Günlük aktivite bazında modelin beklediği aktivite standard sapması tahmini
            steps = float(wearable_data.get("step_count", 5000))
            activity = min(steps / 200, 35.0) # Basit adım -> activity std mappingi

            features = np.array([[hr, hrv, eda_mean, eda_std, eda_slope, temp_mean, temp_slope, activity]])
            
            # Normalizasyon
            features_scaled = self.scaler.transform(features)
            
            # Skor hesapla (IsolationForest)
            scores = self.model.score_samples(features_scaled)
            
            s_min = self.thresholds["score_min"]
            s_max = self.thresholds["score_max"]
            
            # Normalize (0=Normal, 100=Kritik Anomali)
            normalized = float(np.clip((scores[0] - s_max) / (s_min - s_max) * 100, 0, 100))
            
            # Eşik Değerlendirmesi
            p85 = self.thresholds.get("p85", 38.0)
            p95 = self.thresholds.get("p95", 54.0)
            p97 = self.thresholds.get("p97", 62.0)
            critical = self.thresholds.get("critical", 90.0)
            
            level = "Düşük"
            has_anomaly = False
            msg = "Her şey yolunda görünüyor. Değerleriniz normal (Baseline) profilinize uyumlu."
            
            if normalized > critical:
                has_anomaly = True
                level = "Kritik"
                msg = "Fizyolojik verilerinizde ciddi (Kritik) sapmalar var. Doktora görünmeyi veya dinlenmeyi ihmal etmeyin."
            elif normalized > p97:
                has_anomaly = True
                level = "Yüksek"
                msg = "Belirgin anomali saptandı. Stres altında veya hastalanmak üzere olabilirsiniz."
            elif normalized > p95:
                has_anomaly = True
                level = "Orta"
                msg = "Normalden orta düzeyde bir sapma mevcut. Gün içinde hafif bir stres yaşamış olabilirsiniz."
            elif normalized > p85:
                has_anomaly = True
                level = "Hafif"
                msg = "Verilerinizde hafif düzeyde bir dalgalanma var. Dinlenmeye dikkat edin."

            return {
                "has_anomaly": has_anomaly,
                "level": level,
                "message": msg,
                "score": normalized
            }
            
        except Exception as e:
            logger.error(f"Anomali hesaplama hatası: {e}")
            return self._fallback_anomaly(wearable_data)

    def _fallback_anomaly(self, wearable: dict) -> dict:
        """Model yokken eski kural tabanlı basit motor"""
        avg_hr   = wearable.get("avg_hr_bpm", 72)
        sleep_sc = wearable.get("sleep_score", 70)
        hrv      = wearable.get("hrv_ms", 45)
        spo2     = wearable.get("spo2_pct", 98)

        score = 0.0
        
        if spo2 < 94:
            return {"has_anomaly": True, "level": "Yüksek", "message": f"Kan oksijen seviyeniz ({spo2}%) düşük.", "score": 85.0}
        if avg_hr > 100:
            return {"has_anomaly": True, "level": "Orta", "message": f"Bugünkü ortalama nabzınız ({avg_hr} bpm) yüksek.", "score": 75.0}
        if sleep_sc < 35:
            return {"has_anomaly": True, "level": "Orta", "message": "Uyku kaliteniz kritik seviyede düşük.", "score": 65.0}
        if hrv < 25:
            return {"has_anomaly": True, "level": "Hafif", "message": "HRV değeriniz düşük, vücudunuz yorgun.", "score": 45.0}

        return {"has_anomaly": False, "level": "Düşük", "message": "Her şey yolunda görünüyor.", "score": 10.0}

anomaly_service = AnomalyService()
