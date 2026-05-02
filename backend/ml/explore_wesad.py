"""
WESAD Dataset Keşif Script'i
Çalıştır: python3 backend/ml/explore_wesad.py
"""
import pickle
import numpy as np

# Bir katılımcının verisini incele
WESAD_PATH = "/Users/guliyevs13/Downloads/WESAD"
SUBJECT = "S2"

with open(f"{WESAD_PATH}/{SUBJECT}/{SUBJECT}.pkl", "rb") as f:
    data = pickle.load(f, encoding="latin1")

print("=== Veri Yapısı ===")
print("Ana anahtarlar:", list(data.keys()))
print("\n=== Sinyaller ===")
print("Chest sinyalleri:", list(data["signal"]["chest"].keys()))
print("Wrist sinyalleri:", list(data["signal"]["wrist"].keys()))

print("\n=== Etiketler ===")
labels = data["label"]
print("Toplam örnek:", len(labels))
print("Etiket dağılımı:", {int(l): int(np.sum(labels == l)) for l in np.unique(labels)})
# 1=Baseline, 2=Stres, 3=Eğlence, 4=Meditasyon

print("\n=== Wrist Sinyal Boyutları ===")
for key, val in data["signal"]["wrist"].items():
    print(f"  {key}: shape={val.shape}, Hz=?")

print("\n=== Chest Sinyal Boyutları ===")
for key, val in data["signal"]["chest"].items():
    print(f"  {key}: shape={val.shape}")

print("\nÖrnek BVP değerleri (ilk 10):", data["signal"]["wrist"]["BVP"][:10].flatten())
print("Örnek EDA değerleri (ilk 10):", data["signal"]["wrist"]["EDA"][:10].flatten())
print("Örnek ACC değerleri (ilk 5):", data["signal"]["wrist"]["ACC"][:5])
print("Örnek TEMP değerleri (ilk 5):", data["signal"]["wrist"]["TEMP"][:5].flatten())
