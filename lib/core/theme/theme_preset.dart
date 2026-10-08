import 'package:flutter/material.dart';

/// A visual identity independent of the selected light or dark mode.
enum PapatzoaThemePreset {
  therapeuticCalm('Calma terapéutica', 'Equilibrio, seguridad y calidez'),
  comfortingPastel('Pastel reconfortante', 'Suave, cercano y acogedor'),
  introspectiveLavender(
    'Lavanda introspectiva',
    'Calma, introspección y suavidad',
  ),
  livelyWellbeing('Wellbeing vivo', 'Más energía y personalidad'),
  contemporaryMatte('Mate contemporánea', 'Sobrio, premium y maduro'),
  therapeuticBlueMatte(
    'Mate azulado terapéutico',
    'Sereno, seguro y contemporáneo',
  );

  const PapatzoaThemePreset(this.label, this.description);
  final String label;
  final String description;
}

@immutable
class PapatzoaThemePalette {
  const PapatzoaThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceAccent,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primaryActive,
    required this.diary,
    required this.sessions,
    required this.support,
    required this.activity,
    required this.therapist,
    required this.tips,
    required this.emotional,
  });
  final Color background, surface, surfaceElevated, surfaceAccent, border;
  final Color textPrimary, textSecondary, primary, primaryActive;
  final Color diary, sessions, support, activity, therapist, tips, emotional;

  List<Color> get previewColors => [primary, surface, diary, sessions, support];
}

