import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';
import 'menu_screen.dart';

/// Single splash: game logo + name + animated loading line + credits.
class SplashScreen extends StatefulWidget {
  final BilliardAudio audio;
  final BilliardSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment: the official WAJIHA logo, shown first.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _companyDone = true);
    // Game splash: logo + name + animated loading line + credits.
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            MenuScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_companyDone) return const _CompanySplash();
    final theme = BilliardThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B08),
      body: Felt.backdrop(
        theme: theme,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 10),
                      blurRadius: 24,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/billiards_logo.png',
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 22),
              Text('Pocket Billiards', style: Felt.display(44, theme: theme)),
              const SizedBox(height: 6),
              Text(
                'RACK ’EM • CALL NOTHING • POT EVERYTHING',
                style: Felt.label(12, theme: theme),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: _loader,
                  builder: (_, _) => Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                              color: theme.accent.withValues(alpha: 0.5)),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loader.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [theme.accentLight, theme.accent],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _loader.value < 1
                            ? 'Chalking the cue…'
                            : 'Ready!',
                        style: Felt.body(13,
                            theme: theme,
                            color: theme.ivory.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/wajiha_logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text('Credits: WAJIHA',
                      style: Felt.label(14, theme: theme)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Company moment: the official WAJIHA logo (winged W mark), shown unchanged
/// for a beat before the game splash. Logo file is the byte-identical copy
/// of the official artwork — never redrawn or altered.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 170,
              height: 170,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            const Text(
              'W A J I H A',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: Color(0xFFE8CE7A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'presents',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 3,
                color: Color(0x99F5EFE0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
