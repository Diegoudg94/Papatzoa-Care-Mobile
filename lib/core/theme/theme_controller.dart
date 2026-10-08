import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme_preset.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static const preferenceKey = 'appearance_theme_mode';
  static const presetPreferenceKey = 'appearance_theme_preset';
  final FlutterSecureStorage _storage;

  // Use stable enum names as persisted values so labels can be localized or
  // revised without invalidating preferences from an installed app.
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  PapatzoaThemePreset _preset = PapatzoaThemePreset.therapeuticBlueMatte;
  PapatzoaThemePreset get preset => _preset;

  Future<void> load() async {
    final saved = await _storage.read(key: preferenceKey);
    _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final savedPreset = await _storage.read(key: presetPreferenceKey);
    _preset = PapatzoaThemePreset.values.firstWhere(
      (value) => value.name == savedPreset,
      orElse: () => PapatzoaThemePreset.therapeuticBlueMatte,
    );
    // Repair missing or stale values once, keeping future launches predictable.
    if (savedPreset != _preset.name) {
      await _storage.write(key: presetPreferenceKey, value: _preset.name);
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == ThemeMode.system) return;
    _mode = mode;
    notifyListeners();
    await _storage.write(
      key: preferenceKey,
      value: mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> setPreset(PapatzoaThemePreset preset) async {
    _preset = preset;
    notifyListeners();
    await _storage.write(key: presetPreferenceKey, value: preset.name);
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope is required');
    return scope!.notifier!;
  }
}