class PapatzoaThemeDefinition {
  const PapatzoaThemeDefinition(this.light, this.dark);
  final PapatzoaThemePalette light, dark;
  PapatzoaThemePalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

const _calmAccents = [
  Color(0xFF4C8A84),
  Color(0xFF789FC4),
  Color(0xFF9B84B7),
  Color(0xFFD28F7B),
  Color(0xFF89A996),
  Color(0xFFC6A15A),
  Color(0xFFB7839D),
];
const _pastelAccents = [
  Color(0xFF65ADA9),
  Color(0xFF899BC9),
  Color(0xFFA88CB7),
  Color(0xFFDC9B7D),
  Color(0xFF8FAE9E),
  Color(0xFFC6A15A),
  Color(0xFFC58FA6),
];
const _lavenderAccents = [
  Color(0xFF5FAFA7),
  Color(0xFF7899C4),
  Color(0xFF987BB0),
  Color(0xFFD58E73),
  Color(0xFF89A996),
  Color(0xFFC6A15A),
  Color(0xFFB7839D),
];
const _wellbeingAccents = [
  Color(0xFF55B8AE),
  Color(0xFF70A8E8),
  Color(0xFFA47BC7),
  Color(0xFFE38C61),
  Color(0xFF86AF94),
  Color(0xFFD3A94E),
  Color(0xFFCF8398),
];
const _matteAccents = [
  Color(0xFF527F79),
  Color(0xFF647C9D),
  Color(0xFF80758C),
  Color(0xFFAD745E),
  Color(0xFF778879),
  Color(0xFFA78D5F),
  Color(0xFF9D7881),
];
const _blueAccents = [
  Color(0xFF4E9A95),
  Color(0xFF6F8FBE),
  Color(0xFF9B84B7),
  Color(0xFFC9876B),
  Color(0xFF8AA88E),
  Color(0xFFB59A67),
  Color(0xFF7E97C2),
];

PapatzoaThemePalette _palette({
  required int background,
  required int surface,
  required int elevated,
  required int accent,
  required int border,
  required int text,
  required int secondary,
  required int primary,
  int? active,
  required List<Color> modules,
}) => PapatzoaThemePalette(
  background: Color(background),
  surface: Color(surface),
  surfaceElevated: Color(elevated),
  surfaceAccent: Color(accent),
  border: Color(border),
  textPrimary: Color(text),
  textSecondary: Color(secondary),
  primary: Color(primary),
  primaryActive: Color(active ?? primary),
  diary: modules[0],
  sessions: modules[1],
  support: modules[2],
  activity: modules[3],
  therapist: modules[4],
  tips: modules[5],
  emotional: modules[6],
);

final Map<PapatzoaThemePreset, PapatzoaThemeDefinition>
papatzoaThemeDefinitions = {
  PapatzoaThemePreset.therapeuticCalm: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFF7F3EC,
      surface: 0xFFFFFDF9,
      elevated: 0xFFFFFDF9,
      accent: 0xFFF1EBE3,
      border: 0xFFD9D2C7,
      text: 0xFF2E2C2A,
      secondary: 0xFF6F6A63,
      primary: 0xFF4C8A84,
      modules: _calmAccents,
    ),
    _palette(
      background: 0xFF16201F,
      surface: 0xFF1E2B29,
      elevated: 0xFF223431,
      accent: 0xFF223431,
      border: 0xFF354A45,
      text: 0xFFF3EFE8,
      secondary: 0xFFC7C0B7,
      primary: 0xFF7CC6BE,
      modules: _calmAccents,
    ),
  ),
  PapatzoaThemePreset.comfortingPastel: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFFBF7F2,
      surface: 0xFFFFFDFC,
      elevated: 0xFFFFFDFC,
      accent: 0xFFF5EEE8,
      border: 0xFFE5DDD3,
      text: 0xFF2D2A28,
      secondary: 0xFF756E67,
      primary: 0xFF6F9E8F,
      modules: _pastelAccents,
    ),
    _palette(
      background: 0xFF1D2026,
      surface: 0xFF262B33,
      elevated: 0xFF2E3440,
      accent: 0xFF2E3440,
      border: 0xFF414957,
      text: 0xFFF5F1EC,
      secondary: 0xFFC9C1B8,
      primary: 0xFF90C2B1,
      modules: _pastelAccents,
    ),
  ),
  PapatzoaThemePreset.introspectiveLavender: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFF7F4F8,
      surface: 0xFFFFFDFC,
      elevated: 0xFFFFFDFC,
      accent: 0xFFF1EBF4,
      border: 0xFFE3DCE4,
      text: 0xFF302C32,
      secondary: 0xFF746D75,
      primary: 0xFF786985,
      modules: _lavenderAccents,
    ),
    _palette(
      background: 0xFF1B1922,
      surface: 0xFF24212B,
      elevated: 0xFF2D2835,
      accent: 0xFF2D2835,
      border: 0xFF413A46,
      text: 0xFFF4EFF5,
      secondary: 0xFFC7BEC9,
      primary: 0xFFB9A0C7,
      modules: _lavenderAccents,
    ),
  ),
  PapatzoaThemePreset.livelyWellbeing: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFF8F4EE,
      surface: 0xFFFFFDF9,
      elevated: 0xFFFFFDF9,
      accent: 0xFFF4EEE6,
      border: 0xFFE6DDD2,
      text: 0xFF2C2927,
      secondary: 0xFF746E67,
      primary: 0xFF4F8F85,
      modules: _wellbeingAccents,
    ),
    _palette(
      background: 0xFF17212B,
      surface: 0xFF202C38,
      elevated: 0xFF263646,
      accent: 0xFF263646,
      border: 0xFF344556,
      text: 0xFFF7F2EB,
      secondary: 0xFFC8C1B8,
      primary: 0xFF82CBBF,
      modules: _wellbeingAccents,
    ),
  ),
  PapatzoaThemePreset.contemporaryMatte: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFEDEBE6,
      surface: 0xFFF7F5F1,
      elevated: 0xFFFCFBF8,
      accent: 0xFFE6E4DE,
      border: 0xFFD1CEC7,
      text: 0xFF282C30,
      secondary: 0xFF696D70,
      primary: 0xFF536D7A,
      modules: _matteAccents,
    ),
    _palette(
      background: 0xFF14191D,
      surface: 0xFF1D252B,
      elevated: 0xFF242E35,
      accent: 0xFF242E35,
      border: 0xFF303A40,
      text: 0xFFECEBE7,
      secondary: 0xFFADB2B3,
      primary: 0xFF89A4B0,
      modules: _matteAccents,
    ),
  ),
  PapatzoaThemePreset.therapeuticBlueMatte: PapatzoaThemeDefinition(
    _palette(
      background: 0xFFF4F3F0,
      surface: 0xFFFCFBF9,
      elevated: 0xFFFCFBF9,
      accent: 0xFFF7F8FA,
      border: 0xFFD7DCE3,
      text: 0xFF22262B,
      secondary: 0xFF66707A,
      primary: 0xFF547A95,
      active: 0xFF44677F,
      modules: _blueAccents,
    ),
    _palette(
      background: 0xFF101923,
      surface: 0xFF18232E,
      elevated: 0xFF1D2A36,
      accent: 0xFF1D2A36,
      border: 0xFF2C3945,
      text: 0xFFEEF2F5,
      secondary: 0xFFAAB6C2,
      primary: 0xFF78A9C7,
      modules: _blueAccents,
    ),
  ),
};
