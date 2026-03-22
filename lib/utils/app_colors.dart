import 'package:flutter/material.dart';

/// habitseeding — "Morning Garden" Calm Palette.
///
/// Design principle: every color should feel like 6 AM in a quiet garden —
/// warm, grounded, alive, but never loud. The palette earns attention through
/// warmth rather than saturation.
///
/// Metaphor Mapping:
/// - Mist & Sky     -> Backgrounds  (warm cream morning, breathable)
/// - Clouds         -> Cards/Widgets (soft, floating surfaces)
/// - Soil & Seed    -> Navigation + Anchors (earthy, grounded foundation)
/// - Sage Leaf      -> Primary Actions (calm growth, not neon)
/// - Honey          -> Rewards & Coins (warm amber, organic gold)
/// - Lavender Dew   -> Mood / Journal / Affirmations (calm mind)
///
/// WCAG AA contrast (4.5:1+) verified for all text-on-background pairings.
///
/// **Logo alignment (medium):** Reference swatches below are sampled from
/// `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.
/// UI tokens (`mistBackground`, `skyTopTint`, `sproutGreen`) are derived — calmer
/// than the icon — so the app stays “Morning Garden” quiet while echoing the
/// seed/sprout/yellow field brand.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // ── 0. Brand reference (app icon — not always used raw in UI)
  // ═══════════════════════════════════════════════════════════════

  /// Solid icon field / sunflower yellow (background of the app icon).
  static const Color brandLogoFieldYellow = Color(0xFFFEDE59);

  /// Typical sprout leaf midtone from the icon (too vivid for primary buttons).
  static const Color brandSproutGreenVivid = Color(0xFF71A905);

  /// Deep shadow green sampled from sprout shading in the icon.
  static const Color brandSproutShadowGreen = Color(0xFF275100);

  /// Seed body (warm brown) and shadow — useful for illustration / accents.
  static const Color brandSeedBrown = Color(0xFF7A300B);
  static const Color brandSeedBrownDeep = Color(0xFF954C0B);

  // ═══════════════════════════════════════════════════════════════
  // ── 1. The Core Morning Garden Foundation ──
  // ═══════════════════════════════════════════════════════════════

  // ── Mist & Sky (Warm Cream Atmospheres) ──
  // mistBackground: ~88% prior cream + ~12% brandLogoFieldYellow — buttery mist.
  //   Contrast vs forestDeep: ~11.7:1 ✅
  static const Color mistBackground = Color(0xFFF6F1DD);

  // skyTopTint: prior sage haze + ~14% brandLogoFieldYellow — warmer sky band.
  static const Color skyTopTint = Color(0xFFECEFD5);

  // ── Soil & Seed (Earthy Anchors — Navigation, Headers) ──
  // forestDeep: warm soil brown. Replaces cold dark green.
  //   Contrast on white: ~13.7:1 ✅  |  Contrast on mistBackground: ~12.8:1 ✅
  // Named forestDeep for backward compatibility; semantically this is now
  // "soilDeep" — warm, earthy, grounding. Feels like the earth a seed rests in.
  static const Color forestDeep = Color(0xFF3B2D20);

  // ── Sage Leaf (Primary Actions — logo-aligned forest green, WCAG-safe) ──
  // sproutGreen: hue nudged toward brandSproutGreenVivid, darkened for contrast.
  //   Contrast on white: ~6.0:1 ✅  |  on mistBackground: ~5.3:1 ✅
  // Use as: filled button bg, active icon, progress ring, toggle on-state.
  // Do NOT use as body text color — use onPrimaryContainer instead.
  static const Color sproutGreen = Color(0xFF3F6E38);

  // sageDark: for pressed/hover states of primary actions.
  static const Color springWater = Color(0xFF2A4A26);

  // sageContainer: pale fill harmonized with new primary (still calm, not lime).
  static const Color sageContainer = Color(0xFFD6EBD4);

  // ── Honey Seed (Rewards, Coins, Achievements) ──
  // seedGold: warm honey amber. Replaces shiny #D4AF37 which felt glitzy.
  //   Use as: icon fill, badge bg, illustration tint — NOT as text on white.
  //   Contrast on white: ~2.9:1 ❌ — use honeyText (#7A5520) for any text.
  static const Color seedGold = Color(0xFFC48B3C);

  // honeyContainer: pale honey cream for badge/reward container backgrounds.
  static const Color seedChampagne = Color(0xFFFDF3E3);

  // honeyText: dark amber for text that carries gold/reward meaning.
  //   Contrast on white: ~6.7:1 ✅  |  Contrast on mistBackground: ~6.3:1 ✅
  static const Color honeyText = Color(0xFF7A5520);

  // ── Lavender Dew (Calm Accent — Mood, Journal, Affirmations) ──
  // A soft dusty lavender for the app's quietest, most introspective features.
  //   lavenderDew as text on white: ~4.6:1 ✅
  static const Color lavenderDew = Color(0xFF7B74A8);
  static const Color lavenderContainer = Color(0xFFEEEDF8);

  // ── Habit Heatmap ──
  // Deep rose-brown used for missed habit cells in the calendar heatmap.
  static const Color missedHabitCell = Color(0xFF5c2020);

  // ── Cloud Surfaces ──
  static const Color cloudWhite = Color(0xFFFFFFFF);
  // cloudDark: warm grove dark — replaces cold navy.
  static const Color cloudDark = Color(0xFF1F2B22);

  // ── Primitive aliases (Material `Colors.*` lives only here) ──
  static const Color pureBlack = Color(0xFF000000);
  /// Material black87 — body text on light scrims.
  static const Color black87 = Color(0xDD000000);
  static const Color black38 = Color(0x61000000);
  static const Color white70 = Color(0xB3FFFFFF);

  // ── Legacy palette (kept for backward-compat references) ──
  static const Color darkest = Color(0xFF2C1810);
  static const Color dark = Color(0xFF5C3D2E);
  static const Color medium = Color(0xFF8B7355);
  static const Color light = Color(0xFFC9A96E);
  static const Color lightest = Color(0xFFE8D5B8);
  static const Color mintGreen = Color(0xFFA8D5BA);
  static const Color sageGreen = Color(0xFF8FBC8F);
  static const Color mossGreen = Color(0xFF4A7C59);
  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color gold = Color(0xFFD4A843);
  static const Color soilLight = Color(0xFF5C3D2E);
  static const Color soilDark = Color(0xFF2A1B12);
  static const Color soilMedium = Color(0xFF7B5B4A);
  static const Color seedLight = Color(0xFFC9A96E);
  static const Color seedDark = Color(0xFFD4B896);
  static const Color seedDeep = Color(0xFF8B6B3E);
  static const Color waterLight = Color(0xFF4FA4D4);
  static const Color waterDark = Color(0xFF6CB4D9);
  static const Color skyGradientTopLight = Color(0xFFE0F2F1);
  static const Color skyGradientBottomLight = Color(0xFFF4F7F5);
  static const Color skyGradientTopDark = Color(0xFF0D1B2A);
  static const Color skyGradientBottomDark = Color(0xFF1B263B);
  static const Color cloudLight = Color(0xFFFFFFFF);
  static const Color cloudBorderDark = Color(0xFF2A3A4A);

  // ── Domain accent (not in ColorScheme) ──
  static const Color completedOrange = Color(0xFFE8802A);

  // ── Goal canvas (default board background) ──
  static const Color goalCanvasDefaultBackground = Color(0xFFF8F9F4);

  // ── Water dashboard (paired light / dark accents) ──
  static const Color waterAccentLight = Color(0xFF039BE5);
  static const Color waterAccentDark = Color(0xFF29B6F6);
  static const Color waterDeepLight = Color(0xFF01579B);
  static const Color waterDeepDark = Color(0xFF0288D1);

  // ── Calorie log / macro field accents ──
  static const Color calorieLogIconTint = Color(0xFFFF7043);
  static const Color calorieMacroProtein = Color(0xFF42A5F5);
  static const Color calorieMacroCarbs = Color(0xFFFF7043);
  static const Color calorieMacroFat = Color(0xFFEF5350);
  static const Color calorieMacroFiber = Color(0xFF66BB6A);

  // ── Text editor color swatches (Material-aligned basics) ──
  static const Color editorSwatchRed = Color(0xFFF44336);
  static const Color editorSwatchBlue = Color(0xFF2196F3);
  static const Color editorSwatchGreen = Color(0xFF4CAF50);
  static const Color editorSwatchOrange = Color(0xFFFF9800);
  static const Color editorSwatchPurple = Color(0xFF9C27B0);
  static const Color editorSwatchPink = Color(0xFFE91E63);
  static const Color editorSwatchTeal = Color(0xFF009688);
  static const Color editorSwatchAmber = Color(0xFFFFC107);

  /// Trophy / achievement accent (Material amber family).
  static const Color iconTrophyAmber = editorSwatchAmber;

  // ── ColorScheme source values (used only inside lightScheme/darkScheme) ──
  // _backgroundDark: deep organic night soil — warm dark, not cold navy.
  static const Color _backgroundDark = Color(0xFF0F1510);
  static const Color _errorLight = Color(0xFFBA1A1A);
  static const Color _errorDark = Color(0xFFFFB4AB);
  static const Color _onErrorLight = Color(0xFFFFFFFF);
  static const Color _onErrorDark = Color(0xFF690005);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 2: Gold / Amber Gradient (coins, badges, dashboard) ──
  // ═══════════════════════════════════════════════════════════════
  static const Color goldLight = Color(0xFFFFD54F);
  static const Color goldDark = Color(0xFFF9A825);
  static const Color amberBorder = Color(0xFFFF8F00);
  static const Color coinGoldHighlight = Color(0xFFFFE082);
  static const Color coinGold = Color(0xFFFFD700);
  static const Color coinGoldShadow = Color(0xFFFFA000);

  // ═══════════════════════════════════════════════════════════════
  // ── Unified Color Spectrum ──
  // Shared across habit categories, journal covers, habit form
  // presets, and badge accents. Organized by hue.
  //
  // Per-hue levels:
  //   pastelLight / pastelDark   → category circle backgrounds
  //   accentLight / accentDark   → category icon tints
  //   vivid / vividDark          → habit form color picker
  //   cover (int)                → journal book covers
  // ═══════════════════════════════════════════════════════════════

  // ── Red / Coral ──
  static const Color habitRedLight = Color(0xFFEF4444);
  static const Color habitRedDark = Color(0xFFB91C1C);
  static const int coverCoral = 0xFFE57373;

  // ── Orange ──
  static const Color habitOrangeLight = Color(0xFFF97316);
  static const Color habitOrangeDark = Color(0xFFC2410C);
  static const int coverOrange = 0xFFFFB74D;
  static const Color categoryMindfulnessBgLight = Color(0xFFF5C6AA);
  static const Color categoryMindfulnessBgDark = Color(0xFF8D5B3A);
  static const Color categoryMindfulnessIconLight = Color(0xFF5E3820);
  static const Color categoryMindfulnessIconDark = Color(0xFFFDD8B8);

  // ── Yellow ──
  static const Color habitYellowLight = Color(0xFFEAB308);
  static const Color habitYellowDark = Color(0xFFA16207);
  static const int coverYellow = 0xFFFFF176;
  static const Color categoryFinanceBgLight = Color(0xFFFFF9C4);
  static const Color categoryFinanceBgDark = Color(0xFF8A7A30);
  static const Color categoryFinanceIconLight = Color(0xFF5A4A10);
  static const Color categoryFinanceIconDark = Color(0xFFFFF5A0);

  // ── Green ──
  static const Color habitGreenLight = Color(0xFF22C55E);
  static const Color habitGreenDark = Color(0xFF15803D);
  static const int coverLightGreen = 0xFFAED581;
  static const Color categoryHealthBgLight = Color(0xFFA8D5BA);
  static const Color categoryHealthBgDark = Color(0xFF2E7D5B);
  static const Color categoryHealthIconLight = Color(0xFF2E5E4A);
  static const Color categoryHealthIconDark = Color(0xFFB8E6C8);
  static const Color categoryFitnessBgLight = Color(0xFFB8E6C8);
  static const Color categoryFitnessBgDark = Color(0xFF33805E);
  static const Color categoryFitnessIconLight = Color(0xFF2A5E40);
  static const Color categoryFitnessIconDark = Color(0xFFC0F0D0);
  static const Color categoryDefaultBgLight = Color(0xFFD5E8D4);
  static const Color categoryDefaultBgDark = Color(0xFF4A635A);
  static const Color categoryDefaultIconLight = Color(0xFF3A5040);
  static const Color categoryDefaultIconDark = Color(0xFFD0E8D0);

  // ── Teal ──
  static const int coverTeal = 0xFF4DB6AC;

  // ── Blue ──
  static const Color habitBlueLight = Color(0xFF3B82F6);
  static const Color habitBlueDark = Color(0xFF1D4ED8);
  static const int coverBlue = 0xFF64B5F6;
  static const Color categoryProductivityBgLight = Color(0xFFBBDEFB);
  static const Color categoryProductivityBgDark = Color(0xFF3565A0);
  static const Color categoryProductivityIconLight = Color(0xFF1A3A6A);
  static const Color categoryProductivityIconDark = Color(0xFFCCE4FF);

  // ── Indigo ──
  static const Color habitIndigoLight = Color(0xFF6366F1);
  static const Color habitIndigoDark = Color(0xFF4338CA);

  // ── Violet / Purple ──
  static const Color habitVioletLight = Color(0xFF8B5CF6);
  static const Color habitVioletDark = Color(0xFF6D28D9);
  static const int coverPurple = 0xFF9575CD;
  static const Color categoryLearningBgLight = Color(0xFFD1C4E9);
  static const Color categoryLearningBgDark = Color(0xFF5E4B8A);
  static const Color categoryLearningIconLight = Color(0xFF3A2C60);
  static const Color categoryLearningIconDark = Color(0xFFE0D4F0);
  static const Color categoryCreativityBgLight = Color(0xFFE1BEE7);
  static const Color categoryCreativityBgDark = Color(0xFF7B4A8A);
  static const Color categoryCreativityIconLight = Color(0xFF5A2A6A);
  static const Color categoryCreativityIconDark = Color(0xFFF0D0F8);

  // ── Pink ──
  static const int coverPink = 0xFFF06292;
  static const Color categoryRelationshipsBgLight = Color(0xFFF8BBD0);
  static const Color categoryRelationshipsBgDark = Color(0xFF8A4466);
  static const Color categoryRelationshipsIconLight = Color(0xFF6A2040);
  static const Color categoryRelationshipsIconDark = Color(0xFFFDD0E0);

  // ── Brown / Grey (neutral covers) ──
  static const int coverBrown = 0xFFA1887F;
  static const int coverBlueGrey = 0xFF90A4AE;

  // ── Hue stops (habit form color-wheel) ──
  static const Color hueRed = Color(0xFFFF0000);
  static const Color hueYellow = Color(0xFFFFFF00);
  static const Color hueGreen = Color(0xFF00FF00);
  static const Color hueCyan = Color(0xFF00FFFF);
  static const Color hueBlue = Color(0xFF0000FF);
  static const Color hueMagenta = Color(0xFFFF00FF);

  // ── Bookshelf wood grain (journal bookshelf shelf-line gradient) ──
  /// Mid-tone warm oak — shelf gradient stop 1 (lightest).
  static const Color shelfWoodLight = Color(0xFFC4956A);
  /// Warm walnut — shelf gradient stop 2 (mid).
  static const Color shelfWoodMid = Color(0xFFA0724A);
  // Stop 3 (darkest) reuses AppColors.honeyText (0xFF7A5520).

  // ── Special journal cover styles ──
  static const int coverFijiPrimary = 0xFF4A7DFF;
  static const int coverFijiSecondary = 0xFF2E5BDB;
  static const int coverMidnightPrimary = 0xFF5C6BC0;
  static const int coverMidnightSecondary = 0xFF3949AB;
  static const int coverCustomGrey = 0xFF78909C;

  /// Returns the background color for a habit category's icon circle.
  static Color categoryBgColor(String? category, bool isDark) {
    switch (category) {
      case 'Health':
        return isDark ? categoryHealthBgDark : categoryHealthBgLight;
      case 'Fitness':
        return isDark ? categoryFitnessBgDark : categoryFitnessBgLight;
      case 'Mindfulness':
        return isDark ? categoryMindfulnessBgDark : categoryMindfulnessBgLight;
      case 'Productivity':
        return isDark
            ? categoryProductivityBgDark
            : categoryProductivityBgLight;
      case 'Learning':
        return isDark ? categoryLearningBgDark : categoryLearningBgLight;
      case 'Relationships':
        return isDark
            ? categoryRelationshipsBgDark
            : categoryRelationshipsBgLight;
      case 'Finance':
        return isDark ? categoryFinanceBgDark : categoryFinanceBgLight;
      case 'Creativity':
        return isDark ? categoryCreativityBgDark : categoryCreativityBgLight;
      default:
        return isDark ? categoryDefaultBgDark : categoryDefaultBgLight;
    }
  }

  /// Returns the icon color inside a habit category's circle.
  static Color categoryIconColor(String? category, bool isDark) {
    switch (category) {
      case 'Health':
        return isDark ? categoryHealthIconDark : categoryHealthIconLight;
      case 'Fitness':
        return isDark ? categoryFitnessIconDark : categoryFitnessIconLight;
      case 'Mindfulness':
        return isDark
            ? categoryMindfulnessIconDark
            : categoryMindfulnessIconLight;
      case 'Productivity':
        return isDark
            ? categoryProductivityIconDark
            : categoryProductivityIconLight;
      case 'Learning':
        return isDark ? categoryLearningIconDark : categoryLearningIconLight;
      case 'Relationships':
        return isDark
            ? categoryRelationshipsIconDark
            : categoryRelationshipsIconLight;
      case 'Finance':
        return isDark ? categoryFinanceIconDark : categoryFinanceIconLight;
      case 'Creativity':
        return isDark
            ? categoryCreativityIconDark
            : categoryCreativityIconLight;
      default:
        return isDark ? categoryDefaultIconDark : categoryDefaultIconLight;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ── Badge Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color badgeGreen = Color(0xFF4CAF50);
  static const Color badgeOrangeRed = Color(0xFFFF7043);
  static const Color badgePurple = Color(0xFF7C4DFF);
  static const Color badgeAmber = Color(0xFFFFB300);
  static const Color badgeYellow = Color(0xFFFDD835);
  static const Color badgeTeal = Color(0xFF26A69A);
  static const Color badgeOrchid = Color(0xFFAB47BC);
  static const Color badgeSkyBlue = Color(0xFF42A5F5);
  static const Color badgePink = Color(0xFFEC407A);

  // ═══════════════════════════════════════════════════════════════
  // ── Mood Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color moodAwful = Color(0xFFE57373);
  static const Color moodBad = Color(0xFFFFB74D);
  static const Color moodNeutral = Color(0xFFFFD54F);
  static const Color moodGood = Color(0xFF81C784);
  static const Color moodGreat = Color(0xFF4DB6AC);

  // ═══════════════════════════════════════════════════════════════
  // ── Board / Tile Pastel Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color pastelGreen = Color(0xFFECFDF5);
  static const Color pastelBlue = Color(0xFFE0F2FE);
  static const Color pastelPurple = Color(0xFFF3E8FF);
  static const Color pastelOrange = Color(0xFFFFF7ED);
  static const Color pastelPink = Color(0xFFFFF1F2);
  static const Color pastelIndigo = Color(0xFFEEF2FF);

  // ═══════════════════════════════════════════════════════════════
  // ── Editor Background Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color editorBgMist = Color(0xFFF7F7FA);
  static const Color editorBgDarkNavy = Color(0xFF111827);
  static const Color editorBgCyan = Color(0xFF0EA5E9);
  static const Color editorBgEmerald = Color(0xFF10B981);
  static const Color editorBgAmber = Color(0xFFF59E0B);
  static const Color editorBgCrimson = Color(0xFFEF4444);
  static const Color editorBgViolet = Color(0xFF8B5CF6);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 10: Sun Times / Sky Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color skyDarkBlue = Color(0xFF2C3E50);
  static const Color sunriseOrange = Color(0xFFE67E22);
  static const Color skyMutedBlue = Color(0xFF5D6D7E);
  static const Color skyLightBlue = Color(0xFF87CEEB);
  static const Color skyPeach = Color(0xFFFDB462);
  static const Color skyPaleGreen = Color(0xFFE8F0E0);
  static const Color skyAfternoonOrange = Color(0xFFFFB347);
  static const Color skyDuskyBlue = Color(0xFF34495E);
  static const Color nightDeepNavy = Color(0xFF0D1B2A);
  static const Color nightDarkBlue = Color(0xFF1B263B);
  static const Color nightSlate = Color(0xFF415A77);

  static const Color moonGlow = Color(0xFFE0E0E0);
  static const Color moonBody = Color(0xFFF0F0F0);
  static const Color moonCrater = Color(0xFFD0D0D0);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 11: Resize Handle / Manipulable Node ──
  // ═══════════════════════════════════════════════════════════════
  static const Color handleBorderGrey = Color(0xFFD1D5DB);
  static const Color handleActivePurple = Color(0xFF7C3AED);
  static const Color shadowMedium = Color(0x66000000);
  static const Color shadowLight = Color(0x33000000);
  static const Color shadowSubtle = Color(0x26000000);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 12: Circular Timer Defaults ──
  // ═══════════════════════════════════════════════════════════════
  static const Color timerTrackGrey = Color(0xFFE0E0E0);

  // ═══════════════════════════════════════════════════════════════
  // ── Confetti Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color confettiPink = Color(0xFFE91E63);
  static const Color confettiOrange = Color(0xFFFF9800);

  // ═══════════════════════════════════════════════════════════════
  // ── Earn Badges Screen Gradients ──
  // ═══════════════════════════════════════════════════════════════
  static const Color badgeBgDarkStart = Color(0xFF1E293B);
  static const Color badgeBgDarkEnd = Color(0xFF0F172A);
  static const Color badgeBgLightStart = Color(0xFFFFF8E1);
  static const Color badgeBgLightEnd = Color(0xFFFFF3E0);

  // ── ColorScheme-internal (private — only used inside lightScheme/darkScheme) ──
  // Tertiary: warm honey amber family (rewards, coins, badges)
  static const Color _tertiaryGoldDark = Color(0xFFD4A46A);
  static const Color _tertiaryOnDark = Color(0xFF3E2200);
  static const Color _tertiaryContainerDark = Color(0xFF5C3800);
  static const Color _tertiaryContainerLight = Color(0xFFFDF3E3);
  // Error
  static const Color _errorContainerDark = Color(0xFF93000A);
  static const Color _errorContainerLight = Color(0xFFFFDAD6);
  static const Color _onErrorContainerLight = Color(0xFF410002);
  // Dark surface containers: warm soil tints instead of cold forest
  static const Color _surfaceContainerSoilHigh = Color(0xFF1E2B1E);
  static const Color _surfaceContainerSoil = Color(0xFF182018);
  static const Color _surfaceContainerSoilLow = Color(0xFF121810);

  /// Light theme ColorScheme — "Morning Garden" (logo-tinted mist + sprout primary).
  ///
  /// primary     = sprout leaf — growth actions (aligned to app icon, WCAG AA)
  /// secondary   = warm soil — grounded anchor
  /// tertiary    = honey amber — rewards and achievement (icon/fill use only)
  /// surface     = butter-warm mist — breathable page background
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary: logo-aligned forest green — WCAG AA on white (~6:1)
    primary: sproutGreen,
    onPrimary: cloudWhite,
    primaryContainer: sageContainer,
    onPrimaryContainer: forestDeep,
    // Secondary: warm soil — earthy, grounding
    secondary: forestDeep,
    onSecondary: cloudWhite,
    secondaryContainer: Color(0xFFEEE8DC),
    onSecondaryContainer: forestDeep,
    // Tertiary: honey amber — coins, badges, rewards (fill/icon only, not text)
    tertiary: seedGold,
    onTertiary: cloudWhite,
    tertiaryContainer: _tertiaryContainerLight,
    onTertiaryContainer: _tertiaryOnDark,
    // Error
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    // Surface: warm cream — the calming page background
    surface: mistBackground,
    onSurface: forestDeep,
    onSurfaceVariant: Color(0xFF5C4E40),
    // Outline: warm neutral, not cool grey
    outline: Color(0xFF9C8878),
    outlineVariant: Color(0xFFD6CEC5),
    // Shadow & Scrim
    shadow: forestDeep,
    scrim: forestDeep,
    // Inverse
    inverseSurface: forestDeep,
    onInverseSurface: Color(0xFFF0EDE8),
    inversePrimary: Color(0xFF9DC995),
    // Surface containers: butter-warm cream tints (tier with mistBackground)
    surfaceContainerHighest: Color(0xFFEEE8DC),
    surfaceContainerHigh: Color(0xFFF2EDE0),
    surfaceContainer: mistBackground,
    surfaceContainerLow: Color(0xFFFAF7ED),
    surfaceContainerLowest: cloudWhite,
    surfaceDim: Color(0xFFEAE6D6),
    surfaceBright: cloudWhite,
  );

  /// Dark theme ColorScheme — "Night Garden".
  ///
  /// Warm, organic darkness — like a greenhouse at night.
  /// Not cold/navy — everything has a warm soil undertone.
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary: sprout green (same token as light; reads on night soil)
    primary: sproutGreen,
    onPrimary: Color(0xFF0F1510),
    primaryContainer: Color(0xFF2D4A30),
    onPrimaryContainer: sageContainer,
    // Secondary: pale sage — moonlit leaf
    secondary: Color(0xFFCADDCE),
    onSecondary: forestDeep,
    secondaryContainer: Color(0xFF2C3C28),
    onSecondaryContainer: skyTopTint,
    // Tertiary: softened honey amber — warm glow in darkness
    tertiary: _tertiaryGoldDark,
    onTertiary: _tertiaryOnDark,
    tertiaryContainer: _tertiaryContainerDark,
    onTertiaryContainer: _tertiaryContainerLight,
    // Error
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _errorContainerLight,
    // Surface: deep organic night soil — warm dark, not cold navy
    surface: _backgroundDark,
    onSurface: Color(0xFFE4DDD5),
    onSurfaceVariant: Color(0xFFBDB3A8),
    // Outline: warm neutral dark
    outline: Color(0xFF8A7E72),
    outlineVariant: Color(0xFF3D342C),
    // Shadow & Scrim
    shadow: pureBlack,
    scrim: pureBlack,
    // Inverse
    inverseSurface: Color(0xFFE4DDD5),
    onInverseSurface: Color(0xFF1E1A16),
    inversePrimary: Color(0xFF35683C),
    // Surface containers: warm soil-tinted darks
    surfaceContainerHighest: Color(0xFF28332A),
    surfaceContainerHigh: _surfaceContainerSoilHigh,
    surfaceContainer: _surfaceContainerSoil,
    surfaceContainerLow: _surfaceContainerSoilLow,
    surfaceContainerLowest: Color(0xFF0A0E0A),
    surfaceDim: _backgroundDark,
    surfaceBright: Color(0xFF283024),
  );

  /// Sky-to-Land Gradient for full-page backgrounds.
  /// Light: warm cream morning mist (sky haze → mistBackground)
  /// Dark:  deep organic night soil (warm dark, not cold navy)
  static LinearGradient skyGradient({required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFF0F1510), Color(0xFF1A2018)]
          : const [skyTopTint, mistBackground],
    );
  }

  /// Full-page background decoration. Apply to every Scaffold body container.
  /// Light: warm cream with subtle nature texture overlay
  /// Dark:  deep warm soil with subtle dark texture overlay
  static BoxDecoration skyDecoration({required bool isDark}) {
    if (isDark) {
      return const BoxDecoration(
        color: _backgroundDark,
        image: DecorationImage(
          image: AssetImage('assets/backgrounds/dark_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.18,
        ),
      );
    }
    return const BoxDecoration(
      color: mistBackground,
      image: DecorationImage(
        image: AssetImage('assets/backgrounds/light_bg.png'),
        fit: BoxFit.cover,
        opacity: 0.18,
      ),
    );
  }

  /// Full-page background: same as [skyDecoration] or a flat “onboarding-minimal” canvas.
  ///
  /// Use [minimal] `true` for the flat warm cream / night soil look (no texture overlay),
  /// matching onboarding steps. Use `false` (default) to keep the subtle garden texture.
  static BoxDecoration pageBackgroundDecoration({
    required bool isDark,
    bool minimal = false,
  }) {
    if (!minimal) {
      return skyDecoration(isDark: isDark);
    }
    if (isDark) {
      return const BoxDecoration(color: _backgroundDark);
    }
    return const BoxDecoration(color: mistBackground);
  }

  /// Floating Card / Cloud Decoration.
  /// Light: white card, soft warm shadow (soil-tinted, not grey)
  /// Dark:  warm grove dark card, deep shadow
  static BoxDecoration cloudDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? cloudDark : cloudWhite,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? pureBlack.withValues(alpha: 0.35)
              : forestDeep.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
