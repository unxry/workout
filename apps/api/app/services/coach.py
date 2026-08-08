from __future__ import annotations

from datetime import date, timedelta
from statistics import mean

from sqlalchemy.orm import Session

from app.models import CoachEvent, CoachStrategy, DailySnapshot, User
from app.services.memory import get_relevant_memories, remember
from app.services.nutrition import build_targets
from app.services.openai_client import polish_coach_message


def refresh_strategy(db: Session, user: User) -> CoachStrategy:
    targets = build_targets(user)
    strategy = user.strategy or CoachStrategy(user_id=user.id)
    strategy.bmr = targets.bmr
    strategy.tdee = targets.tdee
    strategy.calorie_target = targets.calorie_target
    strategy.protein_target_g = targets.protein_target_g
    strategy.fat_target_g = targets.fat_target_g
    strategy.carbs_target_g = targets.carbs_target_g
    strategy.water_target_ml = targets.water_target_ml
    strategy.weekly_weight_delta_kg = targets.weekly_weight_delta_kg
    strategy.expected_goal_date = targets.expected_goal_date
    strategy.rationale = targets.rationale
    db.add(strategy)
    db.commit()
    db.refresh(strategy)
    return strategy


def analyze_user(db: Session, user: User, on_date: date | None = None) -> list[CoachEvent]:
    on_date = on_date or date.today()
    strategy = user.strategy or refresh_strategy(db, user)
    start = on_date - timedelta(days=21)
    snapshots = (
        db.query(DailySnapshot)
        .filter(DailySnapshot.user_id == user.id, DailySnapshot.snapshot_date >= start)
        .order_by(DailySnapshot.snapshot_date.asc())
        .all()
    )
    if not snapshots:
        return [
            _create_event(
                db,
                user,
                "missing_data",
                "info",
                "Coach needs a baseline",
                "I do not have enough recent data yet to adapt your plan.",
                "Log weight, meals, steps, sleep, and water for three days. After that I can start changing the strategy with confidence.",
                ["Add today's weight", "Log the next meal", "Add sleep and steps tonight"],
                {"date": str(on_date)},
            )
        ]

    today_snapshot = next((item for item in snapshots if item.snapshot_date == on_date), snapshots[-1])
    events: list[CoachEvent] = []

    if strategy.calorie_target and today_snapshot.calories > strategy.calorie_target + 450:
        excess = today_snapshot.calories - strategy.calorie_target
        events.append(
            _create_event(
                db,
                user,
                "calorie_overage",
                "warning",
                "Calories are above plan",
                f"Today is {excess} kcal above the target. This is recoverable without fasting.",
                "Tomorrow, reduce the plan by 200 to 250 kcal and add 2500 to 3500 steps. Keep protein unchanged.",
                ["Keep dinner lean", "Add a 25 minute walk", "Do not skip breakfast tomorrow"],
                {"excess_kcal": excess},
            )
        )

    if strategy.protein_target_g and today_snapshot.protein_g and today_snapshot.protein_g < strategy.protein_target_g * 0.78:
        missing = round(strategy.protein_target_g - today_snapshot.protein_g)
        events.append(
            _create_event(
                db,
                user,
                "low_protein",
                "warning",
                "Protein is behind target",
                f"You still need about {missing} g protein to protect muscle and satiety.",
                "Choose one dense protein meal: cottage cheese, chicken, fish, eggs, Greek yogurt, tofu, or a protein shake.",
                ["Add a protein-first meal", "Keep fats moderate", "Log the meal after eating"],
                {"missing_protein_g": missing},
            )
        )

    if today_snapshot.sleep_hours is not None and today_snapshot.sleep_hours < 6:
        events.append(
            _create_event(
                db,
                user,
                "low_sleep",
                "info",
                "Sleep may affect hunger tomorrow",
                "Sleep was under 6 hours, so cravings and water retention may be higher.",
                "Keep caffeine earlier, avoid aggressive calorie cuts, and make tomorrow's meals predictable.",
                ["Plan breakfast now", "Move training intensity down one notch", "Aim for a fixed bedtime"],
                {"sleep_hours": today_snapshot.sleep_hours},
            )
        )

    last_14 = snapshots[-14:]
    weights = [item.weight_kg for item in last_14 if item.weight_kg is not None]
    if len(weights) >= 10:
        first_half = weights[: len(weights) // 2]
        second_half = weights[len(weights) // 2 :]
        delta = mean(second_half) - mean(first_half)
        if user.goal in {"fat_loss", "cut"} and abs(delta) < 0.15:
            events.append(
                _create_event(
                    db,
                    user,
                    "weight_plateau",
                    "warning",
                    "Weight trend is flat",
                    "The 14-day average is barely moving, which usually means intake, steps, sleep, or sodium are masking progress.",
                    "Hold protein, reduce average intake by 120 kcal, and add 2000 daily steps for the next 7 days. Reassess after a full week.",
                    ["Tighten meal logging", "Set a step floor", "Track waist once this week"],
                    {"fourteen_day_delta_kg": round(delta, 2)},
                )
            )
        if user.goal in {"fat_loss", "cut"} and delta < -max(0.9, (user.current_weight_kg or 80) * 0.012):
            events.append(
                _create_event(
                    db,
                    user,
                    "loss_too_fast",
                    "warning",
                    "Weight is dropping too fast",
                    "The current pace may increase fatigue, hunger, and muscle loss risk.",
                    "Increase calories by 150 to 250 kcal from carbs around training and keep the new target for 10 days.",
                    ["Add carbs near workout", "Watch energy and mood", "Keep protein stable"],
                    {"fourteen_day_delta_kg": round(delta, 2)},
                )
            )

    if today_snapshot.steps and today_snapshot.steps < 5000:
        events.append(
            _create_event(
                db,
                user,
                "low_steps",
                "info",
                "Activity is below baseline",
                "Steps are low today, so calorie burn and appetite regulation may be weaker.",
                "Add a short walk after the next meal. It improves glucose control and keeps the deficit easier.",
                ["Walk 12 to 20 minutes", "Use stairs once", "Update steps before bed"],
                {"steps": today_snapshot.steps},
            )
        )

    if events:
        remember(db, user, "coach_pattern", f"{on_date}: generated {len(events)} proactive coaching events.", 0.45)

    return events


def answer_chat(db: Session, user: User, message: str) -> tuple[str, list[str]]:
    strategy = user.strategy or refresh_strategy(db, user)
    memories = get_relevant_memories(db, user)
    memory_lines = [memory.content for memory in memories]
    system = (
        "You are a careful AI fitness coach and nutritionist. "
        "You personalize advice using user memory, avoid medical claims, and give concise practical actions."
    )
    prompt = (
        f"User goal: {user.goal}. Target kcal: {strategy.calorie_target}. "
        f"Protein target: {strategy.protein_target_g} g. Memories: {memory_lines}. "
        f"Question: {message}"
    )
    polished = polish_coach_message(system, prompt)
    if polished:
        remember(db, user, "chat_preference", f"User asked: {message}", 0.35, "chat")
        return polished, memory_lines

    lowered = message.lower()
    if "protein" in lowered or "бел" in lowered:
        answer = f"Your current protein target is {strategy.protein_target_g} g per day. Build the next meal around a lean protein source and keep fats moderate."
    elif "burger" in lowered or "pizza" in lowered or "бургер" in lowered or "пицц" in lowered:
        answer = "You can fit it in. Keep the portion intentional, log it, then make the next meal leaner with vegetables and protein. No fasting is needed."
    elif "plateau" in lowered or "стоит" in lowered:
        answer = "A plateau is usually a 14-day trend, not one weigh-in. Check logging accuracy, steps, sleep, sodium, and waist measurement before cutting calories harder."
    else:
        answer = "I would keep the strategy simple today: hit protein, stay near calories, drink water, and finish the day with a walk. Send me the meal or situation and I will adjust the plan."
    remember(db, user, "chat_preference", f"User asked: {message}", 0.35, "chat")
    return answer, memory_lines


def _create_event(
    db: Session,
    user: User,
    event_type: str,
    severity: str,
    title: str,
    body: str,
    recommendation: str,
    action_plan: list[str],
    payload: dict,
) -> CoachEvent:
    event = CoachEvent(
        user_id=user.id,
        event_type=event_type,
        severity=severity,
        title=title,
        body=body,
        recommendation=recommendation,
        action_plan=action_plan,
        payload=payload,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event
