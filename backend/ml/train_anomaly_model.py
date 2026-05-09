import os
import joblib
import numpy as np
import pandas as pd
import logging
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score

# Ayarlar
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")
MODEL_PATH = os.path.join(MODEL_DIR, "anomaly_model.pkl")

def generate_synthetic_data(n_samples=20000):
    np.random.seed(42)
    
    # 1. Temel Sensör ve Profil Verileri
    age = np.random.randint(18, 80, n_samples)
    bmi = np.random.uniform(18.0, 40.0, n_samples)
    has_heart_disease = np.random.choice([0, 1], p=[0.8, 0.2], size=n_samples)
    chronic_conditions_count = np.random.randint(0, 4, n_samples)
    
    # Normal baz nabız yaş ve bmi'ye göre değişir, kalp hastalarında daha yüksektir
    base_hr = 60 + (age - 20) * 0.1 + (bmi - 22) * 0.5 + has_heart_disease * 10
    avg_hr_bpm = np.random.normal(base_hr, 10)
    
    # HRV yaşlandıkça ve hastalıkla düşer
    base_hrv = 60 - (age - 20) * 0.5 - has_heart_disease * 15
    hrv_ms = np.random.normal(base_hrv, 15)
    hrv_ms = np.clip(hrv_ms, 10, 120)
    
    step_count = np.random.randint(1000, 20000, n_samples)
    sleep_score = np.random.randint(30, 100, n_samples)
    
    # 2. Opsiyonel Sensör Verileri (Bazen Boş Gelecek)
    spo2_pct = np.random.normal(97, 2, n_samples)
    spo2_pct = np.clip(spo2_pct, 85, 100)
    # %40 ihtimalle SpO2 yok (NaN)
    missing_spo2 = np.random.rand(n_samples) < 0.4
    spo2_pct[missing_spo2] = np.nan
    
    temp_celsius = np.random.normal(36.5, 0.5, n_samples)
    # %70 ihtimalle Vücut Sıcaklığı yok (NaN)
    missing_temp = np.random.rand(n_samples) < 0.7
    temp_celsius[missing_temp] = np.nan

    # 3. Risk Skoru Mantığı (Kural Tabanlı Hedef - Label Üretimi)
    risk_scores = np.zeros(n_samples)
    
    for i in range(n_samples):
        score = 5.0 # Taban puan (Çok Normal)
        
        # Nabız anomalisi (Yaş, BMI ve Kalp Hastalığına göre hassas)
        hr_upper_limit = 100
        if has_heart_disease[i] == 1:
            hr_upper_limit = 85  # Kalp hastaları için çok daha düşük tolerans
            
        if avg_hr_bpm[i] > hr_upper_limit:
            score += (avg_hr_bpm[i] - hr_upper_limit) * 2.0
            if has_heart_disease[i] == 1:
                score += 25 # Ekstra kritik risk (Kalp hastası ve nabız yüksek)
                
        if avg_hr_bpm[i] < 45:
            score += 20
            
        # HRV (Düşük HRV, yüksek yorgunluk/stres demektir)
        if hrv_ms[i] < 30:
            score += (30 - hrv_ms[i]) * 1.5
            
        # Uyku Kalitesi
        if sleep_score[i] < 50:
            score += (50 - sleep_score[i]) * 0.8
            
        # SpO2 (Oksijen - Sadece veri varsa hesaba kat)
        if not np.isnan(spo2_pct[i]) and spo2_pct[i] < 94:
            score += (94 - spo2_pct[i]) * 6.0
            
        # Sıcaklık (Ateş - Sadece veri varsa hesaba kat)
        if not np.isnan(temp_celsius[i]) and temp_celsius[i] > 37.5:
            score += (temp_celsius[i] - 37.5) * 20.0
            
        # Profil Risk Çarpanları
        if bmi[i] > 30:
            score *= 1.15
            
        if age[i] > 60:
            score *= 1.10
            
        # Diğer hastalıkların yükü
        score += chronic_conditions_count[i] * 4.0
        
        # Sınırla
        risk_scores[i] = min(max(score, 0), 100)

    # DataFrame Oluştur
    X = pd.DataFrame({
        'avg_hr_bpm': avg_hr_bpm,
        'hrv_ms': hrv_ms,
        'step_count': step_count,
        'sleep_score': sleep_score,
        'spo2_pct': spo2_pct,
        'temp_celsius': temp_celsius,
        'age': age,
        'bmi': bmi,
        'has_heart_disease': has_heart_disease,
        'chronic_conditions_count': chronic_conditions_count
    })
    
    y = risk_scores
    return X, y

def train():
    logger.info("1. Sentetik veri kümesi üretiliyor (NaN değerleri dahil)...")
    X, y = generate_synthetic_data(20000)
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    logger.info("2. HistGradientBoostingRegressor modeli eğitiliyor (Boş/NaN veriyi anlar)...")
    model = HistGradientBoostingRegressor(
        max_iter=300, 
        learning_rate=0.05, 
        max_depth=7,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    r2 = r2_score(y_test, y_pred)
    
    logger.info(f"3. Model Test Sonuçları: RMSE={rmse:.2f} Puan, R2={r2:.3f} Başarı Oranı")
    
    if not os.path.exists(MODEL_DIR):
        os.makedirs(MODEL_DIR)
        
    joblib.dump(model, MODEL_PATH)
    logger.info(f"4. Model başarıyla kaydedildi: {MODEL_PATH}")

if __name__ == "__main__":
    train()
