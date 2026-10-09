import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pool table is wide: landscape gives the felt room to breathe.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final settings = BilliardSettings();
  await settings.load();
  final audio = BilliardAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(PocketBilliardsApp(settings: settings, audio: audio));
}

class PocketBilliardsApp extends StatefulWidget {
  final BilliardSettings settings;
  final BilliardAudio audio;
  const PocketBilliardsApp(
      {super.key, required this.settings, required this.audio});

  @override
  State<PocketBilliardsApp> createState() => _PocketBilliardsAppState();
}

class _PocketBilliardsAppState extends State<PocketBilliardsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the game screen additionally freezes its engine.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Pocket Billiards',
        debugShowCheckedModeBanner: false,
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
