import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';

/// Audio controls + player renaming.
class SettingsScreen extends StatefulWidget {
  final BilliardAudio audio;
  final BilliardSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BilliardThemeDef get _t => BilliardThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
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
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Felt.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  Felt.card(
                    theme: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sound', style: Felt.display(18, theme: t)),
                        const SizedBox(height: 6),
                        _Toggle(
                          theme: t,
                          label: 'Music',
                          value: s.musicOn,
                          onChanged: (v) {
                            widget.audio.click();
                            s.setMusic(v);
                            widget.audio.configure(
                              musicOn: s.musicOn,
                              sfxOn: s.sfxOn,
                              volume: s.volume,
                            );
                          },
                        ),
                        _Toggle(
                          theme: t,
                          label: 'Sound effects',
                          value: s.sfxOn,
                          onChanged: (v) {
                            widget.audio.click();
                            s.setSfx(v);
                            widget.audio.configure(
                              musicOn: s.musicOn,
                              sfxOn: s.sfxOn,
                              volume: s.volume,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text('Volume', style: Felt.label(13, theme: t)),
                        Slider(
                          value: s.volume,
                          activeColor: t.accentLight,
                          inactiveColor:
                              t.accent.withValues(alpha: 0.3),
                          onChanged: (v) {
                            s.setVolume(v);
                            widget.audio.configure(
                              musicOn: s.musicOn,
                              sfxOn: s.sfxOn,
                              volume: s.volume,
                            );
                          },
                          onChangeEnd: (_) => widget.audio.click(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Felt.card(
                    theme: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Players', style: Felt.display(18, theme: t)),
                        const SizedBox(height: 8),
                        for (int i = 0; i < 2; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FeltNameField(
                              key: ValueKey('sname$i'),
                              initial: s.playerNames[i],
                              hint: i == 0 ? 'Your name' : 'Rival name',
                              label: i == 0
                                  ? 'Player 1'
                                  : (s.mode == 0 ? 'AI rival' : 'Player 2'),
                              theme: t,
                              onCommit: (v) => s.setPlayerName(i, v),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final BilliardThemeDef theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(
      {required this.theme,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Felt.body(15, theme: theme))),
        Switch(
          value: value,
          activeThumbColor: theme.accentLight,
          activeTrackColor: theme.accent.withValues(alpha: 0.5),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
