# Onboarding Redesign — Spec
**Date:** 2026-03-21
**Status:** Approved

---

## Context

The existing onboarding screen collects multiple user details on a single step and uses a mascot-heavy, slide-based design that feels dated. The goal is a minimalistic, modern redesign where **each screen captures one focused piece of information**, paired with a live-preview personalisation moment on the welcome screen. All collected data is saved to `SharedPreferences` immediately and synced to the backend upon sign-in.

---

## Flow — 7 Screens (PageView, horizontal swipe)

| # | Screen | Background | Content |
|---|--------|-----------|---------|
| 1 | Welcome + Name | `AppColors.mistBackground` | Name text field with live preview card |
| 2 | Photo | `AppColors.mistBackground` | Tappable avatar ring → OS picker |
| 3 | Gender + Date of Birth | `AppColors.mistBackground` | Pill list + date field |
| 4 | Height, Weight & Activity | `AppColors.mistBackground` | Stat boxes + unit toggle + activity chips |
| 5 | Feature Highlights | Dark `#0f0f13` | Numbered feature list |
| 6 | Terms & Conditions | `AppColors.sproutGreen` | Scrollable T&C + checkbox |
| 7 | Sign-in | `AppColors.mistBackground` | Existing `AuthGatewayScreen` content (unchanged) |

**Navigation:** `PageController` with horizontal `PageView`. Progress shown as a thin animated bar at the top (not dots). Back swipe navigates to previous screen. Forward navigation only via "Continue" button (except Screen 7 which closes onboarding).

---

## Screen-by-Screen Spec

### Screen 1 — Welcome + Name
- **Title:** "What should we call you?"
- **Input:** Underline-style `TextField` (no border box), auto-focus on mount
- **Live preview card:** Sage green card below input showing `"Hey [Name] 👋 / Welcome to Habit Seeding"` — updates on every keystroke
- **Validation:** Name must be non-empty to enable Continue
- **Storage:** `DvAuthService.setProfileInfo(displayName: name)` → `dv_user_display_name_v1`

### Screen 2 — Photo
- **Title:** "Add a photo, [Name]." (uses name from screen 1)
- **UI:** Large circle with `+` icon only. Tap invokes `ImagePicker` (no app-level Camera/Gallery buttons — OS sheet handles the choice)
- **On selection:** Show cropped preview inside the circle
- **Skip:** Allowed — saves `null`, photo can be set later in Profile settings
- **Storage:** `DvAuthService.setProfilePicPath(path)` → `dv_user_profile_pic_v1`

### Screen 3 — Gender + Date of Birth
- **Title:** "Tell us a bit more."
- **Gender:** Vertical pill list — Male, Female, Non-binary, Prefer not to say. Single select, tapping selects (dark fill). Default: none selected.
- **DOB:** Tapping `field-value` opens `showDatePicker`. Display formatted as `dd MMMM yyyy`.
- **Both fields optional** — user can continue without selecting
- **Storage:** `DvAuthService.setGender(gender)`, `DvAuthService.setDateOfBirth(isoString)`

### Screen 4 — Height, Weight & Activity
- **Title:** "Body & Activity."
- **Height/Weight:** Two stat boxes side by side. Tap opens an inline scroll wheel or `showModalBottomSheet` with a `CupertinoPicker`.
- **Unit toggle:** cm/kg ↔ ft/lbs. Switching converts displayed values in-place. Stored always as cm/kg internally.
- **Activity Level:** 4 single-select chips (vertical list):
  - 🪑 Sedentary
  - 🚶 Lightly Active
  - 🏃 Moderately Active *(default)*
  - 🏋️ Very Active
- **All fields optional** — "Skip" ghost button available
- **Storage:** `DvAuthService.setHeightCm()`, `DvAuthService.setWeightKg()`, `DvAuthService.setActivityLevel()`

### Screen 5 — Feature Highlights
- **Background:** Dark `#0f0f13`
- **Title:** "Built for real growth."
- **Content:** Numbered list (01–04) on dark background, amber `#C48B3C` numbers:
  1. Habit Tracking — Streaks, badges & reminders
  2. Vision Board — Tap-to-explore goal boards
  3. Affirmations — Daily mindset rituals
  4. Progress Insights — Charts & growth analytics
- **CTA:** "Let's go" amber button

### Screen 6 — Terms & Conditions
- **Background:** `AppColors.sproutGreen`
- **Title:** "One last thing."
- **Scrollable T&C text box** (white semi-transparent background)
- **Links:** "View full Terms" → `TermsAndConditionsScreen`, "Privacy Policy" → `PrivacyPolicyScreen` (existing screens, open as modal)
- **Checkbox:** White box with green tick — must be checked to enable "Accept & Continue"
- **On mount:** read `isLegalConsentAccepted()` — if already `true`, pre-check the checkbox so back-navigation from Screen 7 doesn't show a stale unchecked state
- **On accept:** calls `DvAuthService.markLegalConsentAccepted()`, advances to Screen 7
- **Storage:** `legal_consent_accepted_v1`
- **Note:** `markLegalConsentAccepted()` and `isLegalConsentAccepted()` are to be moved from `legal_consent_screen.dart` into `DvAuthService` as static methods (eliminates cross-file import dependency)

