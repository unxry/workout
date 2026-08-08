# AI Fitness Coach Telegram Mini App

Commercial-grade Telegram Mini App and bot scaffold for a proactive AI fitness coach with long-term memory.

## What is included

- React + TypeScript Telegram Mini App UI in `apps/web`
- FastAPI backend in `apps/api`
- Telegram Bot API webhook handler
- Long-term memory models for profile, meals, daily snapshots, strategy, reminders, and coach events
- Proactive daily analysis engine for nutrition, weight, activity, sleep, and adherence
- OpenAI integration hook with deterministic fallback recommendations
- Docker Compose for API, web, PostgreSQL, Redis, and Nginx
- Focused backend tests for nutrition calculations and proactive coach analysis

## Quick start

```bash
cp .env.example .env
npm install
npm run install:api
npm run dev
```

API runs on `http://localhost:8000`.
Mini App runs on `http://localhost:5173`.

## Local Telegram bot

For local development, Telegram cannot call `http://localhost:8000` as a webhook. Use long polling:

```bash
npm run dev:bot
```

Or run everything together:

```bash
npm run dev:all
```

Polling automatically calls `deleteWebhook`, then listens for Telegram updates and replies to `/start` and regular messages.

## Telegram setup

1. Create or open your bot in BotFather.
2. Put the token into `.env` as `TELEGRAM_BOT_TOKEN`.
3. For local bot replies, run `npm run dev:bot`.
4. For a real Telegram Mini App button on a phone, set `PUBLIC_WEBAPP_URL` to an HTTPS URL.
5. For production webhook mode, set `API_PUBLIC_URL` to your HTTPS API URL and register webhook:

```bash
curl -X POST "$API_PUBLIC_URL/api/telegram/set-webhook" \
  -H "X-Admin-Key: $ADMIN_API_KEY"
```

Useful diagnostics:

```bash
curl "$API_PUBLIC_URL/api/telegram/webhook-info" \
  -H "X-Admin-Key: $ADMIN_API_KEY"

curl -X POST "$API_PUBLIC_URL/api/telegram/delete-webhook" \
  -H "X-Admin-Key: $ADMIN_API_KEY"
```

Do not commit real tokens. If a token was shared in chat or logs, rotate it in BotFather before production.

## Railway Deployment

For the simplest production launch, use Railway with two services from this repository:

- API service from `apps/api`
- Web service from `apps/web`

See [RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md) for exact settings and environment variables.

If Railway reports `Missing script: "build"`, the service is pointed at the wrong root directory or an old commit. The web service root must be `apps/web`, or it must use the root package scripts from the latest `main` branch.

## Production With Docker Compose

```bash
docker compose up --build -d
```

The API uses SQLite by default for local development. In Docker it uses PostgreSQL through `DATABASE_URL`.
