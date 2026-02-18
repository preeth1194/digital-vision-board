import 'package:flutter/material.dart';

/// Custom color palette for the Digital Vision Board app.
/// "Organic Clarity" theme — white and light green aesthetic.
///
/// Named palette:
/// - Darkest: #1A2E1A (deep forest-black)
/// - Dark:    #2D5A3D (forestGreen)
/// - Medium:  #4A7C59 (mossGreen)
/// - Light:   #A8D5BA (mintGreen)
/// - Lightest: #D4EBD4 (pale green tint)
class AppColors {
  AppColors._();

  // ── Primary palette (abstract names kept for backward-compat) ──
  static const Color darkest = Color(0xFF1A2E1A);
  static const Color dark = Color(0xFF2D5A3D);
  static const Color medium = Color(0xFF4A7C59);
  static const Color light = Color(0xFFA8D5BA);
  static const Color lightest = Color(0xFFD4EBD4);

  // ── Semantic named colors ──
  static const Color offWhite = Color(0xFFF8F9F4);
  static const Color mintGreen = Color(0xFFA8D5BA);
  static const Color sageGreen = Color(0xFF8FBC8F);
  static const Color mossGreen = Color(0xFF4A7C59);
  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color gold = Color(0xFFD4A843);
  static const Color cream = Color(0xFFFAFAF5);

