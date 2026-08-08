from __future__ import annotations

from typing import Any
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.models import User
from app.services.memory import remember

router = APIRouter(prefix="/api/telegram", tags=["telegram"])


def telegram_api_url(method: str) -> str:
    token = get_settings().telegram_bot_token
    return f"https://api.telegram.org/bot{token}/{method}"


async def send_message(chat_id: str, text: str, reply_markup: dict[str, Any] | None = None) -> None:
    settings = get_settings()
    if not settings.telegram_bot_token:
        return
    payload: dict[str, Any] = {"chat_id": chat_id, "text": text}
    if reply_markup:
        payload["reply_markup"] = reply_markup
    async with httpx.AsyncClient(timeout=12) as client:
        response = await client.post(telegram_api_url("sendMessage"), json=payload)
        response.raise_for_status()


def mini_app_keyboard() -> dict[str, Any] | None:
    webapp_url = get_settings().public_webapp_url
    parsed = urlparse(webapp_url)
    if parsed.scheme != "https":
        return None
    return {
        "inline_keyboard": [
            [{"text": "Open AI Coach", "web_app": {"url": webapp_url}}],
            [{"text": "Open in browser", "url": webapp_url}],
        ]
    }


def get_or_create_telegram_user(db: Session, telegram_id: str, first_name: str) -> User:
    user = db.query(User).filter(User.telegram_id == telegram_id).one_or_none()
    if user:
        return user

    user = User(telegram_id=telegram_id, first_name=first_name)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        user = db.query(User).filter(User.telegram_id == telegram_id).one_or_none()
        if user:
            return user
        raise
    db.refresh(user)
    return user


async def process_telegram_update(update: dict[str, Any], db: Session) -> None:
    settings = get_settings()
    message = update.get("message") or update.get("edited_message")
    if not message:
        return

    chat = message.get("chat", {})
    from_user = message.get("from", {})
    telegram_id = str(from_user.get("id") or chat.get("id"))
    first_name = from_user.get("first_name") or "there"
    text = (message.get("text") or "").strip()

    user = get_or_create_telegram_user(db, telegram_id, first_name)

    if text.startswith("/start"):
        remember(db, user, "activation", "User started the Telegram bot.", 0.7, "telegram")
        await send_message(
            chat_id=telegram_id,
            text=(
                "Я буду твоим AI-тренером. Открой приложение, заполни первый профиль, "
                "и я начну адаптировать питание, тренировки, восстановление и напоминания."
            ),
            reply_markup=mini_app_keyboard(),
        )
    else:
        remember(db, user, "telegram_note", text[:500], 0.4, "telegram")
        await send_message(
            chat_id=telegram_id,
            text="Я сохранил заметку. Открой Mini App, чтобы увидеть, как это меняет план на сегодня.",
            reply_markup=mini_app_keyboard(),
        )


@router.post("/webhook/{secret}")
async def telegram_webhook(secret: str, update: dict[str, Any], db: Session = Depends(get_db)) -> dict[str, bool]:
    settings = get_settings()
    if secret != settings.telegram_webhook_secret:
        raise HTTPException(status_code=403, detail="Invalid webhook secret")

    await process_telegram_update(update, db)
    return {"ok": True}


@router.post("/set-webhook")
async def set_webhook(x_admin_key: str = Header(default="")) -> dict[str, Any]:
    settings = get_settings()
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")
    if not settings.telegram_bot_token:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN is missing")

    webhook_url = f"{settings.api_public_url}/api/telegram/webhook/{settings.telegram_webhook_secret}"
    async with httpx.AsyncClient(timeout=12) as client:
        response = await client.post(telegram_api_url("setWebhook"), json={"url": webhook_url})
        response.raise_for_status()
        return response.json()


@router.post("/delete-webhook")
async def delete_webhook(x_admin_key: str = Header(default="")) -> dict[str, Any]:
    settings = get_settings()
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")
    if not settings.telegram_bot_token:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN is missing")

    async with httpx.AsyncClient(timeout=12) as client:
        response = await client.post(telegram_api_url("deleteWebhook"), json={"drop_pending_updates": False})
        response.raise_for_status()
        return response.json()


@router.get("/webhook-info")
async def webhook_info(x_admin_key: str = Header(default="")) -> dict[str, Any]:
    settings = get_settings()
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")
    if not settings.telegram_bot_token:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN is missing")

    async with httpx.AsyncClient(timeout=12) as client:
        response = await client.get(telegram_api_url("getWebhookInfo"))
        response.raise_for_status()
        return response.json()


@router.get("/debug")
async def telegram_debug() -> dict[str, Any]:
    settings = get_settings()
    return {
        "telegram_token_configured": bool(settings.telegram_bot_token),
        "api_public_url": settings.api_public_url,
        "public_webapp_url": settings.public_webapp_url,
        "public_webapp_url_is_https": urlparse(settings.public_webapp_url).scheme == "https",
        "webhook_url_would_be": f"{settings.api_public_url}/api/telegram/webhook/<hidden>",
    }
