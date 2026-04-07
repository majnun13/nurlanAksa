import asyncpg
from .config import settings

_pool: asyncpg.Pool | None = None


async def get_pool() -> asyncpg.Pool:
    """Bağlantı havuzunu döndürür. İlk çağrıda oluşturur."""
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(
            dsn=settings.DATABASE_URL,
            min_size=2,
            max_size=10,
        )
    return _pool


async def close_pool() -> None:
    """Uygulama kapanırken çağrılır."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
