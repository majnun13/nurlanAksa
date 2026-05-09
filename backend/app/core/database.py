import asyncio
import asyncpg
from .config import settings

_pool: asyncpg.Pool | None = None
_pool_lock = asyncio.Lock()


async def get_pool() -> asyncpg.Pool:
    """Bağlantı havuzunu döndürür. İlk çağrıda oluşturur. asyncio.Lock ile thread-safe."""
    global _pool
    if _pool is not None:
        return _pool
    async with _pool_lock:
        # Double-checked locking: lock alındıktan sonra tekrar kontrol et
        if _pool is None:
            _pool = await asyncpg.create_pool(
                dsn=settings.DATABASE_URL,
                min_size=2,
                max_size=10,
                server_settings={'search_path': '"nurlanAksaV1"'}
            )
    return _pool


async def close_pool() -> None:
    """Uygulama kapanırken çağrılır."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
