from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps import get_current_user
from app.models import CoachEvent, User
from app.schemas import CoachChatIn, CoachChatOut, CoachEventOut
from app.services.coach import analyze_user, answer_chat

router = APIRouter(prefix="/api/coach", tags=["coach"])


@router.get("/feed", response_model=list[CoachEventOut])
def feed(db: Session = Depends(get_db), user: User = Depends(get_current_user), limit: int = 20) -> list[CoachEvent]:
    return (
        db.query(CoachEvent)
        .filter(CoachEvent.user_id == user.id)
        .order_by(CoachEvent.created_at.desc())
        .limit(min(limit, 50))
        .all()
    )


@router.post("/analyze", response_model=list[CoachEventOut])
def analyze(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[CoachEvent]:
    return analyze_user(db, user)


@router.post("/chat", response_model=CoachChatOut)
def chat(payload: CoachChatIn, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> CoachChatOut:
    answer, memories = answer_chat(db, user, payload.message)
    return CoachChatOut(answer=answer, used_memory=memories)
