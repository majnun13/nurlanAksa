"""
Ortak FastAPI Dependency'leri.

Kullanım:
    from app.api.dependencies import get_current_user_id

    @router.get("/endpoint")
    async def my_endpoint(user_id: str = Depends(get_current_user_id)):
        ...
"""
from fastapi import Header, HTTPException, Depends
from ..core.security import decode_access_token


async def get_current_user_id(authorization: str = Header(...)) -> str:
    """
    Authorization: Bearer <token> header'dan user_id çıkarır.
    Token geçersizse 401 fırlatır.

    Her route'ta _get_user_id() kopyasını yazmak yerine Depends() ile kullan.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token gerekli.")
    token = authorization.removeprefix("Bearer ").strip()
    user_id = decode_access_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Geçersiz token.")
    return user_id