  // ── Derived / utility colors ──
  static const Color backgroundDark = Color(0xFF0F1A0F);
  static const Color backgroundLight = Color(0xFFF8F9F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color onErrorDark = Color(0xFF690005);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 1: General UI Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color paleGreenTint = Color(0xFFE8F5E9);
  static const Color nearBlack = Color(0xFF1A1A1A);
  static const Color dimGrey = Color(0xFF6B6B6B);
  static const Color completedOrange = Color(0xFFE8802A);
  static const Color slateGrey = Color(0xFF334155);
  static const Color progressBlue = Color(0xFF3366CC);
  static const Color darkSurface = Color(0xFF1C1B1F);
  static const Color warmIvory = Color(0xFFFAF8F5);

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
  // ── Group 3: Habit Category Colors (bg + icon, light + dark) ──
  // ═══════════════════════════════════════════════════════════════
  static const Color categoryHealthBgLight = Color(0xFFA8D5BA);
  static const Color categoryHealthBgDark = Color(0xFF2E7D5B);
  static const Color categoryHealthIconLight = Color(0xFF2E5E4A);
  static const Color categoryHealthIconDark = Color(0xFFB8E6C8);

  static const Color categoryFitnessBgLight = Color(0xFFB8E6C8);
  static const Color categoryFitnessBgDark = Color(0xFF33805E);
  static const Color categoryFitnessIconLight = Color(0xFF2A5E40);
  static const Color categoryFitnessIconDark = Color(0xFFC0F0D0);

  static const Color categoryMindfulnessBgLight = Color(0xFFF5C6AA);
  static const Color categoryMindfulnessBgDark = Color(0xFF8D5B3A);
  static const Color categoryMindfulnessIconLight = Color(0xFF5E3820);
  static const Color categoryMindfulnessIconDark = Color(0xFFFDD8B8);

  static const Color categoryProductivityBgLight = Color(0xFFBBDEFB);
  static const Color categoryProductivityBgDark = Color(0xFF3565A0);
  static const Color categoryProductivityIconLight = Color(0xFF1A3A6A);
  static const Color categoryProductivityIconDark = Color(0xFFCCE4FF);

  static const Color categoryLearningBgLight = Color(0xFFD1C4E9);
  static const Color categoryLearningBgDark = Color(0xFF5E4B8A);
  static const Color categoryLearningIconLight = Color(0xFF3A2C60);
  static const Color categoryLearningIconDark = Color(0xFFE0D4F0);

  static const Color categoryRelationshipsBgLight = Color(0xFFF8BBD0);
  static const Color categoryRelationshipsBgDark = Color(0xFF8A4466);
  static const Color categoryRelationshipsIconLight = Color(0xFF6A2040);
  static const Color categoryRelationshipsIconDark = Color(0xFFFDD0E0);

  static const Color categoryFinanceBgLight = Color(0xFFFFF9C4);
  static const Color categoryFinanceBgDark = Color(0xFF8A7A30);
  static const Color categoryFinanceIconLight = Color(0xFF5A4A10);
  static const Color categoryFinanceIconDark = Color(0xFFFFF5A0);

  static const Color categoryCreativityBgLight = Color(0xFFE1BEE7);
  static const Color categoryCreativityBgDark = Color(0xFF7B4A8A);
  static const Color categoryCreativityIconLight = Color(0xFF5A2A6A);
  static const Color categoryCreativityIconDark = Color(0xFFF0D0F8);

  static const Color categoryDefaultBgLight = Color(0xFFD5E8D4);
  static const Color categoryDefaultBgDark = Color(0xFF4A635A);
  static const Color categoryDefaultIconLight = Color(0xFF3A5040);
  static const Color categoryDefaultIconDark = Color(0xFFD0E8D0);

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
  // ── Group 4: Badge Colors ──
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
  // ── Group 5: Mood Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color moodAwful = Color(0xFFE57373);
  static const Color moodBad = Color(0xFFFFB74D);
  static const Color moodNeutral = Color(0xFFFFD54F);
  static const Color moodGood = Color(0xFF81C784);
  static const Color moodGreat = Color(0xFF4DB6AC);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 6: Board / Tile Pastel Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color pastelGreen = Color(0xFFECFDF5);
  static const Color pastelBlue = Color(0xFFE0F2FE);
  static const Color pastelPurple = Color(0xFFF3E8FF);
  static const Color pastelOrange = Color(0xFFFFF7ED);
  static const Color pastelPink = Color(0xFFFFF1F2);
  static const Color pastelIndigo = Color(0xFFEEF2FF);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 7: Journal Book Cover Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const int coverCoral = 0xFFE57373;
  static const int coverOrange = 0xFFFFB74D;
  static const int coverYellow = 0xFFFFF176;
  static const int coverLightGreen = 0xFFAED581;
  static const int coverTeal = 0xFF4DB6AC;
  static const int coverBlue = 0xFF64B5F6;
  static const int coverPurple = 0xFF9575CD;
  static const int coverPink = 0xFFF06292;
  static const int coverBrown = 0xFFA1887F;
  static const int coverBlueGrey = 0xFF90A4AE;

  // Cover-only colors used in choose_cover_screen
  static const int coverFijiPrimary = 0xFF4A7DFF;
  static const int coverFijiSecondary = 0xFF2E5BDB;
  static const int coverMidnightPrimary = 0xFF5C6BC0;
  static const int coverMidnightSecondary = 0xFF3949AB;
  static const int coverCustomGrey = 0xFF78909C;

  // ═══════════════════════════════════════════════════════════════
  // ── Group 8: Editor Background Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color editorBgMist = Color(0xFFF7F7FA);
  static const Color editorBgDarkNavy = Color(0xFF111827);
  static const Color editorBgCyan = Color(0xFF0EA5E9);
  static const Color editorBgEmerald = Color(0xFF10B981);
  static const Color editorBgAmber = Color(0xFFF59E0B);
  static const Color editorBgCrimson = Color(0xFFEF4444);
  static const Color editorBgViolet = Color(0xFF8B5CF6);

  // ═══════════════════════════════════════════════════════════════
  // ── Group 9: Habit Form Preset Colors ──
  // ═══════════════════════════════════════════════════════════════
  static const Color hueRed = Color(0xFFFF0000);
  static const Color hueYellow = Color(0xFFFFFF00);
  static const Color hueGreen = Color(0xFF00FF00);
  static const Color hueCyan = Color(0xFF00FFFF);
  static const Color hueBlue = Color(0xFF0000FF);
  static const Color hueMagenta = Color(0xFFFF00FF);

  static const Color habitRedLight = Color(0xFFEF4444);
  static const Color habitRedDark = Color(0xFFB91C1C);
  static const Color habitOrangeLight = Color(0xFFF97316);
  static const Color habitOrangeDark = Color(0xFFC2410C);
  static const Color habitYellowLight = Color(0xFFEAB308);
  static const Color habitYellowDark = Color(0xFFA16207);
  static const Color habitGreenLight = Color(0xFF22C55E);
  static const Color habitGreenDark = Color(0xFF15803D);
  static const Color habitBlueLight = Color(0xFF3B82F6);
  static const Color habitBlueDark = Color(0xFF1D4ED8);
  static const Color habitIndigoLight = Color(0xFF6366F1);
  static const Color habitIndigoDark = Color(0xFF4338CA);
  static const Color habitVioletLight = Color(0xFF8B5CF6);
  static const Color habitVioletDark = Color(0xFF6D28D9);

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

  // ═══════════════════════════════════════════════════════════════
  // ── ColorScheme-internal hex colors (used inside light/dark schemes) ──
  // ═══════════════════════════════════════════════════════════════
  static const Color tertiaryGoldDark = Color(0xFFE8C46A);
  static const Color tertiaryOnDark = Color(0xFF3E2E00);
  static const Color tertiaryContainerDark = Color(0xFF5C4400);
  static const Color tertiaryContainerLight = Color(0xFFFFF3D6);
  static const Color errorContainerDark = Color(0xFF93000A);
  static const Color errorContainerLight = Color(0xFFFFDAD6);
  static const Color onErrorContainerLight = Color(0xFF410002);
  static const Color surfaceContainerGreenHigh = Color(0xFF1E3A1E);
  static const Color surfaceContainerGreen = Color(0xFF152B15);
  static const Color surfaceContainerGreenLow = Color(0xFF122412);
  static const Color surfaceContainerLightMid = Color(0xFFF0F7F0);
  static const Color surfaceContainerLightLow = Color(0xFFF5FAF5);

  /// Light theme ColorScheme
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary
    primary: mossGreen,
    onPrimary: Colors.white,
    primaryContainer: paleGreenTint,
    onPrimaryContainer: darkest,
    // Secondary
    secondary: forestGreen,
    onSecondary: Colors.white,
    secondaryContainer: mintGreen,
    onSecondaryContainer: darkest,
    // Tertiary (gold accent — coins, sliders)
    tertiary: gold,
    onTertiary: Colors.white,
    tertiaryContainer: tertiaryContainerLight,
    onTertiaryContainer: tertiaryOnDark,
    // Error
    error: errorLight,
    onError: onErrorLight,
    errorContainer: errorContainerLight,
    onErrorContainer: onErrorContainerLight,
    // Surface
    surface: surfaceLight,
    onSurface: darkest,
    onSurfaceVariant: forestGreen,
    // Outline
    outline: mossGreen,
    outlineVariant: mintGreen,
    // Shadow & Scrim
    shadow: darkest,
    scrim: darkest,
    // Inverse
    inverseSurface: darkest,
    onInverseSurface: lightest,
    inversePrimary: mintGreen,
    // Surface variants
    surfaceContainerHighest: lightest,
    surfaceContainerHigh: paleGreenTint,
    surfaceContainer: surfaceContainerLightMid,
    surfaceContainerLow: surfaceContainerLightLow,
    surfaceContainerLowest: surfaceLight,
    surfaceDim: mintGreen,
    surfaceBright: surfaceLight,
  );

