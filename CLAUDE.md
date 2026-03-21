# CLAUDE.md — Digital Vision Board

AI assistant guidance for the **Digital Vision Board** (package: `habitseeding`) codebase.

---

## Project Overview

A gamified habit-tracking and personal growth application with:
- **Flutter app** — iOS, Android, Web, macOS, Windows, Linux (primary codebase, ~253 Dart files)
- **Node.js backend** — Express REST API with PostgreSQL or JSON-file storage
- **Next.js webapp** — Admin dashboard and web access

Design metaphor: **"Morning Garden"** — warm, earthy, calm. Opens every morning without anxiety.

---

## Repository Structure

```
digital-vision-board/
├── lib/                    # Flutter/Dart app source (primary)
│   ├── main.dart           # App entry point
│   ├── screens/            # UI screens (11 categories)
│   ├── widgets/            # Reusable widgets (16 categories)
│   ├── services/           # Business logic, storage, sync (40+ files)
│   ├── models/             # Data models (25+ files)
│   └── utils/              # AppColors, AppSpacing, AppTypography, etc.
├── backend/                # Node.js Express API
│   └── src/
│       ├── server.js       # Main server (1107 lines, 40+ routes)
│       ├── db.js           # Database abstraction layer
│       ├── gemini.js       # Gemini AI wizard recommendations
│       ├── pexels.js       # Stock photo integration
│       └── migrations/     # 21 numbered SQL migration files (001–020)
├── webapp/                 # Next.js 14 webapp
│   └── src/
│       ├── app/            # App Router pages
│       ├── components/     # Shared React components
│       └── lib/            # Utilities (firebase, backend, session, seo)
├── test/                   # Flutter unit & widget tests
├── integration_test/       # Flutter integration tests
├── assets/                 # Images, animations (Lottie), audio
├── .github/workflows/      # CI/CD pipelines
├── pubspec.yaml            # Flutter dependencies
├── firebase.json           # Firebase project config (habitseeding-prod)
├── .cursorrules            # Full design system rules (Morning Garden palette)
├── ENV_SETUP.md            # Environment variable reference
└── README.md               # Firebase setup, CI/CD, testing notes
```

---

## Development Commands

### Flutter App

```bash
flutter pub get              # Install dependencies
flutter test                 # Run all tests
flutter test --coverage      # Tests with coverage (LCOV output)
flutter analyze              # Static analysis
flutter run                  # Run on connected device/emulator
flutter build apk            # Build Android APK
flutter build web            # Build web
```

Generate coverage HTML report:
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Backend

```bash
cd backend
npm install
npm run dev     # Development with watch mode (node --watch)
npm start       # Production start
```

### Webapp

```bash
cd webapp
npm install
npm run dev     # Next.js dev server
npm run build   # Production build
npm run lint    # ESLint
npm start       # Production server
```

---

## Environment Setup

### Backend (`backend/.env`)

```env
PORT=8787
BASE_URL=http://127.0.0.1:8787

# Optional — defaults to JSON file storage in backend/data/
DATABASE_URL=postgres://user:password@localhost:5432/digital_vision_board

# Optional — for Firebase auth exchange
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}

# Optional — for wizard AI recommendations
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-1.5-flash

# Optional — for stock image search
PEXELS_API_KEY=your_pexels_api_key

CORS_ORIGIN=*
NODE_ENV=development
```

### Webapp (`webapp/.env.local`)

```env
NEXT_PUBLIC_BACKEND_URL=https://your-backend.com
NEXT_PUBLIC_FIREBASE_API_KEY=...
FIREBASE_PRIVATE_KEY=...
GOOGLE_SITE_VERIFICATION=...
```

See `ENV_SETUP.md` for the complete reference.

---

## Architecture & Key Conventions

### Flutter State Management

- **Provider + SharedPreferences** — do NOT introduce Riverpod or Bloc unless already present
- Services use static methods or singleton instances
- `AppSettingsService` holds global settings (theme mode as `ValueListenable<ThemeMode>`)

### Flutter App Startup (`lib/main.dart`)

