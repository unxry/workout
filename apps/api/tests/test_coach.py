from datetime import date, timedelta

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.session import Base
from app.models import DailySnapshot, User
from app.services.coach import analyze_user, refresh_strategy


def test_proactive_analysis_detects_low_protein_and_steps():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    user = User(
        telegram_id="test",
        sex="male",
        age=29,
        height_cm=181,
        current_weight_kg=90,
        target_weight_kg=82,
        goal="fat_loss",
        activity_level="moderate",
        onboarding_completed=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    refresh_strategy(db, user)

    today = date.today()
    for offset in range(3):
        db.add(
            DailySnapshot(
                user_id=user.id,
                snapshot_date=today - timedelta(days=offset),
                weight_kg=90 - offset * 0.1,
                calories=2600,
                protein_g=70,
                steps=3200,
                sleep_hours=5.5,
            )
        )
    db.commit()

    events = analyze_user(db, user, today)
    event_types = {event.event_type for event in events}
    assert "low_protein" in event_types
    assert "low_steps" in event_types

