from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.bot.telegram import router as telegram_router
from app.core.config import get_settings
from app.db.session import Base, engine
from app.routers.coach import router as coach_router
from app.routers.health import router as health_router
from app.routers.tracking import router as tracking_router
from app.routers.users import router as users_router
from app.workers.proactive import start_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    scheduler = start_scheduler()
    yield
    scheduler.shutdown(wait=False)


settings = get_settings()
app = FastAPI(title="AI Fitness Coach API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.web_cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(users_router)
app.include_router(tracking_router)
app.include_router(coach_router)
app.include_router(telegram_router)

static_dir = Path(__file__).resolve().parents[1] / "static"
if (static_dir / "index.html").exists():
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="web")