Initialization order matters:
1. `SharedPreferences` — detect new vs existing user for onboarding
2. `AppSettingsService`, `LogicalDateService` — load settings
3. Firebase (non-fatal, app works without it)
4. Lazy/non-blocking: `WizardDefaultsService`, `NotificationsService`, geofence, ads, subscriptions, affirmations

Startup screen decision:
- New user → `OnboardingScreen`
- Existing, no legal consent → `LegalConsentScreen`
- Otherwise → `DashboardScreen`

### Screen Orientation

App is locked to portrait (`portraitUp` + `portraitDown`).

### Theme System

Always use `_buildTheme()` pattern in `main.dart`. Theme is applied via `ValueListenableBuilder` on `AppSettingsService.themeMode`. Uses Material 3 (`useMaterial3: true`) with `GoogleFonts.inter`. `AppColors.lightScheme` / `darkScheme` use mist/sky and `sproutGreen` aligned to the app icon (medium tint), with `brand*` tokens documenting raw icon samples.

---

## Design System — Morning Garden Palette

**Core rule**: every color/spacing/type choice should feel like "6 AM in a quiet garden — warm, grounded, alive, and never loud."

### Colors (`lib/utils/app_colors.dart`)

| Token | Hex | Use |
|---|---|---|
| `AppColors.mistBackground` | `#F6F1DD` | Page background (butter-warm mist, logo-tinted) |
| `AppColors.skyTopTint` | `#ECEFD5` | Background gradient top |
| `AppColors.sproutGreen` | `#3F6E38` | Primary CTA, active icons, progress rings (icon-aligned, WCAG AA) |
| `AppColors.brandLogoFieldYellow` etc. | (see `app_colors.dart`) | Sampled from app icon — accents / splash, not full-page fill |
| `AppColors.forestDeep` | `#3B2D20` | Bottom nav bg, headings, earthy anchors |
| `AppColors.seedGold` | `#C48B3C` | Coin/badge icon fill — NOT as text |
| `AppColors.honeyText` | `#7A5520` | Any amber/reward text (WCAG AA: 6.7:1) |
| `AppColors.sageContainer` | `#D6EBD4` | Chips, selected rows, tags |
| `AppColors.seedChampagne` | `#FDF3E3` | Badge/reward container backgrounds |
| `AppColors.lavenderDew` | `#7B74A8` | Mood, journal, affirmations |
| `AppColors.lavenderContainer` | `#EEEDF8` | Lavender feature containers |
| `AppColors.cloudWhite` | `#FFFFFF` | Light mode card surface |
| `AppColors.cloudDark` | `#1F2B22` | Dark mode card surface |

**Semantic usage** (use these helpers, not raw hex):
```dart
AppColors.skyDecoration(isDark: isDark)    // Page background
AppColors.cloudDecoration(isDark: isDark)  // Content card
colorScheme.primary                        // Primary button / FAB / progress
colorScheme.surface                        // Scaffold background
```

### Spacing (`lib/utils/app_spacing.dart`)

Use `AppSpacing` constants — do not hardcode pixel values.

Key constants (verify in file):
- `AppSpacing.xs`, `AppSpacing.sm`, `AppSpacing.md`, `AppSpacing.lg`
- `AppSpacing.radiusCard`, `AppSpacing.radiusInput`, `AppSpacing.radiusChip`

### Typography

- Font: `GoogleFonts.inter` applied globally via `ThemeData.textTheme`
- Use `Theme.of(context).textTheme.*` — do not create standalone `TextStyle` with custom fonts

---

## Key Services

| Service | File | Purpose |
|---|---|---|
| `DvAuthService` | `services/dv_auth_service.dart` | Firebase + guest session auth |
| `AppSettingsService` | `services/app_settings_service.dart` | Global settings, theme mode |
| `LogicalDateService` | `services/logical_date_service.dart` | Date logic (tracks "today") |
| `AdService` | `services/ad_service.dart` | Google Mobile Ads |
| `SubscriptionService` | `services/subscription_service.dart` | RevenueCat in-app purchases |
| `AffirmationService` | `services/affirmation_service.dart` | Affirmations storage/seeding |
| `WizardDefaultsService` | `services/wizard_defaults_service.dart` | Prefetched wizard defaults |
| `NotificationsService` | `services/notifications_service.dart` | Push/local notifications |
| `AutoSyncService` | `services/auto_sync_service.dart` | Background data sync |
| `BackupService` | `services/backup_service.dart` | Google Drive backup |

