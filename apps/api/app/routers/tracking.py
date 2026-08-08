from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps import get_current_user
from app.models import DailySnapshot, MealLog, User
from app.schemas import MealIn, MealOut, SnapshotIn, SnapshotOut

router = APIRouter(prefix="/api/tracking", tags=["tracking"])


@router.post("/snapshots", response_model=SnapshotOut)
def upsert_snapshot(payload: SnapshotIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> DailySnapshot:
    snapshot = (
        db.query(DailySnapshot)
        .filter(DailySnapshot.user_id == user.id, DailySnapshot.snapshot_date == payload.snapshot_date)
        .one_or_none()
    )
    if not snapshot:
        snapshot = DailySnapshot(user_id=user.id, snapshot_date=payload.snapshot_date)
    for key, value in payload.model_dump().items():
        setattr(snapshot, key, value)
    db.add(snapshot)
    db.commit()
    db.refresh(snapshot)
    return snapshot


@router.get("/snapshots", response_model=list[SnapshotOut])
def list_snapshots(db: Session = Depends(get_db), user: User = Depends(get_current_user), days: int = 30) -> list[DailySnapshot]:
    start = date.today().toordinal() - days
    return (
        db.query(DailySnapshot)
        .filter(DailySnapshot.user_id == user.id, DailySnapshot.snapshot_date >= date.fromordinal(start))
        .order_by(DailySnapshot.snapshot_date.asc())
        .all()
    )


@router.post("/meals", response_model=MealOut)
def create_meal(payload: MealIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> MealLog:
    meal = MealLog(user_id=user.id, **payload.model_dump())
    db.add(meal)
    db.commit()
    db.refresh(meal)
    return meal


@router.get("/meals", response_model=list[MealOut])
def list_meals(db: Session = Depends(get_db), user: User = Depends(get_current_user), limit: int = 20) -> list[MealLog]:
    return (
        db.query(MealLog)
        .filter(MealLog.user_id == user.id)
        .order_by(MealLog.eaten_at.desc())
        .limit(min(limit, 100))
        .all()
    )
