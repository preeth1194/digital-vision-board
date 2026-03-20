# Brand Skill

Apply or verify brand identity and tone-of-voice for the Digital Vision Board (`habitseeding`) app.

## Instructions

### 1. App Identity

| Attribute | Value |
|---|---|
| Display name | **Digital Vision Board** |
| Package / brand | **habitseeding** |
| Flutter package ID | `digital_vision_board` |
| Android & iOS bundle | `com.habitseeding.app` |
| Firebase project | `habitseeding-prod` |

### 2. Design Metaphor

> "Morning Garden" — warm soil, sage growth, honey seeds, morning mist.

Every UI and copy decision must pass this test:
**Does this feel like 6 AM in a quiet garden — warm, grounded, alive, and never loud?**

If something feels anxious, clinical, loud, or corporate → it is wrong.

### 3. Tone of Voice

| Attribute | How it sounds |
|---|---|
| Calm | Never urgent, never pushy, no exclamation marks on serious UI |
| Encouraging | Frame everything as growth, not obligation |
| Warm | Personal and human — not corporate or transactional |
| Honest | Acknowledge struggles without shame |
| Growth-oriented | Planting and tending metaphors, not tracking or monitoring |

### 4. Copy Patterns

| Context | Do | Don't |
|---|---|---|
| Empty state | "Your garden is ready to grow." | "No data found." |
| Habit complete | "Seed planted today." | "Task completed." |
| Streak lost | "Every day is a fresh start." | "Streak broken!" |
| Onboarding CTA | "Let's plant your first habit." | "Get started now!" |
| Error | "Something went wrong — try again." | "Error 500." |
| Loading | "Growing…" | "Loading…" |
| No results | "Nothing planted here yet." | "No results." |

### 5. Feature Naming

| Area | Brand name in UI |
|---|---|
| Habit tracker | Habits / Seeds |
| Daily routine | Morning Ritual / Routine |
| Journal | Journal |
| Vision board | Vision Board |
| AI recommendations | Wizard |
| Points / currency | Seeds (coins icon = `AppColors.seedGold`) |
| Achievements | Milestones |
| Mood tracking | Mood |
| Affirmations | Affirmations |

### 6. Visual Brand Rules

- No neon greens, electric blues, or clinical whites
- No cold dark navy — use `#0F1510` Night Soil for dark backgrounds
- Minimum `radiusCard = 24` on all cards — no sharp corners
- No all-caps headings
- Error states use `colorScheme.error` (muted) — not aggressive red
- Coin/reward icons use `AppColors.seedGold`; reward **text** uses `AppColors.honeyText`

### 7. Illustration & Animation Style

- Use Lottie animations from `assets/animations/` — calm, organic motion
- Prefer botanical / nature imagery (seeds, leaves, soil, mist, sunlight)
- Avoid trophy, achievement-badge, or gamification imagery that implies competition

---

## Task

Review or write the copy / brand elements described in `$ARGUMENTS`.

- Check all text against the tone-of-voice table
- Verify feature names match the brand naming conventions
- Flag anything that feels loud, anxious, or off-brand
- Suggest Morning Garden–aligned alternatives for any violations
