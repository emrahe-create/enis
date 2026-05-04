# Enis Mobile MVP

Flutter MVP UI for `enis`, an AI wellness companion app owned by EQ Bilişim. Enis is not therapy, diagnosis, or treatment.

## Architecture

- `lib/src/core`: brand colors, theme, reusable widgets, API client, JWT token storage
- `lib/src/features`: auth, avatar setup, chat, premium, profile, legal, explore, journal
- API calls use `API_BASE_URL` when provided, otherwise Android emulator defaults to `http://10.0.2.2:4000` and iOS simulator defaults to `http://localhost:4000`
- JWTs are stored with `flutter_secure_storage`
- Mobile subscriptions are disabled for launch and will be activated through App Store and Google Play later
- Mock fallback data is allowed only in debug mode when `APP_ENV` is not `production`

## Screens

- Splash
- Onboarding
- Register and login
- Avatar setup
- Chat
- Premium
- Profile
- Legal
- Bottom navigation: Sohbet, Keşfet, Günlük, Profil

## Run Locally

Install Flutter, then from this folder:

```bash
flutter create --platforms=ios,android .
flutter pub get
flutter run
```

Override the backend URL when needed:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

## Production API

Use the Enis production API:

```bash
flutter run --dart-define=API_BASE_URL=https://api.enisapp.com
flutter build apk --dart-define=API_BASE_URL=https://api.enisapp.com
flutter build ios --dart-define=API_BASE_URL=https://api.enisapp.com
```

In debug mode, the app makes a non-blocking `/health` check on startup and shows a small warning if the API cannot be reached.

Mock fallback behavior can be disabled during debug runs:

```bash
flutter run --dart-define=ALLOW_MOCK_FALLBACK=false
```

Production flavor disables mock fallback and surfaces API errors:

```bash
flutter run --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.enisapp.com
```

The UI uses abstract brand assets, neutral positioning, and no therapy claims.
