import 'package:flutter/material.dart';

/// Seero: HabitSeeding — Premium "Digital Greenhouse" Palette.
///
/// Metaphor Mapping:
/// - Mist & Sky   → Backgrounds (Airy and breathable)
/// - Clouds       → Cards/Widgets (Floating and soft)
/// - Forest       → Bottom Nav (Grounded, fertile foundation)
/// - Sprout       → Primary Actions (Growth and life)
/// - Water        → Floating Action Button (The catalyst for growth)
/// - Seed         → Rewards & Coins (The golden potential)
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // ── 1. The Core Nature Foundation ──
  // ═══════════════════════════════════════════════════════════════

  // Mist & Sky (Atmosphere)
  static const Color mistBackground = Color(0xFFF4F7F5);
  static const Color skyTopTint = Color(0xFFE0F2F1);

  // Forest & Growth (Primary Brand)
  static const Color forestDeep = Color(0xFF1B3022);
  static const Color sproutGreen = Color(0xFF4CAF50);
  static const Color springWater = Color(0xFF2D5A27);

  // Seed & Reward (Accents)
  static const Color seedChampagne = Color(0xFFF5E6D3);
  static const Color seedGold = Color(0xFFD4AF37);

  // Cloud Surfaces
  static const Color cloudWhite = Colors.white;
  static const Color cloudDark = Color(0xFF1E2A3A);

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
  static const Color cloudLight = Colors.white;
  static const Color cloudBorderDark = Color(0xFF2A3A4A);

  // ── Domain accent (not in ColorScheme) ──
  static const Color completedOrange = Color(0xFFE8802A);

  // ── ColorScheme source values (used only inside lightScheme/darkScheme) ──
  static const Color _backgroundDark = Color(0xFF0F1A14);
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
        return isDark ? categoryProductivityBgDark : categoryProductivityBgLight;
      case 'Learning':
        return isDark ? categoryLearningBgDark : categoryLearningBgLight;
      case 'Relationships':
        return isDark ? categoryRelationshipsBgDark : categoryRelationshipsBgLight;
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
        return isDark ? categoryMindfulnessIconDark : categoryMindfulnessIconLight;
      case 'Productivity':
        return isDark ? categoryProductivityIconDark : categoryProductivityIconLight;
      case 'Learning':
        return isDark ? categoryLearningIconDark : categoryLearningIconLight;
      case 'Relationships':
        return isDark ? categoryRelationshipsIconDark : categoryRelationshipsIconLight;
      case 'Finance':
        return isDark ? categoryFinanceIconDark : categoryFinanceIconLight;
      case 'Creativity':
        return isDark ? categoryCreativityIconDark : categoryCreativityIconLight;
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
  static const Color skyPaleGreen = Color(0xFFe8f0e0);
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
  static const Color _tertiaryGoldDark = Color(0xFFE8C46A);
  static const Color _tertiaryOnDark = Color(0xFF3E2E00);
  static const Color _tertiaryContainerDark = Color(0xFF5C4400);
  static const Color _tertiaryContainerLight = Color(0xFFFFF3D6);
  static const Color _errorContainerDark = Color(0xFF93000A);
  static const Color _errorContainerLight = Color(0xFFFFDAD6);
  static const Color _onErrorContainerLight = Color(0xFF410002);
  static const Color _surfaceContainerForestHigh = Color(0xFF1A2E22);
  static const Color _surfaceContainerForest = Color(0xFF142518);
  static const Color _surfaceContainerForestLow = Color(0xFF101E14);

  /// Light theme ColorScheme — "Morning in the Garden".
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary (sprout green — drives primary actions)
    primary: sproutGreen,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCEDC8),
    onPrimaryContainer: forestDeep,
    // Secondary (forest deep — grounded accent)
    secondary: forestDeep,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE8F5E9),
    onSecondaryContainer: forestDeep,
    // Tertiary (seed gold — coins, rewards)
    tertiary: seedGold,
    onTertiary: Colors.white,
    tertiaryContainer: _tertiaryContainerLight,
    onTertiaryContainer: _tertiaryOnDark,
    // Error
    error: _errorLight,
    onError: _onErrorLight,
    errorContainer: _errorContainerLight,
    onErrorContainer: _onErrorContainerLight,
    // Surface (sage mist — breathable background)
    surface: mistBackground,
    onSurface: forestDeep,
    onSurfaceVariant: Color(0xFF414F45),
    // Outline (neutral sage tones)
    outline: Color(0xFF727972),
    outlineVariant: Color(0xFFC2C9C2),
    // Shadow & Scrim
    shadow: forestDeep,
    scrim: forestDeep,
    // Inverse
    inverseSurface: forestDeep,
    onInverseSurface: Color(0xFFE8F0EA),
    inversePrimary: Color(0xFF80E27E),
    // Surface containers (subtle sage tints, close to white)
    surfaceContainerHighest: Color(0xFFECF0ED),
    surfaceContainerHigh: Color(0xFFF0F4F1),
    surfaceContainer: Color(0xFFF4F7F5),
    surfaceContainerLow: Color(0xFFF8FAF8),
    surfaceContainerLowest: cloudWhite,
    surfaceDim: Color(0xFFE4E8E5),
    surfaceBright: cloudWhite,
  );

  /// Dark theme ColorScheme — "Night in the Greenhouse".
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary (sprout green — consistent brand)
    primary: sproutGreen,
    onPrimary: forestDeep,
    primaryContainer: Color(0xFF2D5A27),
    onPrimaryContainer: Color(0xFFDCEDC8),
    // Secondary (pale green — moonlit foliage)
    secondary: Color(0xFFD0E8D0),
    onSecondary: forestDeep,
    secondaryContainer: Color(0xFF2A4A30),
    onSecondaryContainer: Color(0xFFE8F5E9),
    // Tertiary (gold accent — coins, rewards)
    tertiary: _tertiaryGoldDark,
    onTertiary: _tertiaryOnDark,
    tertiaryContainer: _tertiaryContainerDark,
    onTertiaryContainer: _tertiaryContainerLight,
    // Error
    error: _errorDark,
    onError: _onErrorDark,
    errorContainer: _errorContainerDark,
    onErrorContainer: _errorContainerLight,
    // Surface (deep organic dark)
    surface: _backgroundDark,
    onSurface: Color(0xFFE1E3E1),
    onSurfaceVariant: Color(0xFFC2C9C2),
    // Outline
    outline: Color(0xFF8B938B),
    outlineVariant: Color(0xFF414F45),
    // Shadow & Scrim
    shadow: Colors.black,
    scrim: Colors.black,
    // Inverse
    inverseSurface: Color(0xFFE1E3E1),
    onInverseSurface: Color(0xFF1A2A1E),
    inversePrimary: Color(0xFF2E7D32),
    // Surface containers (dark forest tints)
    surfaceContainerHighest: Color(0xFF253028),
    surfaceContainerHigh: _surfaceContainerForestHigh,
    surfaceContainer: _surfaceContainerForest,
    surfaceContainerLow: _surfaceContainerForestLow,
    surfaceContainerLowest: Color(0xFF0A120C),
    surfaceDim: _backgroundDark,
    surfaceBright: Color(0xFF253028),
  );

  /// Sky-to-Land Gradient for full-page backgrounds.
  static LinearGradient skyGradient({required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFF0D1B2A), Color(0xFF1B263B)]
          : const [skyTopTint, mistBackground],
    );
  }

  /// Puffy Cloud Decoration for cards/widgets.
  static BoxDecoration cloudDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? cloudDark : cloudWhite,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.4)
              : forestDeep.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
