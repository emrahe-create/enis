# AI Wellness Backend

Express + PostgreSQL backend for a mobile AI wellness platform.

## Features

- Email/password auth with JWT
- Forgot password and email verification placeholders
- Account deletion and personal data export endpoints
- Free subscription plus 15-day premium trial
- AI emotional support chat with OpenAI integration
- Basic and premium avatar system
- Emotion analysis engine with OpenAI and local fallback
- Wellness tools: breathing, meditation, CBT journal
- Expert matching placeholder endpoint
- Stripe checkout and webhook integration
- KVKK/privacy/terms/disclaimer legal content API
- Signup and premium purchase consent tracking
- Modular architecture for auth, users, subscriptions, chat, avatars, analytics, wellness, experts, and payments

## Setup

```bash
npm install
cp .env.example .env
npm run db:migrate
npm run dev
```

The API defaults to `http://localhost:4000`.

For production deployment, see [DEPLOYMENT.md](./DEPLOYMENT.md).

## Mobile UI

A Flutter UI shell lives in `mobile/` with onboarding, avatar selection, chat, premium upgrade, and profile screens.

```bash
cd mobile
flutter create --platforms=ios,android .
flutter pub get
flutter run
```

## Brand

Brand assets live in `assets/brand/` and the JS brand source lives in `src/brand/enis.brand.js`.

- App name is lowercase `enis`.
- Tagline EN: `Say what’s on your mind.`
- Tagline TR: `İçinden geçenleri söyle.`
- Owner company: `EQ Bilişim`
- Primary palette: soft blue to purple, with `#5D8CFF`, `#7CB7FF`, `#A78BFA`, and `#C084FC`.
- Typography should use a rounded modern sans-serif such as Inter, SF Pro, or system sans-serif.
- The mark should stay minimal and global: a rounded `e` speech-loop symbol, not a character-led identity.
- Avoid Arabic script, gendered figures, personal-relationship-role claims, professional-care-role claims, need-based attachment language, and listener/always-present claims in product copy.

Assets:

- `assets/brand/logo-enis.svg`
- `assets/brand/app-icon.svg`
- `assets/brand/colors.json`
- `assets/brand/copy.json`

## Environment

Set these in `.env`:

- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: long random signing secret
- `JWT_EXPIRES_IN`: JWT lifetime, for example `7d`
- `OPENAI_API_KEY`: enables AI chat and emotion analysis
- `OPENAI_MODEL`: OpenAI chat model, defaults to `gpt-4o-mini`
- `STRIPE_SECRET_KEY`: enables Stripe checkout
- `STRIPE_WEBHOOK_SECRET`: validates Stripe webhooks
- `STRIPE_PREMIUM_PRICE_ID`: Stripe recurring price for premium
- `APP_BASE_URL`: public backend URL, for example `https://api.enisapp.com`
- `FREE_DAILY_CHAT_LIMIT`: rolling 24-hour chat limit for non-premium users after trial/free access
- `PORT`: provided by Render in production; local default is `4000`

Without `OPENAI_API_KEY`, chat and emotion analysis use deterministic local fallback responses so the API can still be tested.

In production, set `NODE_ENV=production` and use `npm start`. Hosting platforms should provide `PORT`; the server reads it from `process.env.PORT`.

## Deployment

The backend is ready for Render using:

- Build command: `npm install && npm run db:migrate`
- Start command: `npm start`
- Health check path: `/health`

`render.yaml` is included for a Node web service with the same build, start, and health check settings.

`GET /health` returns:

```json
{
  "status": "ok",
  "service": "ai-wellness-backend"
}
```

Production CORS allows:

- `https://enisapp.com`
- `https://www.enisapp.com`
- `https://api.enisapp.com`

DNS setup for the API:

```text
Type: CNAME
Name: api
Value: <Render service domain>
```

After DNS is active, set `APP_BASE_URL=https://api.enisapp.com`.

## API Overview

### Health

- `GET /health`