### Screen 7 — Sign-in
- Renders existing `AuthGatewayScreen` content inline (Google Sign-in + Guest)
- On success: calls `DvAuthService.markOnboardingCompleted()`, navigates to `DashboardScreen` (replace)
- Guest mode: same flow, 10-day token
- **Note:** `markOnboardingCompleted()` and `isOnboardingCompleted()` are to be moved from `onboarding_screen.dart` into `DvAuthService` as static methods

---

## Data & Storage

All fields saved to `SharedPreferences` via `DvAuthService` **immediately** on each screen's "Continue". On sign-in (Screen 7), all prefs are synced to the backend automatically by the existing `DvAuthService.exchangeFirebaseIdTokenForDvToken()` flow.

| Field | Key | Type |
|-------|-----|------|
| Display name | `dv_user_display_name_v1` | String |
| Profile photo path | `dv_user_profile_pic_v1` | String? |
| Gender | `dv_gender_v1` | String |
| Date of birth | `dv_user_dob_v1` | ISO String |
| Height | `dv_user_height_cm_v1` | String (double) |
| Weight | `dv_user_weight_kg_v1` | String (double) |
| Activity level | `dv_user_activity_level_v1` | String |
| Legal consent | `legal_consent_accepted_v1` | bool |
| Onboarding done | `onboarding_completed_v1` | bool |

---

## Design System

Uses existing Morning Garden palette from `lib/utils/app_colors.dart`:
- Backgrounds: `AppColors.mistBackground` (`#F6F4EF`, cream), `#0f0f13` (dark), `AppColors.sproutGreen` (`#4A7A5A`, sage)
- Primary action: `sproutGreen` `#4A7A5A`
- Accent: `seedGold` `#C48B3C`
- Text: `forestDeep` `#3B2D20`
- Fonts: existing `AppTypography` — bold 800 weight for titles

Progress bar: thin 2px line, fills proportionally per screen using `(currentIndex + 1) / 7` (≈14.3% per step, reaches 100% on Screen 7).

---

## Files to Modify / Create

| Action | File |
|--------|------|
| **Replace** | `lib/screens/onboarding/onboarding_screen.dart` |
| **Replace** | `lib/screens/onboarding/widgets/onboarding_profile_step.dart` |
| **Create** | `lib/screens/onboarding/steps/step_welcome.dart` |
| **Create** | `lib/screens/onboarding/steps/step_photo.dart` |
| **Create** | `lib/screens/onboarding/steps/step_gender_dob.dart` |
| **Create** | `lib/screens/onboarding/steps/step_body_activity.dart` |
| **Create** | `lib/screens/onboarding/steps/step_features.dart` |
| **Create** | `lib/screens/onboarding/steps/step_terms.dart` |
| **Reuse** | `lib/screens/auth/auth_gateway_screen.dart` (Screen 7, no changes) |
| **Reuse** | `lib/screens/legal_consent_screen.dart` → inline in step_terms |
| **Reuse** | `lib/services/dv_auth_service.dart` (all storage calls) |
| **Reuse** | `lib/utils/app_colors.dart` |

---

## Verification

1. Fresh install → `OnboardingScreen` appears (not Dashboard)
2. Screen 1: typing name updates live preview card in real time
3. Screen 2: tapping avatar opens OS picker (Camera / Gallery); selecting photo shows preview; Skip advances without error
4. Screen 3: selecting gender highlights pill; tapping DOB field opens date picker
5. Screen 4: stat boxes open pickers; unit toggle converts values; activity chip single-selects; Skip allowed
6. Screen 5: dark screen renders, "Let's go" advances
7. Screen 6: T&C checkbox enables Accept button; tapping Terms/Privacy links opens existing screens modally
8. Screen 7: Google sign-in and Guest both navigate to Dashboard and set `onboarding_completed_v1 = true`
9. Re-launch after completion → Dashboard shown (not onboarding)
10. Data persistence — verify each field individually:
    - Name entered as "Alice" on Screen 1 → Profile settings shows display name "Alice"
    - Photo selected on Screen 2 → Profile avatar shows selected image
    - Gender "Female" selected on Screen 3 → Profile shows "Female"
    - DOB set to "10 March 1990" → Profile shows correct date
    - Height 170 cm / Weight 60 kg on Screen 4 → Profile shows correct values
    - Activity "Very Active" selected → `dv_user_activity_level_v1` reads "very_active" in SharedPreferences
11. Unit toggle: set height to 180 cm, toggle to ft/lbs → displays "5 ft 11 in"; stored value remains 180 in `dv_user_height_cm_v1`
