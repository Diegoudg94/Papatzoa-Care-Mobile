import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme_preset.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceAccent,
    required this.surfaceDiary,
    required this.surfaceSessions,
    required this.surfaceSupport,
    required this.primary,
    required this.primaryActive,
    required this.primaryContainer,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.diaryAccent,
    required this.diaryAccentContainer,
    required this.sessionsAccent,
    required this.sessionsAccentContainer,
    required this.supportAccent,
    required this.supportAccentContainer,
    required this.activityAccent,
    required this.activityAccentContainer,
    required this.therapistAccent,
    required this.therapistAccentContainer,
    required this.tipsAccent,
    required this.tipsAccentContainer,
    required this.emotionalTrackingAccent,
    required this.emotionalTrackingAccentContainer,
  });
  final Color background, surface, surfaceElevated, surfaceAccent;
  final Color surfaceDiary, surfaceSessions, surfaceSupport;
  final Color primary, primaryActive, primaryContainer, secondary;
  final Color textPrimary, textSecondary, border;
  final Color success, warning, error;
  final Color diaryAccent, diaryAccentContainer;
  final Color sessionsAccent, sessionsAccentContainer;
  final Color supportAccent, supportAccentContainer;
  final Color activityAccent, activityAccentContainer;
  final Color therapistAccent, therapistAccentContainer;
  final Color tipsAccent, tipsAccentContainer;
  final Color emotionalTrackingAccent, emotionalTrackingAccentContainer;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceAccent,
    Color? surfaceDiary,
    Color? surfaceSessions,
    Color? surfaceSupport,
    Color? primary,
    Color? primaryActive,
    Color? primaryContainer,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? diaryAccent,
    Color? diaryAccentContainer,
    Color? sessionsAccent,
    Color? sessionsAccentContainer,
    Color? supportAccent,
    Color? supportAccentContainer,
    Color? activityAccent,
    Color? activityAccentContainer,
    Color? therapistAccent,
    Color? therapistAccentContainer,
    Color? tipsAccent,
    Color? tipsAccentContainer,
    Color? emotionalTrackingAccent,
    Color? emotionalTrackingAccentContainer,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    surfaceAccent: surfaceAccent ?? this.surfaceAccent,
    surfaceDiary: surfaceDiary ?? this.surfaceDiary,
    surfaceSessions: surfaceSessions ?? this.surfaceSessions,
    surfaceSupport: surfaceSupport ?? this.surfaceSupport,
    primary: primary ?? this.primary,
    primaryActive: primaryActive ?? this.primaryActive,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    secondary: secondary ?? this.secondary,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    diaryAccent: diaryAccent ?? this.diaryAccent,
    diaryAccentContainer: diaryAccentContainer ?? this.diaryAccentContainer,
    sessionsAccent: sessionsAccent ?? this.sessionsAccent,
    sessionsAccentContainer:
        sessionsAccentContainer ?? this.sessionsAccentContainer,
    supportAccent: supportAccent ?? this.supportAccent,
    supportAccentContainer:
        supportAccentContainer ?? this.supportAccentContainer,
    activityAccent: activityAccent ?? this.activityAccent,
    activityAccentContainer:
        activityAccentContainer ?? this.activityAccentContainer,
    therapistAccent: therapistAccent ?? this.therapistAccent,
    therapistAccentContainer:
        therapistAccentContainer ?? this.therapistAccentContainer,
    tipsAccent: tipsAccent ?? this.tipsAccent,
    tipsAccentContainer: tipsAccentContainer ?? this.tipsAccentContainer,
    emotionalTrackingAccent:
        emotionalTrackingAccent ?? this.emotionalTrackingAccent,
    emotionalTrackingAccentContainer:
        emotionalTrackingAccentContainer ??
        this.emotionalTrackingAccentContainer,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceAccent: Color.lerp(surfaceAccent, other.surfaceAccent, t)!,
      surfaceDiary: Color.lerp(surfaceDiary, other.surfaceDiary, t)!,
      surfaceSessions: Color.lerp(surfaceSessions, other.surfaceSessions, t)!,
      surfaceSupport: Color.lerp(surfaceSupport, other.surfaceSupport, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryActive: Color.lerp(primaryActive, other.primaryActive, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      diaryAccent: Color.lerp(diaryAccent, other.diaryAccent, t)!,
      diaryAccentContainer: Color.lerp(
        diaryAccentContainer,
        other.diaryAccentContainer,
        t,
      )!,
      sessionsAccent: Color.lerp(sessionsAccent, other.sessionsAccent, t)!,
      sessionsAccentContainer: Color.lerp(
        sessionsAccentContainer,
        other.sessionsAccentContainer,
        t,
      )!,
      supportAccent: Color.lerp(supportAccent, other.supportAccent, t)!,
      supportAccentContainer: Color.lerp(
        supportAccentContainer,
        other.supportAccentContainer,
        t,
      )!,
      activityAccent: Color.lerp(activityAccent, other.activityAccent, t)!,
      activityAccentContainer: Color.lerp(
        activityAccentContainer,
        other.activityAccentContainer,
        t,
      )!,
      therapistAccent: Color.lerp(therapistAccent, other.therapistAccent, t)!,
      therapistAccentContainer: Color.lerp(
        therapistAccentContainer,
        other.therapistAccentContainer,
        t,
      )!,
      tipsAccent: Color.lerp(tipsAccent, other.tipsAccent, t)!,
      tipsAccentContainer: Color.lerp(
        tipsAccentContainer,
        other.tipsAccentContainer,
        t,
      )!,
      emotionalTrackingAccent: Color.lerp(
        emotionalTrackingAccent,
        other.emotionalTrackingAccent,
        t,
      )!,
      emotionalTrackingAccentContainer: Color.lerp(
        emotionalTrackingAccentContainer,
        other.emotionalTrackingAccentContainer,
        t,
      )!,
    );
  }
}