---

## Backend Architecture

### Database Abstraction

`backend/src/db.js` abstracts storage:
- With `DATABASE_URL`: PostgreSQL via `pg` pool
- Without: JSON file storage in `backend/data/` (development-friendly fallback)

### SQL Migrations

Files in `backend/src/migrations/` named `NNN_description.sql`. Run via `migrate.js`. Always add new migrations as the next numbered file — never edit existing ones.

### Key API Areas (`backend/src/server.js`)

- Auth & user management
- Board data (vision boards, components)
- Habit/routine/journal data
- Templates (with admin approval workflow)
- Wizard recommendations (Gemini AI)
- Stock photos (Pexels)
- Subscriptions, gift codes
- Contact/support messages

---

## Webapp Architecture (Next.js 14)

- **App Router** with TypeScript
- Path alias: `@/*` → `src/*`
- Firebase for auth; backend URL proxied via `api/backend/[...path]/` route
- Tailwind CSS for styling
- Admin routes: `/admin/presets/`, `/admin/contact/`
- Auth callbacks: `/auth/callback/`, `/auth/signout/`

---

## Testing

### Flutter Tests

```
test/                    # Unit & widget tests
├── data/                # Data layer tests
├── models/              # Model tests
└── services/            # Service tests

integration_test/        # Integration tests
└── app_test.dart        # Main integration entry
```

Run all: `flutter test`
Run with coverage: `flutter test --coverage`

### Coverage threshold

Currently set to 0% in CI — raise this as test coverage improves.

---

## CI/CD Workflows

| Workflow | Trigger | Action |
|---|---|---|
| `test_and_staging_build.yml` | PR to `master`/`main`/`dev` or manual | Tests + staging APK/iOS/Web |
| `android_release.yml` | Push to `master` (after PR merge) | Tests + signed AAB/APK + Play Store |
| `webapp_vercel_production.yml` | Push to `main`/`master` (webapp changes) | Lint + build + Vercel deploy |

### Required Secrets for Release

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Signed Android release builds |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play deployment |
| `FIREBASE_APP_ID` + `FIREBASE_TOKEN` | Firebase App Distribution |

---

## Firebase Setup

- Project ID: `habitseeding-prod`
- Flutter package: `com.habitseeding.app` (Android & iOS)
- Auth methods: Google Sign-In, phone auth, guest sessions
- Run `flutterfire configure` to regenerate `lib/firebase_options.dart`

See `README.md` → Firebase / FlutterFire Setup section.

---

## Common Pitfalls

1. **Do not use raw hex colors** — always use `AppColors.*` or `colorScheme.*` tokens
2. **`AppColors.seedGold` fails WCAG AA as text** — use `AppColors.honeyText` for amber text
3. **Firebase failures are non-fatal** — initialization is wrapped in try/catch; app runs without Firebase
4. **No Riverpod/Bloc** — use Provider + SharedPreferences only
5. **Backend data/** directory — auto-created for JSON storage; do not commit its contents
6. **Migrations are append-only** — never edit existing SQL migration files
7. **Portrait lock** — do not use landscape-only layouts; app is portrait-only on mobile
8. **`unawaited()`** — used intentionally for best-effort background tasks; don't convert to `await`

---

## Additional Documentation

- `.cursorrules` — Full design system rules (colors, spacing, typography, component patterns)
- `ENV_SETUP.md` — Complete environment variable reference
- `AI_CONTEXT.txt` — Comprehensive feature breakdown (updated 2026-02-20)
- `docs/revenuecat_*.md` — RevenueCat integration & webhook docs
- `README.md` — Firebase setup, CI/CD, platform-specific build notes