  /// Dark theme ColorScheme
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary
    primary: mintGreen,
    onPrimary: darkest,
    primaryContainer: forestGreen,
    onPrimaryContainer: lightest,
    // Secondary
    secondary: lightest,
    onSecondary: darkest,
    secondaryContainer: forestGreen,
    onSecondaryContainer: lightest,
    // Tertiary (gold accent — coins, sliders)
    tertiary: tertiaryGoldDark,
    onTertiary: tertiaryOnDark,
    tertiaryContainer: tertiaryContainerDark,
    onTertiaryContainer: tertiaryContainerLight,
    // Error
    error: errorDark,
    onError: onErrorDark,
    errorContainer: errorContainerDark,
    onErrorContainer: errorContainerLight,
    // Surface
    surface: darkest,
    onSurface: paleGreenTint,
    onSurfaceVariant: mintGreen,
    // Outline
    outline: sageGreen,
    outlineVariant: forestGreen,
    // Shadow & Scrim
    shadow: Colors.black,
    scrim: Colors.black,
    // Inverse
    inverseSurface: lightest,
    onInverseSurface: darkest,
    inversePrimary: mossGreen,
    // Surface variants
    surfaceContainerHighest: forestGreen,
    surfaceContainerHigh: surfaceContainerGreenHigh,
    surfaceContainer: surfaceContainerGreen,
    surfaceContainerLow: surfaceContainerGreenLow,
    surfaceContainerLowest: backgroundDark,
    surfaceDim: darkest,
    surfaceBright: forestGreen,
  );
}
