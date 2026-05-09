import os
import logging
import numpy as np
import pandas as pd
import joblib

logger = logging.getLogger(__name__)

# Model Yolları
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "ml", "models")
MODEL_PATH = os.path.join(MODEL_DIR, "anomaly_model.pkl")

class AnomalyService:
    # Anomali skoru eşik değerleri (0–100 aralığı)
    # Kaynak: eğitim verisinin percentile dağılımına göre seçildi
    _THRESHOLD_HAFIF   = 38.0   # p85 — hafif dalgalanma
    _THRESHOLD_ORTA    = 54.0   # p95 — orta sapma
    _THRESHOLD_YUKSEK  = 62.0   # p97 — belirgin anomali
    _THRESHOLD_KRITIK  = 90.0   # Kritik — doktora bavuru

    def __init__(self):
        self.model = None
        self.is_ready = False
        self._load_models()

    def _load_models(self):
        try:
            if not os.path.exists(MODEL_PATH):
                logger.warning("Anomali modeli bulunamadı. Lütfen önce modeli eğitin.")
                return

            self.model = joblib.load(MODEL_PATH)
            self.is_ready = True
            logger.info("Yeni nesil HistGradientBoosting anomali modeli başarıyla yüklendi.")
        except Exception as e:
            logger.error(f"Anomali modelleri yüklenirken hata: {e}")

    def evaluate_wearable_data(self, wearable_data: dict, profile_data: dict = None) -> dict:
        """
        Gelen günlük giyilebilir veri özelliklerini alır ve anomali skoru hesaplar.
        """
        if profile_data is None:
            profile_data = {}
            
        # Model eğitilmediyse basit kural tabanlı yedeğe dön (Fallback)
        if not self.is_ready:
            return self._fallback_anomaly(wearable_data, profile_data)

        try:
            # 1. Temel Sensör Verileri (Zorunlu)
            hr = float(wearable_data.get("avg_hr_bpm", 72.0))
            hrv = float(wearable_data.get("hrv_ms", 45.0))
            steps = float(wearable_data.get("step_count", 5000.0))
            sleep_score = float(wearable_data.get("sleep_score", 70.0))
            
            # 2. Opsiyonel Sensör Verileri (Eksikse NaN olacak)
            spo2 = float(wearable_data.get("spo2_pct")) if wearable_data.get("spo2_pct") is not None else np.nan
            temp = float(wearable_data.get("temp_celsius")) if wearable_data.get("temp_celsius") is not None else np.nan
            
            # 3. Profil Verileri (Zorunlu - Varsayılan eklendi)
            age = float(profile_data.get("age", 30))
            bmi = float(profile_data.get("weight_kg", 70.0)) / ((float(profile_data.get("height_cm", 170.0)) / 100.0) ** 2)
            
            # Hastalık yükünü hesapla
            medical_conditions = profile_data.get("medical_conditions", [])
            if not isinstance(medical_conditions, list):
                medical_conditions = []
                
            chronic_count = len(medical_conditions)
            
            # Kalp hastalığı kontrolü
            has_heart_disease = 0
            for cond in medical_conditions:
                cond_lower = cond.lower()
                if "kalp" in cond_lower or "hipertansiyon" in cond_lower or "ritim" in cond_lower or "damar" in cond_lower:
                    has_heart_disease = 1
                    break

            # Tahmin için Pandas DataFrame oluştur (Eğitim sırasıyla aynı sütun isimleri)
            features_df = pd.DataFrame({
                'avg_hr_bpm': [hr],
                'hrv_ms': [hrv],
                'step_count': [steps],
                'sleep_score': [sleep_score],
                'spo2_pct': [spo2],
                'temp_celsius': [temp],
                'age': [age],
                'bmi': [bmi],
                'has_heart_disease': [has_heart_disease],
                'chronic_conditions_count': [chronic_count]
            })
            
            # Skor tahmin et
            predicted_score = self.model.predict(features_df)[0]
            
            # Normalize (0=Normal, 100=Kritik Anomali)
            normalized = float(np.clip(predicted_score, 0, 100))
            
            # Eşik Değerlendirmesi — sabıtlere bakınız
            level = "Düşük"
            has_anomaly = False
            msg = "Her şey yolunda görünüyor. Değerleriniz kişisel profilinize uygun."

            if normalized > self._THRESHOLD_KRITIK:
                has_anomaly = True
                level = "Kritik"
                msg = "Fizyolojik verilerinizde ciddi (Kritik) sapmalar var. Doktora görünmeyi veya dinlenmeyi ihmal etmeyin."
            elif normalized > self._THRESHOLD_YUKSEK:
                has_anomaly = True
                level = "Yüksek"
                msg = "Belirgin anomali saptandı. Stres altında veya hastalanmak üzere olabilirsiniz."
            elif normalized > self._THRESHOLD_ORTA:
                has_anomaly = True
                level = "Orta"
                msg = "Normalden orta düzeyde bir sapma mevcut. Gün içinde hafif bir stres yaşamış olabilirsiniz."
            elif normalized > self._THRESHOLD_HAFIF:
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
            return self._fallback_anomaly(wearable_data, profile_data)

    def _fallback_anomaly(self, wearable: dict, profile: dict) -> dict:
        """Model yokken eski kural tabanlı basit motor (Profile duyarlı)"""
        avg_hr   = wearable.get("avg_hr_bpm", 72)
        sleep_sc = wearable.get("sleep_score", 70)
        hrv      = wearable.get("hrv_ms", 45)
        spo2     = wearable.get("spo2_pct", 98)

        score = 0.0
        
        medical_conditions = profile.get("medical_conditions", []) if profile else []
        has_heart_disease = any("kalp" in c.lower() for c in medical_conditions)
        
        if spo2 < 94:
            return {"has_anomaly": True, "level": "Yüksek", "message": f"Kan oksijen seviyeniz ({spo2}%) düşük.", "score": 85.0}
            
        hr_limit = 90 if has_heart_disease else 100
        if avg_hr > hr_limit:
            return {"has_anomaly": True, "level": "Orta", "message": f"Bugünkü ortalama nabzınız ({avg_hr} bpm) yüksek.", "score": 75.0}
            
        if sleep_sc < 35:
            return {"has_anomaly": True, "level": "Orta", "message": "Uyku kaliteniz kritik seviyede düşük.", "score": 65.0}
        if hrv < 25:
            return {"has_anomaly": True, "level": "Hafif", "message": "HRV değeriniz düşük, vücudunuz yorgun.", "score": 45.0}

        return {"has_anomaly": False, "level": "Düşük", "message": "Her şey yolunda görünüyor.", "score": 10.0}

anomaly_service = AnomalyService()
