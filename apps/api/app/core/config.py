from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[4]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(PROJECT_ROOT / ".env", PROJECT_ROOT / "apps/api/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    api_public_url: str = "http://localhost:8000"
    public_webapp_url: str = "http://localhost:5173"
    web_cors_origins: str = "http://localhost:5173"

    database_url: str = "sqlite:///./fitness_coach.sqlite3"
    redis_url: str = "redis://localhost:6379/0"

    telegram_bot_token: str = ""
    telegram_webhook_secret: str = "change-me"
    admin_api_key: str = "change-me"

    openai_api_key: str = ""
    openai_model: str = "gpt-4.1-mini"

    @field_validator("web_cors_origins", mode="before")
    @classmethod
    def normalize_origins(cls, value: str | list[str]) -> str:
        if isinstance(value, list):
            return ",".join(value)
        return value

    @property
    def web_cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.web_cors_origins.split(",") if origin.strip()]

    @property
    def is_development(self) -> bool:
        return self.app_env.lower() in {"dev", "development", "local"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
