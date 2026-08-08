from __future__ import annotations

import json
from urllib.parse import parse_qsl

from fastapi import Depends, Header, HTTPException, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.models import User
from app.security.telegram_init_data import validate_init_data


def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
    x_telegram_id: str | None = Header(default=None),
    x_telegram_init_data: str | None = Header(default=None),
) -> User:
    settings = get_settings()
    telegram_id = x_telegram_id

    if x_telegram_init_data:
        if not validate_init_data(x_telegram_init_data, settings.telegram_bot_token):
            raise HTTPException(status_code=401, detail="Invalid Telegram init data")
        init_payload = dict(parse_qsl(x_telegram_init_data, keep_blank_values=True))
        if init_payload.get("user"):
            user_payload = json.loads(init_payload["user"])
            telegram_id = str(user_payload["id"])

    if not telegram_id and settings.is_development:
        telegram_id = request.headers.get("X-Dev-Telegram-Id", "dev-user")

    if not telegram_id:
        raise HTTPException(status_code=401, detail="Telegram identity is required")

    user = db.query(User).filter(User.telegram_id == telegram_id).one_or_none()
    if user:
        return user

    user = User(telegram_id=telegram_id, first_name="Telegram user")
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
