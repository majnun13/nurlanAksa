from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.core.database import get_pool, close_pool
from app.core.config import settings
from app.api.routes import auth as auth_router
from app.api.routes import profile as profile_router
from app.api.routes import dashboard as dashboard_router
from app.api.routes import exercise as exercise_router
from app.api.routes import nutrition as nutrition_router
from app.api.routes import wearable as wearable_router
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Uygulama başlangıcında bağlantı havuzu oluştur
    await get_pool()
    yield
    # Uygulama kapanırken havuzu kapat
    await close_pool()

app = FastAPI(
    title=settings.APP_NAME,
    description="Akıllı Kişisel Sağlık Asistanı – REST API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────
# Geliştirme aşamasında tüm originlere izin ver
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"OMGGGG VALIDATION ERROR: {exc.errors()}")
    print(f"BODY WAS: {await request.body()}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )


# ── Router'ları ekle ──────────────────────────────────────────
app.include_router(auth_router.router, prefix="/api/v1")
app.include_router(profile_router.router, prefix="/api/v1")
app.include_router(dashboard_router.router, prefix="/api/v1")
app.include_router(exercise_router.router, prefix="/api/v1")
app.include_router(nutrition_router.router, prefix="/api/v1")
app.include_router(wearable_router.router, prefix="/api/v1")


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "app": settings.APP_NAME, "version": "1.0.0"}
