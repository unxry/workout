# AI Fitness Coach Backend

FastAPI backend for a proactive AI fitness coach with long-term memory.

This repository now intentionally contains only the server side. The old Telegram Mini App / React frontend was removed so the backend can be deployed cleanly and later connected to a native iOS client.

## Included

- FastAPI API in `apps/api`
- Telegram Bot API webhook handler
- Long-term memory models for profile, meals, daily snapshots, strategy, reminders, and coach events
- Proactive daily analysis engine for nutrition, weight, activity, sleep, and adherence
- OpenAI integration hook with deterministic fallback recommendations
- Dockerfile for single-container backend deployment
- Docker Compose for local API, PostgreSQL, and Redis
- Focused backend tests for nutrition calculations and proactive coach analysis

## Local API

```bash
cp .env.example .env
python3 -m venv .venv
. .venv/bin/activate
pip install -r apps/api/requirements.txt
cd apps/api
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API runs on `http://localhost:8000`.

## Local Telegram Bot

For local development, Telegram cannot call `http://localhost:8000` as a webhook. Use long polling:

```bash
. .venv/bin/activate
cd apps/api
python -m app.bot.polling
```

Polling automatically calls `deleteWebhook`, then listens for Telegram updates and replies to `/start` and regular messages.

## Telegram Webhook

Set these variables in production:

```env
APP_ENV=production
API_PUBLIC_URL=https://your-server-domain
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_WEBHOOK_SECRET=generate_a_long_random_value
ADMIN_API_KEY=generate_a_long_random_value
OPENAI_API_KEY=your_openai_key_optional
OPENAI_MODEL=gpt-4.1-mini
```

Register the webhook:

```bash
curl -X POST "$API_PUBLIC_URL/api/telegram/set-webhook" \
  -H "X-Admin-Key: $ADMIN_API_KEY"
```

Useful diagnostics:

```bash
curl "$API_PUBLIC_URL/api/health"

curl "$API_PUBLIC_URL/api/telegram/debug"

curl "$API_PUBLIC_URL/api/telegram/webhook-info" \
  -H "X-Admin-Key: $ADMIN_API_KEY"
```

Do not commit real tokens. If a token was shared in chat or logs, rotate it in BotFather before production.

## Timeweb Cloud

Use the root `Dockerfile` as a backend Docker service.

See [TIMEWEB_DEPLOY.md](TIMEWEB_DEPLOY.md).

## Docker Compose

```bash
docker compose up --build -d
```

The API uses SQLite by default for quick local development. In Docker Compose it uses PostgreSQL through `DATABASE_URL`.
