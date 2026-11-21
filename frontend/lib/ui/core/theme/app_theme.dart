import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const primary = Color(0xFF32A060);
  static const accent = Color(0xFF52C883);
  static const mint = Color(0xFFAFE6A2);
  static const lime = Color(0xFFB8E68C);
  static const sage = Color(0xFF6AC08F);

  static const ink = Color(0xFF010E07);
  static const canvas = Color(0xFFF6F6F6);
  static const header = Color(0xFFFBFBFB);
  static const notificationBackground = Color(0xFFF1F6EF);
  static const mutedText = Color(0xFF6A7870);
  static const inactiveIcon = Color(0xFF6C6C6C);
}

abstract final class AppTheme {
  static const _large = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
  );

  static const _regular = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
  );

  static const _small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
  );

  static const _regularLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );

  static const _smallLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.sage,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.mint,
      onSecondaryContainer: AppColors.ink,
      tertiaryContainer: AppColors.lime,
      onTertiaryContainer: AppColors.ink,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: _large,
      displayMedium: _large,
      displaySmall: _large,
      headlineLarge: _large,
      headlineMedium: _large,
      headlineSmall: _large,
      titleLarge: _large,
      titleMedium: _regularLabel,
      titleSmall: _regularLabel,
      bodyLarge: _regular,
      bodyMedium: _regular,
      bodySmall: _small,
      labelLarge: _regularLabel,
      labelMedium: _smallLabel,
      labelSmall: _smallLabel,
    ),
  );
}
