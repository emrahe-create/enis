# Enis Mobile MVP

Flutter MVP UI for `enis`, an AI wellness companion app owned by EQ Bilişim. Enis is not therapy, diagnosis, or treatment.

## Architecture

- `lib/src/core`: brand colors, theme, reusable widgets, API client, JWT token storage
- `lib/src/features`: auth, avatar setup, chat, premium, profile, legal, explore, journal
- API calls use `API_BASE_URL` when provided, otherwise Android emulator defaults to `http://10.0.2.2:4000` and iOS simulator defaults to `http://localhost:4000`
- JWTs are stored with `flutter_secure_storage`
- Stripe checkout URLs open in the external browser with `url_launcher`
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

Mock fallback behavior can be disabled during debug runs:

```bash
flutter run --dart-define=ALLOW_MOCK_FALLBACK=false
```

Production flavor disables mock fallback and surfaces API errors:

```bash
flutter run --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.example.com
```

The UI uses abstract brand assets, neutral positioning, and no therapy claims.
