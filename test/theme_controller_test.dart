import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papatzoa_mobile/core/theme/app_theme.dart';
import 'package:papatzoa_mobile/core/theme/theme_controller.dart';
import 'package:papatzoa_mobile/core/theme/theme_preset.dart';
import 'package:papatzoa_mobile/core/theme/theme_picker_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('defaults to light without saved preference', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.light);
    expect(controller.preset, PapatzoaThemePreset.therapeuticBlueMatte);
    controller.dispose();
  });

  test('saves dark, restores it, and changes back to light', () async {
    final first = ThemeController();
    await first.load();
    await first.setMode(ThemeMode.dark);
    expect(
      await const FlutterSecureStorage().read(
        key: ThemeController.preferenceKey,
      ),
      'dark',
    );
    final restarted = ThemeController();
    await restarted.load();
    expect(restarted.mode, ThemeMode.dark);
    await restarted.setMode(ThemeMode.light);
    expect(
      await const FlutterSecureStorage().read(
        key: ThemeController.preferenceKey,
      ),
      'light',
    );
    first.dispose();
    restarted.dispose();
  });

  test('both themes provide semantic colors and contrasting brightness', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.extension<AppColors>(), isNotNull);
    expect(AppTheme.dark.extension<AppColors>(), isNotNull);
  });
  test('restores old mode and falls back for unknown preset', () async {
    FlutterSecureStorage.setMockInitialValues({
      ThemeController.preferenceKey: 'dark',
      ThemeController.presetPreferenceKey: 'removed-preset',
    });
    final controller = ThemeController();
    await controller.load();
    expect(controller.mode, ThemeMode.dark);
    expect(controller.preset, PapatzoaThemePreset.therapeuticBlueMatte);
    controller.dispose();
  });

  test('all presets persist independently from appearance mode', () async {
    final controller = ThemeController();
    await controller.load();
    await controller.setMode(ThemeMode.dark);
    for (final preset in PapatzoaThemePreset.values) {
      await controller.setPreset(preset);
      expect(controller.mode, ThemeMode.dark);
      final restarted = ThemeController();
      await restarted.load();
      expect(restarted.mode, ThemeMode.dark);
      expect(restarted.preset, preset);
      restarted.dispose();
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(preset, brightness);
        expect(theme.brightness, brightness);
        expect(theme.extension<AppColors>(), isNotNull);
      }
    }
    await controller.setMode(ThemeMode.light);
    expect(controller.preset, PapatzoaThemePreset.therapeuticBlueMatte);
    controller.dispose();
  });

  testWidgets('picker shows six previews and selects immediately', (
    tester,
  ) async {
    final controller = ThemeController();
    await tester.pumpWidget(
      ThemeControllerScope(
        controller: controller,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.build(controller.preset, Brightness.light),
            home: const ThemePickerPage(),
          ),
        ),
      ),
    );
    expect(find.text('Elegir tema'), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-therapeuticCalm')), findsOneWidget);
    for (final preset in PapatzoaThemePreset.values) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('theme-${preset.name}')),
        180,
      );
      expect(find.byKey(ValueKey('theme-${preset.name}')), findsOneWidget);
      expect(find.byKey(ValueKey('preview-${preset.name}-0')), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('theme-introspectiveLavender')),
      -180,
    );
    await tester.tap(find.byKey(const ValueKey('theme-introspectiveLavender')));
    await tester.pumpAndSettle();
    expect(controller.preset, PapatzoaThemePreset.introspectiveLavender);
    expect(controller.mode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Elegir tema'))).colorScheme.primary,
      papatzoaThemeDefinitions[PapatzoaThemePreset.introspectiveLavender]!
          .light
          .primary,
    );
    controller.dispose();
  });
}
