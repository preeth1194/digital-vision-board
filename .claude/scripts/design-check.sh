#!/usr/bin/env bash
# =============================================================================
# design-check.sh — Morning Garden Design System Guard
# =============================================================================
# Runs as a Claude Code PostToolUse hook after every Edit / Write tool call.
# Reads JSON from stdin, extracts the edited file path, and runs design-system
# checks appropriate to the file type.
#
# Exit 0 = clean (or non-applicable file).
# Exit 2 = violations found — Claude Code surfaces the output as a warning.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Parse the file path from the JSON hook payload (stdin)
# ---------------------------------------------------------------------------
PAYLOAD=$(cat)
FILE_PATH=$(echo "$PAYLOAD" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # tool_input is nested under different keys depending on hook type
    ti = data.get('tool_input', data.get('input', {}))
    print(ti.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || true)

# Nothing to check if no file path
[[ -z "$FILE_PATH" ]] && exit 0
# Only check files that exist and are readable
[[ -f "$FILE_PATH" ]] || exit 0

EXT="${FILE_PATH##*.}"
FILENAME=$(basename "$FILE_PATH")
VIOLATIONS=()

# ---------------------------------------------------------------------------
# Helper: record a violation
# ---------------------------------------------------------------------------
violation() {
  VIOLATIONS+=("  ⚠  $1")
}

# ---------------------------------------------------------------------------
# 2. Dart / Flutter checks
# ---------------------------------------------------------------------------
if [[ "$EXT" == "dart" ]]; then

  # Skip the palette definition file itself
  if [[ "$FILENAME" == "app_colors.dart" ]]; then
    exit 0
  fi

  # ── 2a. Raw hex Color literals ──────────────────────────────────────────
  # Raw Color(0xFF...) outside app_colors.dart means a hard-coded colour.
  # Exception: alpha-only values like Color(0x00000000) used for transparent.
  RAW_HEX=$(grep -nE 'Color\(0x[0-9A-Fa-f]{8}\)' "$FILE_PATH" \
    | grep -vE 'Color\(0x00[0-9A-Fa-f]{6}\)' || true)
  if [[ -n "$RAW_HEX" ]]; then
    violation "Raw hex Color() literals found — use AppColors.* tokens instead:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$RAW_HEX"
  fi

  # ── 2b. Bare Material color constants ───────────────────────────────────
  # e.g. Colors.green, Colors.blue, Colors.red (not Colors.transparent/white/black)
  MATERIAL_COLORS=$(grep -nE 'Colors\.(red|green|blue|yellow|orange|purple|pink|teal|cyan|indigo|brown|grey|gray|lime|amber)\b' \
    "$FILE_PATH" || true)
  if [[ -n "$MATERIAL_COLORS" ]]; then
    violation "Bare Material Colors.* used — use AppColors.* or colorScheme.* tokens:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$MATERIAL_COLORS"
  fi

  # ── 2c. seedGold used as text color ─────────────────────────────────────
  # seedGold (#C48B3C) fails WCAG AA — any text must use honeyText instead.
  GOLD_TEXT=$(grep -nE '(color|foreground).*seedGold|seedGold.*(color|foreground)' \
    "$FILE_PATH" || true)
  if [[ -n "$GOLD_TEXT" ]]; then
    violation "AppColors.seedGold used as text/foreground color — use AppColors.honeyText instead:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$GOLD_TEXT"
  fi

  # ── 2d. Hardcoded pixel spacing ──────────────────────────────────────────
  # Catch EdgeInsets / SizedBox / gap / padding with literal numbers not on
  # the 4pt grid or using AppSpacing constants.
  # Pattern: EdgeInsets.all(NUMBER) or .symmetric(h: NUMBER) with raw floats/ints
  # Allow 0 and 2 (half-xs fine for hairlines).
  HARD_SPACING=$(grep -nE \
    'EdgeInsets\.(all|only|symmetric|fromLTRB)\([^)]*[3-9][0-9]\.[0-9]|SizedBox\((width|height): [3-9][0-9]\.' \
    "$FILE_PATH" || true)
  if [[ -n "$HARD_SPACING" ]]; then
    violation "Potentially hardcoded spacing values — use AppSpacing.* constants:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$HARD_SPACING"
  fi

  # ── 2e. Standalone TextStyle with fontFamily ─────────────────────────────
  FONT_FAMILY=$(grep -nE "TextStyle\([^)]*fontFamily\s*:" "$FILE_PATH" || true)
  if [[ -n "$FONT_FAMILY" ]]; then
    violation "TextStyle with explicit fontFamily — use AppTypography.* or Theme.of(context).textTheme.*:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$FONT_FAMILY"
  fi

  # ── 2f. Standalone TextStyle with fontSize/fontWeight (not via theme) ────
  # Warn when creating a raw TextStyle(fontSize: ...) outside of app_typography.dart
  # and main.dart (which is the legitimate global _buildTheme() definition).
  if [[ "$FILENAME" != "app_typography.dart" && "$FILENAME" != "main.dart" ]]; then
    RAW_TEXTSTYLE=$(grep -nE 'TextStyle\([^)]*fontSize\s*:' "$FILE_PATH" \
      | grep -v '//.*TextStyle' || true)
    if [[ -n "$RAW_TEXTSTYLE" ]]; then
      violation "Raw TextStyle with fontSize — use AppTypography.* helpers instead:"
      while IFS= read -r line; do
        VIOLATIONS+=("     $line")
      done <<< "$RAW_TEXTSTYLE"
    fi
  fi

  # ── 2g. State management — no Riverpod / Bloc ───────────────────────────
  RIVERPOD=$(grep -nE "import 'package:flutter_riverpod|import 'package:riverpod|import 'package:flutter_bloc|import 'package:bloc/" \
    "$FILE_PATH" || true)
  if [[ -n "$RIVERPOD" ]]; then
    violation "Riverpod / Bloc import detected — use Provider + SharedPreferences only:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$RIVERPOD"
  fi

  # ── 2h. Landscape orientation ────────────────────────────────────────────
  LANDSCAPE=$(grep -nE 'DeviceOrientation.landscapeLeft|DeviceOrientation.landscapeRight|Orientation.landscape' \
    "$FILE_PATH" || true)
  if [[ -n "$LANDSCAPE" ]]; then
    violation "Landscape orientation detected — app is portrait-only:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$LANDSCAPE"
  fi

  # ── 2i. Missing dark-mode detection in build() ──────────────────────────
  # If the file uses AppColors.skyDecoration or AppColors.cloudDecoration,
  # it must also resolve isDark.
  USES_DECORATION=$(grep -cE 'AppColors\.(skyDecoration|cloudDecoration)' "$FILE_PATH" 2>/dev/null || true)
  USES_IS_DARK=$(grep -cE 'isDark\s*=' "$FILE_PATH" 2>/dev/null || true)
  if [[ "$USES_DECORATION" -gt 0 && "$USES_IS_DARK" -eq 0 ]]; then
    violation "AppColors decoration used but 'isDark' not resolved — add: final isDark = Theme.of(context).brightness == Brightness.dark;"
  fi

fi

# ---------------------------------------------------------------------------
# 3. Webapp (TypeScript / TSX) checks
# ---------------------------------------------------------------------------
if [[ "$EXT" == "tsx" || "$EXT" == "ts" ]]; then

  # Approved Morning Garden hex values for Tailwind arbitrary values
  APPROVED_HEX=(
    "F6F4EF"  # mistBackground
    "EAF2EA"  # skyTopTint
    "4A7A5A"  # sproutGreen
    "3B2D20"  # forestDeep
    "C48B3C"  # seedGold
    "7A5520"  # honeyText
    "DCF0E4"  # sageContainer
    "FDF3E3"  # seedChampagne
    "7B74A8"  # lavenderDew
    "EEEDF8"  # lavenderContainer
    "1F2B22"  # cloudDark
    "2A5040"  # springWater
    "0F1510"  # night soil (dark bg)
    "FFFFFF"  # white
    "000000"  # black
  )

  # Build an alternation pattern of approved hex values (case-insensitive)
  APPROVED_PATTERN=$(IFS='|'; echo "${APPROVED_HEX[*]}" | tr '[:upper:]' '[:lower:]')

  # Find all hex values used in Tailwind arbitrary value syntax: [#XXXXXX] or [#XXX]
  UNAPPROVED_HEX=$(grep -nEo '\[#[0-9A-Fa-f]{3,6}\]' "$FILE_PATH" \
    | grep -ivE "\[(#($APPROVED_PATTERN))\]" || true)
  if [[ -n "$UNAPPROVED_HEX" ]]; then
    violation "Non-Morning-Garden hex colours in Tailwind — use approved palette tokens:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$UNAPPROVED_HEX"
  fi

  # ── 3b. Raw style= hex not in approved list ──────────────────────────────
  INLINE_HEX=$(grep -nE "style=.*color:\s*'#[0-9A-Fa-f]{3,6}'" "$FILE_PATH" || true)
  if [[ -n "$INLINE_HEX" ]]; then
    violation "Inline style hex colour — use Tailwind Morning Garden classes instead:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$INLINE_HEX"
  fi

  # ── 3c. Font family override ─────────────────────────────────────────────
  FONT_IMPORT=$(grep -nE "import.*google.*font|fontFamily.*['\"](?!inter|Inter)" \
    "$FILE_PATH" || true)
  if [[ -n "$FONT_IMPORT" ]]; then
    violation "Non-Inter font or Google Fonts import — Inter is loaded globally, use font-sans:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$FONT_IMPORT"
  fi

  # ── 3d. seedGold as text colour in webapp ────────────────────────────────
  GOLD_WEB=$(grep -nE "text-\[#C48B3C\]|color.*C48B3C" "$FILE_PATH" || true)
  if [[ -n "$GOLD_WEB" ]]; then
    violation "seedGold (#C48B3C) used as text colour — use honeyText (#7A5520) for WCAG AA compliance:"
    while IFS= read -r line; do
      VIOLATIONS+=("     $line")
    done <<< "$GOLD_WEB"
  fi

fi

# ---------------------------------------------------------------------------
# 4. Report
# ---------------------------------------------------------------------------
if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  exit 0
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  🌿 Morning Garden Design Guard — Violations Detected       │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│  File: $FILE_PATH"
echo "│"
for v in "${VIOLATIONS[@]}"; do
  echo "│$v"
done
echo "│"
echo "│  Fix these before committing. See CLAUDE.md → Design System."
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

exit 2
