import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/pool_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: logo, PLAY, mode setup (vs AI / pass-and-play, 3 difficulties),
/// player renaming, table themes, ball/cue styles, tip jar, settings.
class MenuScreen extends StatefulWidget {
  final BilliardAudio audio;
  final BilliardSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  BilliardSettings get _s => widget.settings;
  BilliardThemeDef get _t =>
      BilliardThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Felt.body(15, theme: _t)),
        backgroundColor: _t.woodDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {}
  }

  void _play() {
    widget.audio.gameStart();
    final vsAi = _s.mode == 0;
    final players = [
      PoolPlayer(name: _s.playerNames[0], isBot: false),
      PoolPlayer(
          name: _s.playerNames[1],
          isBot: vsAi), // pass-and-play: both human
    ];
    final engine = PoolEngine(
      players: players,
      botDifficulty: BotDifficulty.values[_s.difficulty],
    );
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Felt.backdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/billiards_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Pocket Billiards', style: Felt.display(40, theme: t)),
                  Text(
                    'SMOOTH 8-BALL • REAL PHYSICS',
                    style: Felt.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  FeltButton(
                      label: '🎱  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border:
                            Border.all(color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _s.isPro ? '✦  PRO ACTIVE' : '✦  Get PRO',
                        style: Felt.label(17, theme: t, color: t.woodDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t, settings: _s, audio: widget.audio),
                  const SizedBox(height: 14),
                  _ThemeCard(theme: t, settings: _s, audio: widget.audio),
                  const SizedBox(height: 14),
                  _NamesCard(theme: t, settings: _s, audio: widget.audio),
                  const SizedBox(height: 14),
                  _AppearanceCard(
                      theme: t, settings: _s, audio: widget.audio),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await Share.share(
                              'Rack ’em up — play Pocket Billiards with me! https://play.google.com/store/apps/details?id=com.gameswajiha.pocketbilliards');
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Wins: ${_s.wins}   •   Games: ${_s.gamesPlayed}${_s.bestShots > 0 ? '   •   Best: ${_s.bestShots} shots' : ''}',
                      style: Felt.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Felt.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, BilliardThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Felt.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Drag BACK anywhere on the felt to aim — release to shoot. Longer pull = harder hit.',
                  '• Break the rack, then pot a ball to claim solids or stripes.',
                  '• Pot one of your group to keep shooting; miss and the turn passes.',
                  '• Clear your group, then sink the 8-ball to win. Early 8 = instant loss!',
                  '• Scratch (cue ball potted) = foul: your rival gets ball in hand.',
                  '• No ball hit at all = foul, turn passes.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Felt.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: FeltButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final BilliardThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.woodMid, theme.woodDark],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Felt.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Mode setup: vs AI (3 difficulties) or 2-player pass-and-play.
class _ModeCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final BilliardSettings settings;
  final BilliardAudio audio;
  const _ModeCard(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Felt.card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Game Mode', style: Felt.display(18, theme: theme)),
          const SizedBox(height: 10),
          Wrap(
            children: [
              Felt.chip(
                theme: theme,
                text: '🤖 Vs AI',
                selected: settings.mode == 0,
                onTap: () {
                  audio.click();
                  settings.setMode(0);
                },
              ),
              Felt.chip(
                theme: theme,
                text: '👥 Pass & Play',
                selected: settings.mode == 1,
                onTap: () {
                  audio.click();
                  settings.setMode(1);
                },
              ),
            ],
          ),
          if (settings.mode == 0) ...[
            const SizedBox(height: 8),
            Text('AI Difficulty', style: Felt.label(13, theme: theme)),
            const SizedBox(height: 4),
            Wrap(
              children: [
                for (int i = 0; i < 3; i++)
                  Felt.chip(
                    theme: theme,
                    text: ['Easy', 'Medium', 'Hard'][i],
                    selected: settings.difficulty == i,
                    locked: i == 2 && !settings.isPro,
                    onTap: () {
                      audio.click();
                      settings.setDifficulty(i);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Theme picker grid.
class _ThemeCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final BilliardSettings settings;
  final BilliardAudio audio;
  const _ThemeCard(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Felt.card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Table Theme', style: Felt.display(18, theme: theme)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  audio.click();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                        audio: audio, settings: settings),
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: theme.accent.withValues(alpha: 0.6)),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Text(
                    settings.isPro
                        ? '🎨 Create My Own'
                        : '🎨 Create My Own 🔒',
                    style: Felt.label(12, theme: theme),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemCount: BilliardThemes.all.length,
            itemBuilder: (_, i) {
              final td = BilliardThemes.all[i];
              final selected = settings.themeId == td.id;
              final locked =
                  !settings.isPro && BilliardThemes.isProTheme(td.id);
              return GestureDetector(
                onTap: () {
                  audio.click();
                  settings.setTheme(td.id);
                },
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? theme.accentLight
                              : theme.accent.withValues(alpha: 0.35),
                          width: selected ? 3 : 1.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [td.felt, td.woodMid],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          locked ? '🔒' : (selected ? '✓' : ''),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      td.name,
                      style: Felt.body(9, theme: theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Renameable player seats.
class _NamesCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final BilliardSettings settings;
  final BilliardAudio audio;
  const _NamesCard(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    final vsAi = settings.mode == 0;
    return Felt.card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Players', style: Felt.display(18, theme: theme)),
          const SizedBox(height: 10),
          for (int i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(
                          color: theme.accent.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i == 0 ? '🎱' : (vsAi ? '🤖' : '🎯'),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FeltNameField(
                      key: ValueKey('name$i'),
                      initial: settings.playerNames[i],
                      hint: i == 0 ? 'Your name' : 'Rival name',
                      label: i == 0
                          ? 'Player 1'
                          : (vsAi ? 'AI rival' : 'Player 2'),
                      theme: theme,
                      onCommit: (v) => settings.setPlayerName(i, v),
                    ),
                  ),
                  if (i == 1 && vsAi)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('BOT',
                          style: Felt.label(11,
                              theme: theme, color: theme.accentLight)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Appearance: ball set + cue stick finishes.
class _AppearanceCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final BilliardSettings settings;
  final BilliardAudio audio;
  const _AppearanceCard(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Felt.card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ball Set', style: Felt.display(18, theme: theme)),
          const SizedBox(height: 8),
          Wrap(
            children: [
              for (int i = 0; i < BallStyles.names.length; i++)
                Felt.chip(
                  theme: theme,
                  text: BallStyles.names[i],
                  selected: settings.ballStyle == i,
                  locked:
                      !settings.isPro && BallStyles.isPro(i),
                  onTap: () {
                    audio.click();
                    settings.setBallStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Cue Stick', style: Felt.display(18, theme: theme)),
          const SizedBox(height: 8),
          Wrap(
            children: [
              for (int i = 0; i < CueStyles.names.length; i++)
                Felt.chip(
                  theme: theme,
                  text: CueStyles.names[i],
                  selected: settings.cueStyle == i,
                  locked: !settings.isPro && CueStyles.isPro(i),
                  onTap: () {
                    audio.click();
                    settings.setCueStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