class AppTheme {
  static final AppColors lightColors = colorsFor(
    PapatzoaThemePreset.therapeuticBlueMatte,
    Brightness.light,
  );
  static final AppColors darkColors = colorsFor(
    PapatzoaThemePreset.therapeuticBlueMatte,
    Brightness.dark,
  );
  static ThemeData get light =>
      build(PapatzoaThemePreset.therapeuticBlueMatte, Brightness.light);
  static ThemeData get dark =>
      build(PapatzoaThemePreset.therapeuticBlueMatte, Brightness.dark);

  static AppColors colorsFor(
    PapatzoaThemePreset preset,
    Brightness brightness,
  ) {
    final palette = papatzoaThemeDefinitions[preset]!.forBrightness(brightness);
    final dark = brightness == Brightness.dark;
    Color container(Color color) =>
        Color.lerp(palette.surface, color, dark ? 0.22 : 0.16)!;
    return AppColors(
      background: palette.background,
      surface: palette.surface,
      surfaceElevated: palette.surfaceElevated,
      primaryActive: palette.primaryActive,
      surfaceAccent: palette.surfaceAccent,
      surfaceDiary: palette.surface,
      surfaceSessions: palette.surface,
      surfaceSupport: palette.surface,
      primary: palette.primary,
      primaryContainer: container(palette.primary),
      secondary: palette.textSecondary,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      border: palette.border,
      success: palette.diary,
      warning: palette.tips,
      error: palette.activity,
      diaryAccent: palette.diary,
      diaryAccentContainer: container(palette.diary),
      sessionsAccent: palette.sessions,
      sessionsAccentContainer: container(palette.sessions),
      supportAccent: palette.support,
      supportAccentContainer: container(palette.support),
      activityAccent: palette.activity,
      activityAccentContainer: container(palette.activity),
      therapistAccent: palette.therapist,
      therapistAccentContainer: container(palette.therapist),
      tipsAccent: palette.tips,
      tipsAccentContainer: container(palette.tips),
      emotionalTrackingAccent: palette.emotional,
      emotionalTrackingAccentContainer: container(palette.emotional),
    );
  }

  static ThemeData build(PapatzoaThemePreset preset, Brightness brightness) =>
      _build(colorsFor(preset, brightness), brightness);

  static ThemeData _build(AppColors tokens, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.primary,
          brightness: brightness,
        ).copyWith(
          primary: tokens.primary,
          onPrimary: tokens.primary.computeLuminance() > 0.179
              ? Colors.black
              : Colors.white,
          primaryContainer: tokens.primaryContainer,
          onPrimaryContainer: tokens.textPrimary,
          secondary: tokens.secondary,
          surface: tokens.surface,
          onSurface: tokens.textPrimary,
          onSurfaceVariant: tokens.textSecondary,
          outline: tokens.border,
          error: tokens.error,
        );
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: tokens.background,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.border.withValues(alpha: 0.82)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: tokens.textSecondary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        tileColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerColor: tokens.border,
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(
            bodyColor: tokens.textPrimary,
            displayColor: tokens.textPrimary,
          )
          .copyWith(
            headlineMedium: ThemeData(brightness: brightness)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                  letterSpacing: -0.2,
                ),
            titleLarge: ThemeData(brightness: brightness).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
            titleMedium: ThemeData(brightness: brightness).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500, height: 1.38),
            bodyLarge: ThemeData(brightness: brightness).textTheme.bodyLarge
                ?.copyWith(height: 1.5, letterSpacing: 0.05),
            bodyMedium: ThemeData(brightness: brightness).textTheme.bodyMedium
                ?.copyWith(height: 1.48),
          ),
    );
  }
}
