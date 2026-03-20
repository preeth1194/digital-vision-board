# Design Review Skill

Audit Flutter, webapp, or backend code against the Morning Garden design system — colours, spacing, typography, architecture, and brand consistency.

## Instructions

Run through every checklist section relevant to the file(s) being reviewed.

---

### Checklist A — Morning Garden Colours (Flutter)

- [ ] No raw `Color(0xFF...)` hex literals (except in `app_colors.dart`)
- [ ] No bare `Colors.green`, `Colors.blue`, etc. — use `AppColors.*` or `colorScheme.*`
- [ ] `AppColors.seedGold` is NOT used as a text/foreground colour → must be `AppColors.honeyText`
- [ ] Page backgrounds use `AppColors.skyDecoration(isDark: isDark)`
- [ ] Card surfaces use `AppColors.cloudDecoration(isDark: isDark)`
- [ ] `isDark` is resolved via `Theme.of(context).brightness == Brightness.dark` wherever decorations are used
- [ ] Bottom nav uses `AppColors.forestDeep`
- [ ] Active nav icons use `AppColors.sproutGreen`
- [ ] Mood / journal / affirmation accents use `AppColors.lavenderDew`
- [ ] Chip / tag backgrounds use `AppColors.sageContainer`
- [ ] Error states use `colorScheme.error`

### Checklist B — Spacing (Flutter)

- [ ] All `EdgeInsets`, `SizedBox`, `gap`, and `Padding` use `AppSpacing.*` constants
- [ ] No hardcoded pixel values outside `app_spacing.dart`
- [ ] Touch targets are at least 48×48 logical pixels
- [ ] Border radii use `AppSpacing.radius*` constants

### Checklist C — Typography (Flutter)

- [ ] All text styles use `AppTypography.*` or `Theme.of(context).textTheme.*`
- [ ] No standalone `TextStyle(fontFamily: ...)` in widget files
- [ ] No standalone `TextStyle(fontSize: ...)` outside `app_typography.dart` / `main.dart`
- [ ] `GoogleFonts.inter(...)` is not called directly in widget files — theme handles the font

### Checklist D — Flutter Architecture

- [ ] No Riverpod, Bloc, GetX, or MobX imports
- [ ] State management is Provider + SharedPreferences
- [ ] No landscape orientation code (`DeviceOrientation.landscape*`, `Orientation.landscape`)
- [ ] Firebase calls are wrapped in `try/catch` (non-fatal)
- [ ] Background/best-effort async uses `unawaited(...catchError((_) {}))` — not `await`
- [ ] `const` constructors used wherever possible

### Checklist E — Morning Garden Colours (Webapp TSX/TS)

- [ ] Tailwind arbitrary hex values `[#XXXXXX]` only use approved Morning Garden palette
- [ ] No inline `style=` hex colours — use Tailwind classes
- [ ] `text-[#C48B3C]` (seedGold) not used for text — must be `text-[#7A5520]` (honeyText)
- [ ] No Google Fonts imports in component files — Inter loaded globally via `layout.tsx`

### Checklist F — Brand & Tone

- [ ] Empty states use warm, garden-metaphor copy (not "No data found")
- [ ] Error messages are calm and actionable (not raw error codes)
- [ ] Feature names match brand naming (Seeds not Points, Wizard not AI, etc.)
- [ ] No all-caps headings
- [ ] No aggressive gamification language (streak broken, failed, etc.)

### Checklist G — Backend / AI

- [ ] No hardcoded API keys — all via `process.env.*`
- [ ] Gemini prompts sanitise user input and use system-instruction scoping
- [ ] AI responses validated before storage
- [ ] Wizard recommendations are cached — no redundant Gemini calls
- [ ] Pexels photos are attributed per ToS

---

## How to Report

For each violation found, report in this format:

```
[SEVERITY] File: path/to/file.dart — Line N
Rule: Which checklist item
Issue: What is wrong
Fix: What to change it to
```

Severity levels:
- **BLOCKER** — accessibility (WCAG AA) or brand identity violation
- **MAJOR** — design system token violation (raw hex, hardcoded spacing)
- **MINOR** — style inconsistency that won't break anything but drifts from the system

---

## Task

Review the file(s) or feature described in `$ARGUMENTS` against all applicable checklists above.

- Run through every relevant checklist section
- Report all violations with severity, file, line, and suggested fix
- Summarise: total blockers / majors / minors found
