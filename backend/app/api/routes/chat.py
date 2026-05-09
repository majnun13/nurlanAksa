"""
Aksa AI Asistan — Gemini destekli kisisellestirilmis saglik chatbotu.
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List
import logging

# Yeni Google Gen AI SDK (google-genai paketi)
from google import genai
from google.genai import types as genai_types

from app.core.config import settings
from app.core.database import get_pool
from app.api.dependencies import get_current_user_id

router = APIRouter(prefix="/chat", tags=["AI Asistan"])
_logger = logging.getLogger(__name__)

# ── Gemini Client — Singleton (her request'te yeniden oluşturma) ────────────
_gemini_client: genai.Client | None = None

def _get_gemini_client() -> genai.Client:
    global _gemini_client
    if _gemini_client is None:
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _gemini_client


# ── Şemalar ───────────────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str      # "user" | "model"
    content: str = Field(..., max_length=4096)

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2048,
                         description="Kullanıcı mesajı. Max 2048 karakter.")
    history: List[ChatMessage] = Field(default=[], max_length=20,
                                       description="Sohbet geçmişi. Max 20 mesaj.")


class ChatResponse(BaseModel):
    reply: str


# ── Sistem Prompt Oluşturucu ──────────────────────────────────────────────────

def _build_system_prompt(profile: dict, wearable: dict, nutrition: dict) -> str:
    name       = profile.get("full_name") or "Kullanıcı"
    age        = profile.get("age") or "?"
    gender     = profile.get("gender") or "?"
    weight     = profile.get("weight_kg") or "?"
    height     = profile.get("height_cm") or "?"
    goal       = profile.get("health_goal") or "maintain"
    lifestyle  = profile.get("lifestyle") or "Orta"
    conditions = profile.get("medical_conditions") or []
    diet       = profile.get("dietary_restrictions") or []

    bmi_str = "?"
    try:
        bmi = float(weight) / ((float(height) / 100) ** 2)
        bmi_str = f"{bmi:.1f}"
    except Exception:
        pass

    hr       = wearable.get("avg_hr_bpm") or "?"
    rhr      = wearable.get("resting_hr_bpm") or "?"
    hrv      = wearable.get("hrv_ms") or "?"
    steps    = wearable.get("step_count") or "?"
    sleep_h  = wearable.get("sleep_hours") or "?"
    sleep_sc = wearable.get("sleep_score") or "?"
    spo2     = wearable.get("spo2_pct")
    spo2_str = f"%{spo2:.0f}" if spo2 else "Ölçülmedi"
    calories = wearable.get("calories_burned") or "?"
    active_m = wearable.get("active_minutes") or "?"

    cal_in    = nutrition.get("total_calories") or "?"
    protein   = nutrition.get("total_protein_g") or "?"
    carbs     = nutrition.get("total_carbs_g") or "?"
    fat       = nutrition.get("total_fat_g") or "?"
    cal_goal  = nutrition.get("calorie_goal") or "?"
    prot_goal = nutrition.get("protein_goal_g") or "?"

    goal_tr = {
        "lose_weight": "kilo vermek",
        "gain_weight": "kilo almak / kas yapmak",
        "maintain":    "kilosunu korumak",
    }.get(goal, goal)

    conditions_str = ", ".join(conditions) if conditions else "Yok"
    diet_str = ", ".join(diet) if diet else "Yok"

    return f"""Sen Aksa uygulamasının kişisel sağlık asistanısın. Adın "Aksa AI".
Sana konuşan kişi hakkında aşağıdaki gerçek zamanlı verilere sahipsin.
Bu verileri kullanarak kişiselleştirilmiş, samimi ve anlaşılır yanıtlar ver.

## Kullanıcı Profili
- Ad: {name}
- Yaş: {age}
- Cinsiyet: {gender}
- Kilo: {weight} kg | Boy: {height} cm | VKİ: {bmi_str}
- Sağlık hedefi: {goal_tr}
- Yaşam tarzı: {lifestyle}
- Kronik hastalıklar: {conditions_str}
- Diyet kısıtlamaları: {diet_str}

## Bugünkü Wearable Verileri
- Ortalama nabız: {hr} bpm
- Dinlenme nabzı: {rhr} bpm
- HRV (kalp değişkenliği): {hrv} ms
- Adım sayısı: {steps}
- Uyku süresi: {sleep_h} sa | Uyku kalitesi: {sleep_sc}/100
- Kan oksijeni (SpO2): {spo2_str}
- Yakılan kalori: {calories} kcal
- Aktif dakika: {active_m} dk

