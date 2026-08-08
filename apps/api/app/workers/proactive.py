from __future__ import annotations

from datetime import date

from apscheduler.schedulers.background import BackgroundScheduler

from app.bot.telegram import send_message
from app.db.session import SessionLocal
from app.models import CoachEvent, User
from app.services.coach import analyze_user


def run_daily_analysis() -> None:
    db = SessionLocal()
    try:
        users = db.query(User).filter(User.onboarding_completed.is_(True)).all()
        for user in users:
            events = analyze_user(db, user, date.today())
            for event in events:
                if event.severity == "warning" and user.telegram_id:
                    event.delivered_to_telegram = True
                    db.add(event)
                    db.commit()
                    import anyio

                    anyio.run(send_message, user.telegram_id, f"{event.title}\n\n{event.body}\n\n{event.recommendation}")
    finally:
        db.close()


def start_scheduler() -> BackgroundScheduler:
    scheduler = BackgroundScheduler(timezone="UTC")
    scheduler.add_job(run_daily_analysis, "cron", hour=18, minute=0, id="daily_coach_analysis", replace_existing=True)
    scheduler.start()
    return scheduler
