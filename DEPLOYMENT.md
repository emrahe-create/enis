# Deployment Guide

This backend is a Node.js Express API for Enis. It uses PostgreSQL, JWT auth, OpenAI, and Stripe.

## Production Checks

- Start command: `npm start`
- Optional production start command: `npm run start:prod`
- Server port: uses `process.env.PORT` through `src/config/env.js`
- Health check: `GET /health`
- Required runtime: Node.js with `npm install`
- Database migration command: `npm run db:migrate`

## Required Environment Variables

Set these in the hosting provider dashboard:

```bash
DATABASE_URL=
JWT_SECRET=
JWT_EXPIRES_IN=7d
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PREMIUM_PRICE_ID=
APP_BASE_URL=
FREE_DAILY_CHAT_LIMIT=10
PORT=4000
```

Recommended production values:

```bash
NODE_ENV=production
APP_BASE_URL=https://api.enisapp.com
```

`JWT_SECRET` must be a long random secret. Do not reuse the example value in production.

## CORS

The API allows browser requests from:

- `https://enisapp.com`
- `https://www.enisapp.com`
- `https://api.enisapp.com`

Requests without an `Origin` header are allowed for server-to-server and mobile app calls.

## Render

1. Create a new Web Service from the repository.
2. Set the runtime to Node.js.
3. Build command: `npm install && npm run db:migrate`
4. Start command: `npm start`
5. Add a PostgreSQL database and copy its connection string to `DATABASE_URL`.
6. Add all required environment variables from this guide.
7. Confirm the migration step completed during the Render build.
8. Set the health check path to `/health`.
9. Add the custom domain `api.enisapp.com` after the service is live.

## Railway

1. Create a new Railway project from the repository.
2. Add a PostgreSQL service.
3. Set `DATABASE_URL` from the PostgreSQL service connection string.
4. Add all required environment variables from this guide.
5. Use `npm start` as the start command.
6. Run `npm run db:migrate` after deployment or from a one-off shell.
7. Confirm `GET /health` returns `{ "status": "ok", "service": "ai-wellness-backend" }`.
8. Add the custom domain `api.enisapp.com` after the service is live.

## DNS

Create this DNS record for the API:

```text
Type: CNAME
Name: api
Value: <Render service domain>
```

After DNS propagates, set:

```bash
APP_BASE_URL=https://api.enisapp.com
```
