# Shared Memory — Digital Vision Board (habitseeding)

Persistent context for Claude Code sessions. Updated: 2026-04-14.
This file captures key decisions, known issues, audit findings, and architectural context so every Claude session starts with full awareness.

---

## Project Identity

- **App name**: Digital Vision Board
- **Package**: `habitseeding` / `com.habitseeding.app`
- **Firebase project**: `habitseeding-prod`
- **Primary language**: Dart/Flutter (277 files, ~85,200 LOC)
- **Backend**: Node.js Express (`backend/`) + PostgreSQL or JSON fallback
- **Webapp**: Next.js 14 (`webapp/`) — admin dashboard
- **Platforms**: iOS, Android, Web, macOS, Windows, Linux
- **Status**: Near production-ready (as of 2026-04-14)

---

## Permanent Architectural Decisions

### 1. Do NOT switch to Swift iOS
Flutter gives iOS + Android + Web + Desktop from one codebase. Swift iOS would mean:
- Losing Android permanently
- Losing the web presence
- Re-writing 85,200 lines from scratch
- 6–12 months of rework for zero user-visible benefit
- Native Swift is already used where needed: `ios/HabitProgressWidget/` (WidgetKit), `ios/Runner/AppDelegate.swift` (method channels)

**Decision: Stay on Flutter. Use Swift only for system-level extensions (WidgetKit, Live Activities).**

### 2. State management: Provider + SharedPreferences only
Do NOT introduce Riverpod, Bloc, or GetX. Existing pattern is static service methods + SharedPreferences. 

### 3. Portrait-only
App is locked to portraitUp + portraitDown. No landscape layouts.

### 4. Backend is dual-mode
`db.js` falls back to JSON file storage if `DATABASE_URL` is absent. Do not assume PostgreSQL is always running.

### 5. Firebase is non-fatal
Firebase init is wrapped in try/catch. The app runs without Firebase. Never block startup on Firebase.

### 6. Migrations are append-only
Never edit existing SQL migration files in `backend/src/migrations/`. Always add a new numbered file.

---

## Known Issues (Audit: 2026-04-14)

### Auth / Login (CRITICAL)
- **Google Sign-In may fail silently** — if SHA-1 fingerprint is not registered in Firebase Console or `google-services.json`/`GoogleService-Info.plist` is outdated, login produces no error message to the user
- **Guest token expiry not enforced on client** — `dv_auth_service.dart` stores a 10-day token but likely does not proactively check expiry on cold start; users may hit 401s from the backend with no recovery UI
- **Hardcoded backend URL fallback** — `DvAuthService.backendBaseUrl()` falls back to `https://digital-vision-board.onrender.com`; if this server is down, all authenticated features silently fail
- **No refresh token flow** — when a dvToken expires, the user is not automatically re-authenticated; they may see blank screens instead of a login prompt

### Design Violations (85+ files)
- **Typography**: 85+ `TextStyle()` instances bypass `AppTypography` — worst offenders: `recipe_book_screen.dart` (7), `challenge_setup_screen.dart` (11), `calorie_tracker_card.dart` (8), `main.dart` (8)
- **Spacing**: ~20 hardcoded pixel values instead of `AppSpacing.*` — worst: `auth_gateway_screen.dart` (10 violations)
- **Loading states**: `CircularProgressIndicator()` uses default Material blue — clashes with Morning Garden warm palette; should use `colorScheme.primary` (sproutGreen)
- **Legacy backgrounds**: ~5 screens use old `skyGradientTopDark` instead of `AppColors.skyDecoration(isDark: isDark)`

### Technical Debt
- `lib/screens/planner_guide_screen.dart` is 2,841 lines — should be split into sub-widgets
- `lib/widgets/dashboard/all_boards_habits_tab.dart` is 3,956 lines — largest file, high complexity
- `lib/screens/add_habit_modal.dart` is 2,024 lines — multi-step wizard should be broken into steps
- `print()` / `debugPrint()` statements likely left in service files (not stripped for production)
- Test coverage is effectively 0% in CI — threshold not raised after initial setup

---

## Design System Quick Reference (Morning Garden)

**Rule**: every UI choice should feel like "6 AM in a quiet garden — warm, grounded, alive, never loud."

