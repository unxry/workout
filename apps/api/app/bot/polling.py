from __future__ import annotations

import asyncio
import fcntl
import logging
from pathlib import Path
from typing import Any

import httpx

from app.bot.telegram import process_telegram_update, telegram_api_url
from app.core.config import get_settings
from app.db.session import Base, SessionLocal, engine


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logger = logging.getLogger("telegram-polling")


async def _telegram_post(method: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=35) as client:
        response = await client.post(telegram_api_url(method), json=payload or {})
        response.raise_for_status()
        return response.json()


async def run_polling() -> None:
    settings = get_settings()
    if not settings.telegram_bot_token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN is missing. Put it into the root .env file.")

    lock_path = Path(__file__).resolve().parents[4] / ".telegram-polling.lock"
    lock_file = lock_path.open("w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise RuntimeError("Telegram polling is already running on this machine. Stop the other dev:bot process first.")

    Base.metadata.create_all(bind=engine)
    await _telegram_post("deleteWebhook", {"drop_pending_updates": False})
    me = await _telegram_post("getMe")
    logger.info("Polling started for @%s", me.get("result", {}).get("username", "unknown_bot"))

    offset: int | None = None
    while True:
        try:
            payload: dict[str, Any] = {"timeout": 25, "allowed_updates": ["message", "edited_message"]}
            if offset is not None:
                payload["offset"] = offset
            result = await _telegram_post("getUpdates", payload)
            for update in result.get("result", []):
                offset = update["update_id"] + 1
                db = SessionLocal()
                try:
                    await process_telegram_update(update, db)
                finally:
                    db.close()
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 409:
                logger.error("Another Telegram getUpdates consumer is running. Stop the other bot process, server, or hosting worker.")
                raise SystemExit(1) from exc
            logger.error("Telegram API error: %s", exc.response.text)
            await asyncio.sleep(5)
        except Exception:
            logger.exception("Polling iteration failed")
            await asyncio.sleep(5)


if __name__ == "__main__":
    asyncio.run(run_polling())
