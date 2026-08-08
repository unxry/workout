from datetime import date

from app.models import User
from app.services.nutrition import build_targets, calculate_bmr


def test_calculates_mifflin_bmr_for_male():
    user = User(sex="male", age=30, height_cm=180, current_weight_kg=82)
    assert calculate_bmr(user) == 1800


def test_fat_loss_targets_include_deficit_and_eta():
    user = User(
        sex="female",
        age=34,
        height_cm=168,
        current_weight_kg=78,
        target_weight_kg=68,
        goal="fat_loss",
        activity_level="moderate",
    )
    targets = build_targets(user, today=date(2026, 8, 8))
    assert targets.calorie_target < targets.tdee
    assert targets.protein_target_g >= 150
    assert targets.expected_goal_date is not None
