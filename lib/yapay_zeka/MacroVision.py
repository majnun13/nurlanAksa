import os
import torch
import timm
import pandas as pd
from PIL import Image
from torchvision import transforms

# ====================================================
# DOSYA YOLLARI (Proje içi – taşınabilir)
# =====================================================
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(_SCRIPT_DIR, "combined_best.pth")
IMAGE_PATH = os.path.join(_SCRIPT_DIR, "test_resim.jpg")
CSV_PATH   = os.path.join(_SCRIPT_DIR, "yemek_besin_tablosu(Besin Tablosu).csv")

# =====================================================
# CİHAZ
# =====================================================
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# =====================================================
# CSV OKUMA ve TEMİZLEME
# =====================================================
def load_nutrition_table(csv_path):
    # CSV ; ile ayrılmış, bazı sayılarda virgül ondalık olarak kullanılmış
    df = pd.read_csv(csv_path, sep=";", encoding="utf-8-sig")

    # Bazı dosyalarda sonda boş bir sütun oluşabiliyor, onu temizle
    df = df.loc[:, ~df.columns.str.contains(r"^Unnamed")]
    df.columns = [col.strip().lower() for col in df.columns]

    # Beklenen sütunlar
    required_cols = ["sinif", "protein", "karbonhidrat", "yag", "kalori"]
    missing = [col for col in required_cols if col not in df.columns]
    if missing:
        raise ValueError(f"CSV içinde eksik sütun(lar) var: {missing}")

    # Sayıları float'a çevir
    # virgül varsa noktaya çeviriyoruz
    for col in ["protein", "karbonhidrat", "yag", "kalori"]:
        df[col] = (
            df[col]
            .astype(str)
            .str.strip()
            .str.replace(",", ".", regex=False)
        )
        df[col] = pd.to_numeric(df[col], errors="coerce")

    # sınıf isimlerini temizle
    df["sinif"] = df["sinif"].astype(str).str.strip().str.lower()

    return df

# =====================================================
# CHECKPOINT YÜKLE
# =====================================================
checkpoint = torch.load(MODEL_PATH, map_location=DEVICE, weights_only=False)

classes = checkpoint["classes"]
num_classes = checkpoint["num_classes"]

# =====================================================
# MODEL OLUŞTUR
# =====================================================
model = timm.create_model(
    "efficientnet_b4",
    pretrained=False,
    num_classes=num_classes
)

model.load_state_dict(checkpoint["model_state_dict"])
model.to(DEVICE)
model.eval()

# =====================================================
# GÖRSEL DÖNÜŞÜMÜ
# Eğitimde IMAGE_SIZE = 288 kullanıldı
# =====================================================
transform = transforms.Compose([
    transforms.Resize(int(288 * 1.15)),
    transforms.CenterCrop(288),
    transforms.ToTensor(),
    transforms.Normalize(
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225]
    )
])

# =====================================================
# RESMİ YÜKLE
# =====================================================
image = Image.open(IMAGE_PATH).convert("RGB")
x = transform(image).unsqueeze(0).to(DEVICE)

# =====================================================
# TAHMİN
# =====================================================
with torch.no_grad():
    output = model(x)
    probs = torch.softmax(output, dim=1)
    top_probs, top_idxs = torch.topk(probs, 5)

print("\n🔥 TOP 5 TAHMİN:\n")
for i in range(5):
    idx = top_idxs[0][i].item()
    label = classes[idx]
    prob = top_probs[0][i].item() * 100
    print(f"{i+1}. {label} → %{prob:.2f}")

# En yüksek olasılıklı sınıfı al
pred_idx = top_idxs[0][0].item()
pred_label = classes[pred_idx]
pred_conf = top_probs[0][0].item() * 100

print(f"\n✅ Tahmin edilen yemek: {pred_label} (%{pred_conf:.2f})")

# =====================================================
# KULLANICIDAN GRAM AL
# =====================================================
while True:
    gram_input = input("\nBu yemek kaç gram? (örnek: 180) : ").strip()
    try:
        gram = float(gram_input.replace(",", "."))
        if gram <= 0:
            print("Lütfen 0'dan büyük bir değer gir.")
            continue
        break
    except ValueError:
        print("Geçerli bir sayı gir. Örnek: 150 veya 150.5")

# =====================================================
# BESİN TABLOSUNDAN BUL ve HESAPLA
# =====================================================
df = load_nutrition_table(CSV_PATH)

row = df[df["sinif"] == pred_label.lower()]

if row.empty:
    print(f"\n⚠️ Uyarı: '{pred_label}' için CSV tablosunda kayıt bulunamadı.")
    print("Tahmin edilen sınıf adı ile CSV'deki 'sinif' sütunundaki isim birebir aynı olmalı.")
else:
    row = row.iloc[0]

    # 100 gramlık değerler
    protein_100 = row["protein"]
    carb_100    = row["karbonhidrat"]
    fat_100     = row["yag"]
    cal_100     = row["kalori"]

    # Kullanıcının gramına göre ölçekle
    katsayi = gram / 100.0

    protein_val = protein_100 * katsayi
    carb_val    = carb_100 * katsayi
    fat_val     = fat_100 * katsayi
    cal_val     = cal_100 * katsayi

    print("\n" + "=" * 50)
    print("🍽️ BESİN DEĞERLERİ")
    print("=" * 50)
    print(f"Yemek           : {pred_label}")
    print(f"Miktar          : {gram:.2f} g")
    print(f"Protein         : {protein_val:.2f} g")
    print(f"Karbonhidrat    : {carb_val:.2f} g")
    print(f"Yağ             : {fat_val:.2f} g")
    print(f"Kalori          : {cal_val:.2f} kcal")
    print("=" * 50)