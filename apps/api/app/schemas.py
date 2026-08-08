from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class UserProfileIn(BaseModel):
    telegram_id: str | None = None
    first_name: str | None = None
    timezone: str = "Europe/Moscow"
    sex: str | None = None
    age: int | None = Field(default=None, ge=12, le=100)
    height_cm: float | None = Field(default=None, ge=120, le=230)
    current_weight_kg: float | None = Field(default=None, ge=35, le=300)
    target_weight_kg: float | None = Field(default=None, ge=35, le=300)
    goal: Literal["fat_loss", "muscle_gain", "recomposition", "cut", "maintenance"] | None = None
    activity_level: Literal["sedentary", "light", "moderate", "active", "athlete"] = "moderate"
    constraints: dict[str, Any] = Field(default_factory=dict)
    preferences: dict[str, Any] = Field(default_factory=dict)


class UserOut(UserProfileIn):
    id: str
    onboarding_completed: bool

    model_config = {"from_attributes": True}


class StrategyOut(BaseModel):
    bmr: int
    tdee: int
    calorie_target: int
    protein_target_g: int
    fat_target_g: int
    carbs_target_g: int
    water_target_ml: int
    weekly_weight_delta_kg: float
    expected_goal_date: date | None
    rationale: str

    model_config = {"from_attributes": True}


class SnapshotIn(BaseModel):
    snapshot_date: date
    weight_kg: float | None = Field(default=None, ge=35, le=300)
    calories: int = Field(default=0, ge=0, le=12000)
    protein_g: float = Field(default=0, ge=0, le=600)
    fat_g: float = Field(default=0, ge=0, le=500)
    carbs_g: float = Field(default=0, ge=0, le=1500)
    water_ml: int = Field(default=0, ge=0, le=12000)
    steps: int = Field(default=0, ge=0, le=100000)
    sleep_hours: float | None = Field(default=None, ge=0, le=16)
    mood: int | None = Field(default=None, ge=1, le=5)
    stress_level: int | None = Field(default=None, ge=1, le=5)
    workouts_count: int = Field(default=0, ge=0, le=5)


class SnapshotOut(SnapshotIn):
    id: str

    model_config = {"from_attributes": True}


class MealIn(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    raw_input: str | None = None
    source: Literal["text", "voice", "photo", "manual"] = "text"
    items: list[dict[str, Any]] = Field(default_factory=list)
    calories: int = Field(default=0, ge=0, le=6000)
    protein_g: float = Field(default=0, ge=0, le=300)
    fat_g: float = Field(default=0, ge=0, le=300)
    carbs_g: float = Field(default=0, ge=0, le=800)
    confidence: float = Field(default=0.65, ge=0, le=1)


class MealOut(MealIn):
    id: str
    eaten_at: datetime

    model_config = {"from_attributes": True}


class CoachEventOut(BaseModel):
    id: str
    event_type: str
    severity: str
    title: str
    body: str
    recommendation: str
    action_plan: list[str]
    payload: dict[str, Any]
    created_at: datetime

    model_config = {"from_attributes": True}


class CoachChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


class CoachChatOut(BaseModel):
    answer: str
    used_memory: list[str]
