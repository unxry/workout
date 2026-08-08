# Timeweb Cloud Backend Deploy

Deploy this repository as one Docker backend service.

Use this setup for Timeweb:

- Repository: `https://github.com/unxry/workout`
- Branch: `main`
- Framework/type: `Other` or `Dockerfile`, depending on the Timeweb screen
- Dockerfile path: `Dockerfile`
- Project directory: empty or `/`
- Port: `8080`
- Build command: empty
- Build directory: empty

The root `Dockerfile` starts FastAPI directly. It does not build or serve a React frontend.

## Environment Variables

Set these variables in the Timeweb app panel:

```env
APP_ENV=production
DATABASE_URL=sqlite:////app/fitness_coach.sqlite3
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_WEBHOOK_SECRET=generate_a_long_random_value
ADMIN_API_KEY=generate_a_long_random_value
OPENAI_API_KEY=your_openai_key_optional
OPENAI_MODEL=gpt-4.1-mini
API_PUBLIC_URL=https://your-timeweb-app-domain
WEB_CORS_ORIGINS=https://your-timeweb-app-domain
```

For a quick first launch, SQLite is enough. Later, move `DATABASE_URL` to a managed PostgreSQL database.

## Check The API

After deploy, open:

```text
https://your-timeweb-app-domain/api/health
```

Expected:

```json
{"status":"ok"}
```

Then open:

```text
https://your-timeweb-app-domain/api/telegram/debug
```

Expected:

```json
{
  "telegram_token_configured": true
}
```

## Register Telegram Webhook

Run this from your Mac terminal:

```bash
curl -X POST "https://your-timeweb-app-domain/api/telegram/set-webhook" \
  -H "X-Admin-Key: your_admin_api_key"
```

Then send `/start` to the Telegram bot.

## Important

Do not use local polling in production. Production must use webhook mode.
