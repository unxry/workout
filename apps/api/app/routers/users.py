from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import StrategyOut, UserOut, UserProfileIn
from app.services.coach import refresh_strategy
from app.services.memory import remember

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("/me", response_model=UserOut)
def read_me(user: User = Depends(get_current_user)) -> User:
    return user


@router.put("/me", response_model=UserOut)
def update_me(payload: UserProfileIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> User:
    for key, value in payload.model_dump().items():
        setattr(user, key, value)
    user.onboarding_completed = True
    db.add(user)
    db.commit()
    db.refresh(user)
    refresh_strategy(db, user)
    remember(db, user, "profile", f"Goal: {user.goal}, activity: {user.activity_level}, preferences: {user.preferences}", 0.8)
    return user


@router.get("/me/strategy", response_model=StrategyOut)
def read_strategy(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return user.strategy or refresh_strategy(db, user)
