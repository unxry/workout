# Backend Architecture

The repository contains the server side for AI Fitness Coach. The native iOS app can use these APIs for onboarding, tracking, coach chat, progress, and proactive recommendations.

## Domains

- Identity: user resolution from Telegram or future client credentials
- Profile: onboarding answers, goals, constraints, preferences, and health disclaimers
- Nutrition: meal logs, macro targets, and food text entry points
- Training: workout plans, performed sessions, and progression hints
- Progress: daily snapshots, body measurements, and trend forecasts
- Memory: durable facts, preferences, behavior patterns, and coach strategy revisions
- Coach: proactive analysis, chat, alerts, reminders, and Telegram notifications

## AI Coach Loop

1. User data is written as structured events: meals, snapshots, workouts, reminders, and profile updates.
2. The strategy engine calculates BMR, TDEE, macro targets, hydration, weight velocity, and goal ETA.
3. The proactive analyzer reviews the latest 14 to 21 days.
4. It creates coach events when it detects risk, drift, plateaus, missing protein, poor sleep, low activity, or too-fast weight change.
5. If OpenAI is configured, the event is rewritten into a more personal coaching message using long-term memory.
6. Telegram can deliver important events without waiting for the user to open a client app.

## Security Notes

- Telegram bot token is loaded only from environment variables.
- Admin-only webhook registration is protected by `X-Admin-Key`.
- The current local MVP accepts `X-Telegram-Id` for development. Replace that with a native-client auth flow before exposing private user data in a production iOS app.