## Bugünkü Beslenme
- Alınan kalori: {cal_in} kcal (Hedef: {cal_goal} kcal)
- Protein: {protein} g (Hedef: {prot_goal} g)
- Karbonhidrat: {carbs} g
- Yağ: {fat} g

## Davranış Kuralları
- Türkçe konuş, samimi ve sıcak ol
- Yanıtları kısa tut (3-5 cümle), çok uzun yazma
- Tıbbi tavsiye vermek yerine "doktorunuza danışın" de, ama kullanıcı verilerine bakarak genel bilgi ve öneri verebilirsin
- Yemek tarifi sorarsa kullanıcının diyet kısıtlamalarına ve beslenme hedeflerine uygun öner
- Kullanıcı verilerindeki gerçek değerlere atıfta bulun
- Emoji kullanabilirsin ama abartma
"""


# ── Ana Endpoint ──────────────────────────────────────────────────────────────

@router.post("", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user_id: str = Depends(get_current_user_id),
):
    # ── 1. Gemini Konfigürasyon Kontrolü ──────────────────────────
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI asistan şu an yapılandırılmamış. Lütfen yöneticinize bildirin."
        )

    # ── 2. Kullanıcı verilerini çek ──────────────────────────────
    pool = await get_pool()
    async with pool.acquire() as conn:
        profile_row = await conn.fetchrow(
            """SELECT u.full_name, u.email,
                      p.age, p.gender, p.weight_kg, p.height_cm,
                      p.health_goal, p.lifestyle,
                      p.medical_conditions, p.dietary_restrictions
               FROM users u
               LEFT JOIN health_profiles p ON p.user_id = u.id
               WHERE u.id = $1""",
            user_id,
        )

        wearable_row = await conn.fetchrow(
            """SELECT step_count, avg_hr_bpm, resting_hr_bpm,
                      sleep_hours, sleep_score, hrv_ms, spo2_pct,
                      active_minutes, calories_burned
               FROM daily_wearable_logs
               WHERE user_id = $1
               ORDER BY log_date DESC LIMIT 1""",
            user_id,
        )

        nutrition_row = await conn.fetchrow(
            """SELECT
                 COALESCE(SUM(ml.calories), 0)::int  AS total_calories,
                 COALESCE(SUM(ml.protein), 0)::int   AS total_protein_g,
                 COALESCE(SUM(ml.carbs), 0)::int     AS total_carbs_g,
                 COALESCE(SUM(ml.fat), 0)::int       AS total_fat_g
               FROM meal_logs ml
               WHERE ml.user_id = $1 AND ml.created_at::date = CURRENT_DATE""",
            user_id,
        )

        # nutrition_targets tablosu dinamik hesaplandığı için db'den çekilmiyor.
        # Bunu aşağıda hesaplayacağız.

    profile   = dict(profile_row)  if profile_row   else {}
    wearable  = dict(wearable_row) if wearable_row  else {}
    nutrition = dict(nutrition_row) if nutrition_row else {}
    
    # ── Dinamik Beslenme Hedefleri ──────────────────────────
    from app.services.nutrition_target_service import get_user_nutrition_targets
    targets = await get_user_nutrition_targets(user_id)
    nutrition["calorie_goal"]   = targets["calorie_target"]
    nutrition["protein_goal_g"] = targets["protein_target"]

    # ── 3. Gemini istemcisi (Singleton) ───────────────────────────────────
    client = _get_gemini_client()

    # Sohbet geçmişini yeni SDK formatına çevir
    contents = []
    for msg in body.history:
        contents.append(
            genai_types.Content(
                role=msg.role,
                parts=[genai_types.Part(text=msg.content)],
            )
        )
    contents.append(
        genai_types.Content(
            role="user",
            parts=[genai_types.Part(text=body.message)],
        )
    )

    system_prompt = _build_system_prompt(profile, wearable, nutrition)

    # ── 4. Gemini'ye gönder, yanıt al ───────────────────────────
    try:
        response = await client.aio.models.generate_content(
            model="gemini-2.5-flash-lite",
            contents=contents,
            config=genai_types.GenerateContentConfig(
                system_instruction=system_prompt,
                temperature=0.7,
                max_output_tokens=512,
            ),
        )
        reply = response.text.strip()
    except Exception as e:
        _logger.error("[Chat] Gemini API hatası: %s", e, exc_info=True)
        raise HTTPException(status_code=502, detail="AI asistan şu an yanıt veremiyor. Lütfen tekrar deneyin.")

    return ChatResponse(reply=reply)
