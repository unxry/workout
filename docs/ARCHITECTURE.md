# Architecture

The product is split into a Telegram Mini App frontend and a FastAPI backend.

## Domains

- Identity: Telegram user resolution and Mini App init data validation
- Profile: onboarding answers, goals, constraints, preferences, and health disclaimers
- Nutrition: meal logs, macro targets, food text/photo/voice entry points
- Training: workout plans, performed sessions, progression hints
- Progress: daily snapshots, body measurements, and trend forecasts
- Memory: durable facts, preferences, behavior patterns, and coach strategy revisions
- Coach: proactive analysis, chat, alerts, reminders, and Telegram notifications

## AI Coach loop

1. User data is written as structured events: meals, snapshots, workouts, reminders, and profile updates.
2. The strategy engine calculates BMR, TDEE, macro targets, hydration, weight velocity, and goal ETA.
3. The proactive analyzer reviews the latest 14 to 21 days.
4. It creates coach events when it detects risk, drift, plateaus, missing protein, poor sleep, low activity, or too-fast weight change.
5. If OpenAI is configured, the event is rewritten into a more personal coaching message using long-term memory.
6. The Telegram notifier can deliver important events without waiting for the user to open the Mini App.

## Security notes

- Telegram bot token is loaded only from environment variables.
- Telegram WebApp `initData` validation is implemented with HMAC.
- Admin-only webhook registration is protected by `X-Admin-Key`.
- The current local MVP accepts `X-Telegram-Id` for development. Disable that bypass outside development.