### Auth

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/forgot-password`
- `POST /api/auth/email-verification`

Signup requires mandatory consent acceptance:

```json
{
  "email": "user@example.com",
  "password": "password123",
  "fullName": "Demo User",
  "avatarName": "Mira",
  "consents": {
    "kvkk_clarification_seen": true,
    "privacy_policy": true,
    "terms_of_use": true,
    "wellness_disclaimer": true,
    "marketing_permission": false
  }
}
```

### Users

- `GET /api/users/me`
- `PATCH /api/users/me`
- `GET /api/users/me/export`
- `DELETE /api/users/me`

Profiles include optional wellness onboarding fields. `avatarName` is the user-defined name for the AI avatar. Premium/trial chat can use it subtly and rarely in responses; free chat does not use it.

```json
{
  "fullName": "Demo User",
  "birthYear": 1994,
  "gender": "prefer_not_to_say",
  "city": "Istanbul",
  "occupation": "Product manager",
  "relationshipStatus": "single",
  "sleepQuality": "mixed",
  "mainGoal": "Handle daily stress more gently",
  "preferredAvatar": "warm",
  "avatarName": "Mira",
  "notificationConsent": true,
  "marketingConsent": false
}
```

### Legal

- `GET /api/legal`
- `GET /api/legal/:slug`
- `GET /api/legal/privacy-policy`
- `GET /api/legal/kvkk-clarification`
- `GET /api/legal/explicit-consent`
- `GET /api/legal/terms-of-use`
- `GET /api/legal/distance-sales-agreement`
- `GET /api/legal/cancellation-refund-policy`
- `GET /api/legal/disclaimer`
- `GET /api/legal/faq`

Each legal endpoint returns `{ slug, title, version, updatedAt, company, content }`. Legal text is versioned and states that Enis is not psychotherapy, does not diagnose or treat, and is for wellness and emotional support only. In crisis situations, users are directed to emergency services or qualified professionals.

### Subscriptions

- `GET /api/subscriptions/me`
- `POST /api/subscriptions/trial`

`POST /api/subscriptions/trial` starts a one-time 15-day premium trial. `GET /api/subscriptions/me` returns the current subscription, trial state, feature entitlements, and chat usage.

```json
{
  "trial": {
    "available": false,
    "active": true,
    "expired": false,
    "daysRemaining": 15
  },
  "entitlements": {
    "premium": true,
    "fullFeatures": true,
    "unlimitedChat": true,
    "memoryChat": true,
    "premiumAvatars": true
  },
  "usage": {
    "chat": {
      "period": "rolling_24_hours",
      "used": 0,
      "limit": null,
      "remaining": null,
      "limited": false
    }
  }
}
```

When the trial expires and no active Stripe subscription is present, the backend marks the user as `trial_expired`, removes premium entitlements, and enforces the configured free chat limit. Active Stripe subscriptions unlock full features and unlimited chat.

### Chat

- `GET /api/chat/sessions`
- `POST /api/chat/sessions`
- `POST /api/chat/message`
- `POST /api/chat/respond`

`/api/chat/message` and `/api/chat/respond` accept user text and return an empathetic conversational response from Enis, an AI wellness companion for supportive reflection. Free users receive shorter supportive replies with no memory. Premium users receive deeper replies that can use the last five stored conversation turns, gently reflect repeated themes, and ask a warm follow-up question.

All chat requests require `Authorization: Bearer <token>`.

Free request:

```json
{
  "text": "I feel anxious before work today",
  "avatar": "structured",
  "sessionId": "optional-existing-session-id"
}
```

Valid avatar personalities are:

- `structured`: calm, structured
- `warm`: casual, warm
- `guide`: slow, peaceful

Free response:

```json
{
  "response": "It seems like anxious in what you shared is present. What feels like the heaviest part right now? It might help to pause and notice one manageable next step.",
  "tone": "calm, structured",
  "suggestion": "It might help to name the feeling and notice one small next step.",
  "memoryUsed": false,
  "premiumUpsell": "Bu konuşmayı daha derin ve kişisel şekilde sürdürmek istersen Premium avatar seni daha iyi takip edebilir.",
  "avatarNameUsed": false
}
```

Premium request:

```json
{
  "text": "Work pressure is back again today",
  "avatar": "warm",
  "sessionId": "existing-session-id"
}
```

Premium response:

```json
{
  "response": "I'm Mira. It seems like anxious in what you shared is present, and naming it may make it a little easier to look at. I am noticing work pressure has come up more than once in what you have shared here. What part feels most important to talk through next?",
  "tone": "casual, warm",
  "suggestion": "It might help to stay with the feeling for a moment, then notice the smallest useful action.",
  "memoryUsed": true,
  "premiumUpsell": null,
  "avatarNameUsed": true
}
```

The AI support layer avoids labels, certainty claims, scores, percentages, strict commands, and care-plan language. It keeps the tone supportive, brief, and non-judgmental.

If a message contains self-harm signals or crisis language, chat bypasses avatar/personality generation and returns a fixed safety response instead. The response shows a warning and points to external help such as local emergency services and the 988 Suicide & Crisis Lifeline in the U.S.

Crisis request:

```json
{
  "text": "I cannot stay safe right now.",
  "avatar": "guide"
}
```

Crisis response:

```json
{
  "response": "Safety warning: I am concerned about your immediate safety...",
  "tone": "safety-focused",
  "suggestion": "It may be safest to contact emergency services or a trusted crisis line now.",
  "memoryUsed": false,
  "premiumUpsell": null,
  "avatarNameUsed": false
}
```

### Avatars

- `GET /api/avatars/catalog`
- `GET /api/avatars`
- `POST /api/avatars`

The avatar catalog returns the built-in personality system: Structured, Friend, and Guide. Premium users get deeper emotional replies, follow-up questions, and memory-based continuity; free users get simpler replies in the selected personality.

### Analytics

- `POST /api/analytics/emotion`
- `GET /api/analytics/emotion/summary`

`POST /api/analytics/emotion` detects stress, anxiety signals, and mood level from user text. The response is intentionally human-readable: no percentages, scores, or labels.

```json
{
  "text": "I feel overwhelmed and worried today"
}
```

```json
{
  "analysis": {
    "stress": "some",
    "anxietySignals": "some",
    "moodLevel": "mixed",
    "summary": "You seem stressed and uneasy, with your mood needing some gentle care today."
  }
}
```

### Wellness

- `GET /api/wellness/tools`
- `GET /api/wellness/entries`
- `POST /api/wellness/entries`

### Experts

- `GET /api/experts/matching`
- `GET /api/experts/waitlist`
- `POST /api/experts/waitlist`

Expert matching is a placeholder for now and returns `status: "coming_soon"` with waitlist information. Authenticated users can join or update their waitlist preferences.

```json
{
  "preferredFocus": ["stress", "sleep", "cbt"],
  "note": "I prefer evening sessions."
}
```

The database is prepared for future expert profiles, specialties, availability, waitlist entries, and match requests.

### Payments

- `POST /api/payments/checkout-session`
- `POST /api/payments/webhook/stripe`

Premium checkout requires active acceptance of the distance sales agreement and cancellation/refund policy before a Stripe session is created:

```json
{
  "consents": {
    "distance_sales": true,
    "cancellation_refund_policy": true
  }
}
```

Checkout sessions attach `userId` metadata to the Stripe subscription. Stripe webhooks update subscription status, current period end, cancellation state, and store processed events for subscription tracking/idempotency.

## Example Auth Flow

```bash
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123","fullName":"Demo User","avatarName":"Mira","consents":{"kvkk_clarification_seen":true,"privacy_policy":true,"terms_of_use":true,"wellness_disclaimer":true}}'
```

Use the returned token:

```bash
curl http://localhost:4000/api/subscriptions/me \
  -H "Authorization: Bearer <token>"
```

## Notes

This backend is built for product iteration. It includes real persistence, migrations, service boundaries, and external provider integration points, while keeping expert matching as an explicit coming-soon placeholder.
