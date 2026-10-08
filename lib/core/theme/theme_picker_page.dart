import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'theme_controller.dart';
import 'theme_preset.dart';

class ThemePickerPage extends StatelessWidget {
  const ThemePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeControllerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir tema')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: PapatzoaThemePreset.values.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final preset = PapatzoaThemePreset.values[index];
            final palette = papatzoaThemeDefinitions[preset]!.forBrightness(
              Theme.of(context).brightness,
            );
            final selected = controller.preset == preset;
            final colors = Theme.of(context).extension<AppColors>()!;
            return Card(
              child: InkWell(
                key: ValueKey('theme-${preset.name}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => controller.setPreset(preset),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              preset.description,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                for (final (colorIndex, color)
                                    in palette.previewColors.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 7),
                                    child: Container(
                                      key: ValueKey(
                                        'preview-${preset.name}-$colorIndex',
                                      ),
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: palette.border,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: colors.primary),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
