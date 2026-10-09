import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';

/// Pro feature: design your own table — pick felt, wood and brass colors.
class CustomThemeScreen extends StatelessWidget {
  final BilliardAudio audio;
  final BilliardSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  static const _swatches = [
    Color(0xFF1E5B40),
    Color(0xFF6E1E28),
    Color(0xFF1B3A5C),
    Color(0xFF4A5A2E),
    Color(0xFF0F6E5A),
    Color(0xFF2E3440),
    Color(0xFF7A3A1E),
    Color(0xFF4A1E42),
    Color(0xFF5A3618),
    Color(0xFF6E2F1C),
    Color(0xFF2C3A55),
    Color(0xFF3E2A14),
    Color(0xFF241309),
    Color(0xFF0C0C0E),
    Color(0xFFC9A227),
    Color(0xFFD4AF37),
    Color(0xFFB87333),
    Color(0xFFC0C6D4),
  ];

  static const _labels = {
    'felt': 'Cloth',
    'feltDark': 'Cloth shade',
    'woodDark': 'Rail shadow',
    'woodMid': 'Rail wood',
    'woodLight': 'Rail highlight',
    'accent': 'Brass trim',
  };

  @override
  Widget build(BuildContext context) {
    final t = BilliardThemes.byId('custom', custom: settings.customTheme);
    return Felt.backdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('My Table', style: Felt.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () {
                audio.click();
                settings.resetCustomColors();
              },
              child: Text('Reset',
                  style: Felt.label(13, theme: t, color: t.accentLight)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (_, _) {
              final active = settings.themeId == 'custom';
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Column(
                  children: [
                    // Live preview: mini table.
                    Container(
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: t.accent.withValues(alpha: 0.5), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Container(color: Color(settings.customColors['felt']!)),
                          Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF141414),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF5F2EA),
                                ),
                                alignment: Alignment.center,
                                child: const Text('8',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Felt.chip(
                      theme: t,
                      text: active ? '✓  Using My Table' : 'Use My Table',
                      selected: active,
                      onTap: () {
                        audio.click();
                        settings.setTheme('custom');
                      },
                    ),
                    const SizedBox(height: 12),
                    for (final key in _labels.keys)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Felt.card(
                          theme: t,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_labels[key]!,
                                  style: Felt.label(13, theme: t)),
                              const SizedBox(height: 8),
                              Wrap(
                                children: [
                                  for (final sw in _swatches)
                                    GestureDetector(
                                      onTap: () {
                                        audio.click();
                                        settings.setCustomColor(
                                            key, sw.toARGB32());
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: sw,
                                          border: Border.all(
                                            color: settings
                                                        .customColors[key] ==
                                                    sw.toARGB32()
                                                ? t.accentLight
                                                : Colors.white24,
                                            width: settings.customColors[
                                                        key] ==
                                                    sw.toARGB32()
                                                ? 3
                                                : 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
