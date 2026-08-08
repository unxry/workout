# Railway Deploy Guide

Deploy this project as two Railway services from the same GitHub repository.

## 1. API Service

Create a new Railway project from GitHub and choose this repository.

Service settings:

- Root directory: `apps/api`
- Builder: Dockerfile
- Public networking: Generate Domain

Add PostgreSQL in the same Railway project, then attach its `DATABASE_URL` to the API service.

API environment variables:

```env
APP_ENV=production
DATABASE_URL=${{Postgres.DATABASE_URL}}
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_WEBHOOK_SECRET=generate_a_long_random_value
ADMIN_API_KEY=generate_a_long_random_value
OPENAI_API_KEY=your_openai_key_optional
OPENAI_MODEL=gpt-4.1-mini
API_PUBLIC_URL=https://your-api-service.up.railway.app
PUBLIC_WEBAPP_URL=https://your-web-service.up.railway.app
WEB_CORS_ORIGINS=https://your-web-service.up.railway.app
```

After the API is deployed, open:

```text
https://your-api-service.up.railway.app/api/health
```

It should return:

```json
{"status":"ok"}
```

## 2. Web Service

Add another service from the same GitHub repository.

Service settings:

- Root directory: `apps/web`
- Builder: Dockerfile
- Public networking: Generate Domain

Web build variable:

```env
VITE_API_URL=https://your-api-service.up.railway.app
```

After deployment, copy the generated web URL into the API service as:

```env
PUBLIC_WEBAPP_URL=https://your-web-service.up.railway.app
WEB_CORS_ORIGINS=https://your-web-service.up.railway.app
```

Redeploy the API service after changing these values.

## 3. Register Telegram Webhook

Use your API domain and admin key:

```bash
curl -X POST "https://your-api-service.up.railway.app/api/telegram/set-webhook" \
  -H "X-Admin-Key: your_admin_api_key"
```

Check webhook status:

```bash
curl "https://your-api-service.up.railway.app/api/telegram/webhook-info" \
  -H "X-Admin-Key: your_admin_api_key"
```

## Important

Do not run `npm run dev:bot` in production. Production should use Telegram webhook mode.

Only one mode can receive Telegram messages:

- Local development: polling via `npm run dev:bot`
- Production: webhook via `/api/telegram/set-webhook`
