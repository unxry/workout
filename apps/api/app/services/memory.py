from __future__ import annotations

from datetime import datetime

from sqlalchemy.orm import Session

from app.models import MemoryItem, User


def remember(db: Session, user: User, kind: str, content: str, importance: float = 0.5, source: str = "system") -> MemoryItem:
    item = MemoryItem(user_id=user.id, kind=kind, content=content, importance=importance, source=source)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def get_relevant_memories(db: Session, user: User, limit: int = 10) -> list[MemoryItem]:
    memories = (
        db.query(MemoryItem)
        .filter(MemoryItem.user_id == user.id)
        .order_by(MemoryItem.importance.desc(), MemoryItem.created_at.desc())
        .limit(limit)
        .all()
    )
    now = datetime.utcnow()
    for memory in memories:
        memory.last_used_at = now
    db.commit()
    return memories
