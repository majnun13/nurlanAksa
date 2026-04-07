from fastapi import HTTPException
from ..core.database import get_pool
from ..schemas.profile import HealthProfileRequest, HealthProfileResponse


async def save_health_profile(
    user_id: str,
    data: HealthProfileRequest,
) -> HealthProfileResponse:
    pool = await get_pool()

    # UPSERT – varsa güncelle, yoksa ekle
    row = await pool.fetchrow(
        """
        INSERT INTO health_profiles
            (user_id, age, weight_kg, height_cm, gender, lifestyle,
             health_goal, dietary_restrictions, medical_conditions, medications)
        VALUES ($1,$2,$3,$4,$5,$6,$7, COALESCE($8, '{}'::text[]), COALESCE($9, '{}'::text[]), $10)
        ON CONFLICT (user_id) DO UPDATE SET
            age                  = COALESCE(EXCLUDED.age, health_profiles.age),
            weight_kg            = COALESCE(EXCLUDED.weight_kg, health_profiles.weight_kg),
            height_cm            = COALESCE(EXCLUDED.height_cm, health_profiles.height_cm),
            gender               = COALESCE(EXCLUDED.gender, health_profiles.gender),
            lifestyle            = COALESCE(EXCLUDED.lifestyle, health_profiles.lifestyle),
            health_goal          = COALESCE(EXCLUDED.health_goal, health_profiles.health_goal),
            dietary_restrictions = COALESCE($8, health_profiles.dietary_restrictions),
            medical_conditions   = COALESCE($9, health_profiles.medical_conditions),
            medications          = COALESCE(EXCLUDED.medications, health_profiles.medications),
            updated_at           = NOW()
        RETURNING id, user_id, age, weight_kg, height_cm, gender,
                  lifestyle, health_goal, dietary_restrictions, medical_conditions, medications
        """,
        user_id,
        data.age,
        data.weight_kg,
        data.height_cm,
        data.gender,
        data.lifestyle,
        data.health_goal,
        data.dietary_restrictions,
        data.medical_conditions,
        data.medications,
    )
    return _to_response(dict(row))


async def get_health_profile(user_id: str) -> HealthProfileResponse:
    pool = await get_pool()
    row = await pool.fetchrow(
        """
        SELECT id, user_id, age, weight_kg, height_cm, gender,
               lifestyle, health_goal, dietary_restrictions, medical_conditions, medications
        FROM health_profiles WHERE user_id = $1 LIMIT 1
        """,
        user_id,
    )
    if not row:
        raise HTTPException(status_code=404, detail="Profil bulunamadı.")
    return _to_response(dict(row))


def _to_response(r: dict) -> HealthProfileResponse:
    return HealthProfileResponse(
        id=str(r["id"]),
        user_id=str(r["user_id"]),
        age=r["age"],
        weight_kg=float(r["weight_kg"]) if r["weight_kg"] else None,
        height_cm=float(r["height_cm"]) if r["height_cm"] else None,
        gender=r["gender"],
        lifestyle=r["lifestyle"],
        health_goal=r["health_goal"],
        dietary_restrictions=list(r["dietary_restrictions"] or []),
        medical_conditions=list(r["medical_conditions"] or []),
        medications=r.get("medications"),
    )
