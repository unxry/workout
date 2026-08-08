# Timeweb Cloud App Platform Deploy

Timeweb App Platform is simplest with one Docker container. The root `Dockerfile` builds the Telegram Mini App and serves it from FastAPI together with the API.

Use this setup for Timeweb:

- Repository: `https://github.com/unxry/workout`
- Branch: `main`
- Build type/framework: `Dockerfile` / `Docker`
- Dockerfile path: `Dockerfile`
- Port: `8080`

Timeweb App Platform does not use `docker-compose.yml` for this flow, so use the root `Dockerfile`.

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
PUBLIC_WEBAPP_URL=https://your-timeweb-app-domain
WEB_CORS_ORIGINS=https://your-timeweb-app-domain
```

For a quick first launch, SQLite is enough. Later, move `DATABASE_URL` to a managed PostgreSQL database.

## Check The App

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
  "telegram_token_configured": true,
  "public_webapp_url_is_https": true
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

Do not use `npm run dev:bot` on Timeweb. Production must use webhook mode.
