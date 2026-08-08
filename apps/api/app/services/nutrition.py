from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from app.models import User


ACTIVITY_FACTORS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "athlete": 1.9,
}


@dataclass(frozen=True)
class NutritionTargets:
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


def calculate_bmr(user: User) -> int:
    if not all([user.sex, user.age, user.height_cm, user.current_weight_kg]):
        return 0

    base = 10 * user.current_weight_kg + 6.25 * user.height_cm - 5 * user.age
    if user.sex == "female":
        base -= 161
    else:
        base += 5
    return max(0, round(base))


def build_targets(user: User, today: date | None = None) -> NutritionTargets:
    today = today or date.today()
    bmr = calculate_bmr(user)
    factor = ACTIVITY_FACTORS.get(user.activity_level, ACTIVITY_FACTORS["moderate"])
    tdee = round(bmr * factor) if bmr else 0

    weight = user.current_weight_kg or 75
    goal = user.goal or "maintenance"
    calorie_delta = 0
    weekly_delta = 0.0
    rationale = "Maintenance strategy until onboarding is complete."

    if goal in {"fat_loss", "cut"}:
        calorie_delta = -round(min(650, max(300, tdee * 0.18)))
        weekly_delta = -round(min(weight * 0.008, 0.8), 2)
        rationale = "Moderate deficit designed to preserve muscle and reduce rebound risk."
    elif goal == "muscle_gain":
        calorie_delta = round(min(350, max(180, tdee * 0.1)))
        weekly_delta = round(min(weight * 0.004, 0.35), 2)
        rationale = "Controlled surplus focused on lean mass instead of aggressive weight gain."
    elif goal == "recomposition":
        calorie_delta = -round(min(250, max(100, tdee * 0.07)))
        weekly_delta = -round(min(weight * 0.003, 0.25), 2)
        rationale = "Small deficit with high protein for recomposition."

    calorie_target = max(1300, tdee + calorie_delta) if tdee else 0
    protein_per_kg = 2.1 if goal in {"fat_loss", "cut", "recomposition"} else 1.8
    protein = round(weight * protein_per_kg)
    fat = round(max(weight * 0.7, calorie_target * 0.22 / 9)) if calorie_target else 0
    remaining = max(0, calorie_target - protein * 4 - fat * 9)
    carbs = round(remaining / 4) if calorie_target else 0
    water = round(weight * 35)

    expected_goal_date = None
    if user.target_weight_kg and user.current_weight_kg and weekly_delta:
        kilos = abs(user.current_weight_kg - user.target_weight_kg)
        weeks = round(kilos / abs(weekly_delta))
        expected_goal_date = today + timedelta(weeks=max(1, weeks))

    return NutritionTargets(
        bmr=bmr,
        tdee=tdee,
        calorie_target=calorie_target,
        protein_target_g=protein,
        fat_target_g=fat,
        carbs_target_g=carbs,
        water_target_ml=water,
        weekly_weight_delta_kg=weekly_delta,
        expected_goal_date=expected_goal_date,
        rationale=rationale,
    )
