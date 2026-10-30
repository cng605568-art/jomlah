import 'package:flutter/material.dart';

/// Jomlah's colours: a modern dark blue, with the icon's cyan and lime as small accents.
/// Change a colour here and it changes everywhere.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0B1430); // app background
  static const surface = Color(0xFF111C3D); // cards and sheets
  static const overlay = Color(0xF2111C3D); // cards floating over the map (slightly see-through)
  static const raised = Color(0xFF1A2A55); // buttons and chips sitting on a card
  static const outline = Color(0xFF2B3A67); // thin borders and dividers
  static const primary = Color(0xFF3B82F6); // the main blue: buttons, highlights
  static const primaryDeep = Color(0xFF2563EB); // strong buttons
  static const sky = Color(0xFF60A5FA); // icons and links on dark backgrounds
  static const cyan = Color(0xFF22D3EE); // second accent
  static const lime = Color(0xFFC8FF3D); // brand accent from the icon, used sparingly
  static const textMuted = Color(0xFFA9B6D6); // secondary text
  static const warning = Color(0xFFF59E0B); // GPS problems, road alerts
  static const danger = Color(0xFFEF4444); // over the speed limit

  // On the map
  static const route = Color(0xFF2F7BFF); // the route ahead
  static const routeBorder = Color(0xFF0B1F5C);
  static const routeOption = Color(0xFF8FA3C7); // other routes while choosing
  static const destination = Color(0xFFF43F5E);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryDeep,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.cyan,
    onSecondary: AppColors.navy,
    secondaryContainer: const Color(0xFF1E3A8A),
    onSecondaryContainer: Colors.white,
    surface: AppColors.surface,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.navy,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.raised,
    surfaceContainerHighest: AppColors.raised,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
  );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.navy,
    canvasColor: AppColors.surface,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.outline,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.raised,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryDeep,
      foregroundColor: Colors.white,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.raised),
    dividerTheme: const DividerThemeData(color: AppColors.outline),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.sky),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.raised,
      selectedColor: AppColors.primaryDeep,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: Colors.white),
      side: BorderSide.none,
      shape: StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppColors.outline),
        shape: rounded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.sky),
    ),
  );
}