| Need | Token |
|---|---|
| Page background | `AppColors.skyDecoration(isDark: isDark)` |
| Content card | `AppColors.cloudDecoration(isDark: isDark)` |
| Primary CTA / progress | `colorScheme.primary` (sproutGreen #3F6E38) |
| Bottom nav bg | `AppColors.forestDeep` (#3B2D20) |
| Reward text | `AppColors.honeyText` (#7A5520) — NEVER seedGold as text |
| Mood / journal | `AppColors.lavenderDew` (#7B74A8) |
| Scaffold bg | `colorScheme.surface` |

**Typography**: always `AppTypography.heading1/2/3(context)`, `body()`, `bodySmall()`, `caption()` — never raw `TextStyle()`

**Spacing**: always `AppSpacing.xs/sm/md/lg/xl/xxl` — never hardcoded pixels

**Dark mode detection**: `final isDark = Theme.of(context).brightness == Brightness.dark;`

---

## Claude Skills Available (`.claude/commands/`)

| Command | Purpose |
|---|---|
| `/flutter-widget` | New widget following Morning Garden design |
| `/flutter-screen` | New screen with correct scaffold pattern |
| `/flutter-service` | New or extended service |
| `/flutter-model` | Dart model with fromJson/toJson/copyWith |
| `/flutter-test` | Unit/widget/integration tests |
| `/ios-native` | Swift method channels or WidgetKit extensions |
| `/design-review` | Audit against Morning Garden tokens |
| `/brand` | Brand/tone-of-voice review |
| `/ai-guardrails` | AI integration safety review (Gemini, Pexels) |
| `/backend-route` | New Express route |
| `/new-migration` | New SQL migration file |
| `/webapp-page` | New Next.js 14 page |

Design guard runs automatically on every file edit via `.claude/scripts/design-check.sh`.

---

## Key File Map

| What you want | Where it is |
|---|---|
| App entry | `lib/main.dart` |
| Dashboard | `lib/screens/dashboard_screen.dart` |
| Home tab cards | `lib/widgets/dashboard/dashboard_tab.dart` |
| Habits tab | `lib/widgets/dashboard/all_boards_habits_tab.dart` (3,956 lines) |
| Auth service | `lib/services/dv_auth_service.dart` |
| Color tokens | `lib/utils/app_colors.dart` |
| Spacing tokens | `lib/utils/app_spacing.dart` |
| Typography tokens | `lib/utils/app_typography.dart` |
| iOS WidgetKit | `ios/HabitProgressWidget/HabitProgressWidget.swift` |
| iOS method channels | `ios/Runner/AppDelegate.swift` |
| Backend entry | `backend/src/server.js` |
| DB abstraction | `backend/src/db.js` |
| SQL migrations | `backend/src/migrations/` (append-only, NNN_name.sql) |
| Webapp pages | `webapp/src/app/` |

---

## Features That Need Attention Before Launch

1. **Login flow** — test Google Sign-In end-to-end on a real device with production Firebase config
2. **Guest token expiry** — add proactive expiry check on app cold start
3. **Loading state colors** — fix `CircularProgressIndicator` to use `colorScheme.primary`
4. **Typography cleanup** — migrate worst-offender files to `AppTypography`
5. **CI test coverage** — raise threshold from 0%; add at least model serialization tests
6. **Production API keys** — confirm no test/debug AdMob IDs or RevenueCat sandbox keys are in the release build

---

## Screens Inventory (70+ routes)

All screens in `lib/screens/` are reachable — no orphaned/dead screens found in the 2026-04-14 audit.

Notable large screens requiring care when editing:
- `all_boards_habits_tab.dart` — 3,956 lines
- `planner_guide_screen.dart` — 2,841 lines
- `add_habit_modal.dart` — 2,024 lines
- `meal_prep_week_screen.dart` — 1,818 lines
- `skincare_planner_screen.dart` — 1,791 lines

---

## CI/CD

| Workflow | Trigger | Produces |
|---|---|---|
| `test_and_staging_build.yml` | PR to master/main/dev | Tests + APK/iOS/Web |
| `android_release.yml` | Push to master | Signed AAB + Play Store |
| `webapp_vercel_production.yml` | Push to main/master (webapp) | Vercel deploy |

Branch convention: feature branches prefixed `claude/` for AI-assisted work.

---

## Session Notes

- 2026-04-14: Full codebase audit completed. Flutter→Swift switch evaluated and rejected. CLAUDE.md and AI_CONTEXT.txt updated. 3 new skills added (flutter-model, flutter-test, ios-native). Auth bug identified — login needs end-to-end testing.
