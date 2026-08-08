from __future__ import annotations

from openai import OpenAI

from app.core.config import get_settings


def polish_coach_message(system: str, user_prompt: str) -> str | None:
    settings = get_settings()
    if not settings.openai_api_key:
        return None

    client = OpenAI(api_key=settings.openai_api_key)
    response = client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.35,
        max_tokens=420,
    )
    return response.choices[0].message.content
