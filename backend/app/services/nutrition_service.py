# ─────────────────────────────────────────────────────────────
#  NutritionService – MacroVision AI model + Veritabanı
#  Model: EfficientNet-B4, eğitilmiş yemek tanıma modeli
# ─────────────────────────────────────────────────────────────

import os
import asyncio
import logging
import torch
import timm
from PIL import Image
from torchvision import transforms
from io import BytesIO
from fastapi import HTTPException
from ..core.database import get_pool

# ── Dosya yolları (backend/ml_models/ altında) ────────────────
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "combined_best.pth")

# ── Cihaz ─────────────────────────────────────────────────────
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# ── Görsel dönüşümü (eğitimde IMAGE_SIZE = 288) ──────────────
_transform = transforms.Compose([
    transforms.Resize(int(288 * 1.15)),
    transforms.CenterCrop(288),
    transforms.ToTensor(),
    transforms.Normalize(
        [0.485, 0.456, 0.406],
        [0.229, 0.224, 0.225]
    )
])

# ── Lazy model loading (singleton) ────────────────────────────
_model = None
_classes = None

_logger = logging.getLogger(__name__)

def _load_model():
    """Model'i ilk kullanımda yükler (lazy loading)."""
    global _model, _classes

    if _model is not None:
        return

    if not os.path.exists(MODEL_PATH):
        raise HTTPException(
            status_code=503,
            # GÜVENLİK: İç dosya yolu istemciye sızdırılmaz
            detail="Yemek tanıma modeli şu an hazır değil. Lütfen daha sonra tekrar deneyin."
        )

    checkpoint = torch.load(MODEL_PATH, map_location=DEVICE, weights_only=False)
    _classes = checkpoint["classes"]
    num_classes = checkpoint["num_classes"]

    _model = timm.create_model(
        "efficientnet_b4",
        pretrained=False,
        num_classes=num_classes
    )
    _model.load_state_dict(checkpoint["model_state_dict"])
    _model.to(DEVICE)
    _model.eval()
    _logger.info("MacroVision model yüklendi (%d sınıf, cihaz: %s)", num_classes, DEVICE)


# ── Public API ────────────────────────────────────────────────

def predict_food(image_bytes: bytes) -> dict:
    """Fotoğraftan yemek tahmini yap. Senkron — run_in_executor ile çağırılmalı."""
    _load_model()

    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    x = _transform(image).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        output = _model(x)
        probs = torch.softmax(output, dim=1)
        top_probs, top_idxs = torch.topk(probs, 5)

    top5 = []
    for i in range(5):
        idx = top_idxs[0][i].item()
        label = _classes[idx]
        prob = top_probs[0][i].item() * 100
        top5.append({"label": label, "confidence": round(prob, 2)})

    return {
        "predicted_food": top5[0]["label"],
        "confidence": top5[0]["confidence"],
        "top5": top5,
    }


async def get_nutrition_for_food(food_name: str, gram: float) -> dict | None:
    """Yemek adı ve gram miktarına göre besin değerini veritabanından hesapla."""
    pool = await get_pool()
    # ILIKE ile büyük/küçük harf duyarsız arama
    row = await pool.fetchrow(
        "SELECT protein_per_100g, carbs_per_100g, fat_per_100g, calories_per_100g FROM food_items WHERE name ILIKE $1 LIMIT 1",
        food_name.strip()
    )
    
    if not row:
        return None

    ratio = gram / 100.0

    protein = row.get("protein_per_100g") or 0
    carbs = row.get("carbs_per_100g") or 0
    fat = row.get("fat_per_100g") or 0
    calories = row.get("calories_per_100g") or 0

    return {
        "food_name": food_name,
        "gram": gram,
        "protein": round(float(protein) * ratio, 2),
        "carbs": round(float(carbs) * ratio, 2),
        "fat": round(float(fat) * ratio, 2),
        "calories": round(float(calories) * ratio, 2),
    }


async def search_foods(query: str) -> list[dict]:
    """Yemek adına göre veritabanında arama yap. Türkçe karakterlere karşı duyarlıdır."""
    pool = await get_pool()
    query_raw = query.strip()

    if not query_raw:
        rows = await pool.fetch(
            "SELECT name, protein_per_100g, carbs_per_100g, fat_per_100g, calories_per_100g FROM food_items ORDER BY name LIMIT 100"
        )
    else:
        # Türkçe → ASCII dönüşüm tablosu
        tr_map = {
            'ı': 'i', 'İ': 'i', 'I': 'i',
            'ğ': 'g', 'Ğ': 'g',
            'ü': 'u', 'Ü': 'u',
            'ş': 's', 'Ş': 's',
            'ö': 'o', 'Ö': 'o',
            'ç': 'c', 'Ç': 'c',
        }

        def normalize_tr(s: str) -> str:
            return ''.join(tr_map.get(c, c.lower()) for c in s)

        # 3 farklı arama biçimi:
        # 1) Orijinal (Türkçe harfler, boşluklu) – DB'de Türkçe + boşlukla saklıysa
        form_original  = f"%{query_raw.lower()}%"
        # 2) ASCII normalize, boşluklu – DB'de ASCII + boşlukla saklıysa
        form_ascii_sp  = f"%{normalize_tr(query_raw)}%"
        # 3) ASCII normalize, tire ile – DB'de ASCII + tireli saklıysa (ör: adana-kebap)
        form_ascii_hyp = f"%{normalize_tr(query_raw).replace(' ', '-')}%"

        rows = await pool.fetch(
            """
            SELECT DISTINCT name, protein_per_100g, carbs_per_100g, fat_per_100g, calories_per_100g
            FROM food_items
            WHERE name ILIKE $1
               OR name ILIKE $2
               OR name ILIKE $3
            ORDER BY name
            """,
            form_original,
            form_ascii_sp,
            form_ascii_hyp,
        )


    foods = []
    for row in rows:
        foods.append({
            "name": row["name"],
            "protein_per_100g": round(float(row["protein_per_100g"]), 2) if row["protein_per_100g"] else None,
            "carbs_per_100g": round(float(row["carbs_per_100g"]), 2) if row["carbs_per_100g"] else None,
            "fat_per_100g": round(float(row["fat_per_100g"]), 2) if row["fat_per_100g"] else None,
            "calories_per_100g": round(float(row["calories_per_100g"]), 2) if row["calories_per_100g"] else None,
        })

    return foods


async def get_all_food_names() -> list[str]:
    """Tüm yemek isimlerini veritabanından listele. B19: LIMIT 500 — OOM koruması."""
    pool = await get_pool()
    rows = await pool.fetch("SELECT name FROM food_items ORDER BY name LIMIT 500")
    return [r["name"] for r in rows]
