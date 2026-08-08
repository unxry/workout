from __future__ import annotations

from datetime import date, datetime, time
from typing import Any, List, Optional
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.db.session import Base


def uuid() -> str:
    return str(uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    telegram_id: Mapped[Optional[str]] = mapped_column(String(64), unique=True, index=True)
    first_name: Mapped[Optional[str]] = mapped_column(String(120))
    timezone: Mapped[str] = mapped_column(String(80), default="Europe/Moscow")
    sex: Mapped[Optional[str]] = mapped_column(String(24))
    age: Mapped[Optional[int]] = mapped_column(Integer)
    height_cm: Mapped[Optional[float]] = mapped_column(Float)
    current_weight_kg: Mapped[Optional[float]] = mapped_column(Float)
    target_weight_kg: Mapped[Optional[float]] = mapped_column(Float)
    goal: Mapped[Optional[str]] = mapped_column(String(48))
    activity_level: Mapped[str] = mapped_column(String(48), default="moderate")
    constraints: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    preferences: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    snapshots: Mapped[List["DailySnapshot"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    meals: Mapped[List["MealLog"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    memories: Mapped[List["MemoryItem"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    coach_events: Mapped[List["CoachEvent"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    strategy: Mapped[Optional["CoachStrategy"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class DailySnapshot(Base):
    __tablename__ = "daily_snapshots"
    __table_args__ = (UniqueConstraint("user_id", "snapshot_date", name="uq_snapshot_user_date"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    snapshot_date: Mapped[date] = mapped_column(Date, index=True)
    weight_kg: Mapped[Optional[float]] = mapped_column(Float)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    protein_g: Mapped[float] = mapped_column(Float, default=0)
    fat_g: Mapped[float] = mapped_column(Float, default=0)
    carbs_g: Mapped[float] = mapped_column(Float, default=0)
    water_ml: Mapped[int] = mapped_column(Integer, default=0)
    steps: Mapped[int] = mapped_column(Integer, default=0)
    sleep_hours: Mapped[Optional[float]] = mapped_column(Float)
    mood: Mapped[Optional[int]] = mapped_column(Integer)
    stress_level: Mapped[Optional[int]] = mapped_column(Integer)
    workouts_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates="snapshots")


class MealLog(Base):
    __tablename__ = "meal_logs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    eaten_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    title: Mapped[str] = mapped_column(String(180))
    source: Mapped[str] = mapped_column(String(24), default="text")
    raw_input: Mapped[Optional[str]] = mapped_column(Text)
    items: Mapped[List[dict[str, Any]]] = mapped_column(JSON, default=list)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    protein_g: Mapped[float] = mapped_column(Float, default=0)
    fat_g: Mapped[float] = mapped_column(Float, default=0)
    carbs_g: Mapped[float] = mapped_column(Float, default=0)
    confidence: Mapped[float] = mapped_column(Float, default=0.65)

    user: Mapped[User] = relationship(back_populates="meals")


class MemoryItem(Base):
    __tablename__ = "memory_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(48), index=True)
    content: Mapped[str] = mapped_column(Text)
    importance: Mapped[float] = mapped_column(Float, default=0.5)
    source: Mapped[str] = mapped_column(String(48), default="system")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    last_used_at: Mapped[Optional[datetime]] = mapped_column(DateTime)

    user: Mapped[User] = relationship(back_populates="memories")


class CoachStrategy(Base):
    __tablename__ = "coach_strategies"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True, index=True)
    bmr: Mapped[int] = mapped_column(Integer, default=0)
    tdee: Mapped[int] = mapped_column(Integer, default=0)
    calorie_target: Mapped[int] = mapped_column(Integer, default=0)
    protein_target_g: Mapped[int] = mapped_column(Integer, default=0)
    fat_target_g: Mapped[int] = mapped_column(Integer, default=0)
    carbs_target_g: Mapped[int] = mapped_column(Integer, default=0)
    water_target_ml: Mapped[int] = mapped_column(Integer, default=0)
    weekly_weight_delta_kg: Mapped[float] = mapped_column(Float, default=0)
    expected_goal_date: Mapped[Optional[date]] = mapped_column(Date)
    rationale: Mapped[str] = mapped_column(Text, default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates="strategy")


class CoachEvent(Base):
    __tablename__ = "coach_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    severity: Mapped[str] = mapped_column(String(24), default="info")
    title: Mapped[str] = mapped_column(String(180))
    body: Mapped[str] = mapped_column(Text)
    recommendation: Mapped[str] = mapped_column(Text, default="")
    action_plan: Mapped[List[str]] = mapped_column(JSON, default=list)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    delivered_to_telegram: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    user: Mapped[User] = relationship(back_populates="coach_events")


class Reminder(Base):
    __tablename__ = "reminders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(48))
    local_time: Mapped[time] = mapped_column(Time)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    last_sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime)
