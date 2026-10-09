import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural pool-hall audio — all sounds synthesized in code as WAV bytes.
/// Warm wood, ivory clack, leather pocket drop. No asset files.
///
/// Reliability design:
/// - Music clips are synthesized ONCE and cached.
/// - A [_musicGen] generation counter serializes track changes; the latest
///   request always wins — music never silently dies.
/// - Lifecycle uses pause()/resume() so interruptions resume in place.
/// - Every public method catches player errors; audio can never crash the app.
class BilliardAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  BilliardAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    this.volume = volume.clamp(0.0, 1.0);
    _music.setVolume(musicOn ? this.volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? this.volume : 0.0);
    if (!musicOn) stopMusic();
  }

  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02, double decay = 2.2}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, decay).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  // Warm jazzy parlor pad for the menu: Dm9 – G13 – Cmaj9 – A7, 16s loop.
  Uint8List _menuBytes() => _clip('music_menu', () {
        final seq = [
          [293.66, 349.23, 440.0, 523.25],
          [196.0, 246.94, 293.66, 392.0],
          [261.63, 329.63, 392.0, 493.88],
          [220.0, 277.18, 329.63, 415.30],
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.0));
        }
        return out;
      });

  // Mellow gameplay groove: low drone + lazy bluesy plucks, 12s loop.
  Uint8List _gameBytes() => _clip('music_game', () {
        final drone = _padChord([110.0, 164.81, 220.0], 12.0);
        final plucks = [
          329.63,
          392.0,
          440.0,
          493.88,
          440.0,
          392.0,
          349.23,
          293.66
        ];
        final n = (_rate * 12).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.45, harmonics: 0.4);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.32;
          }
        }
        return out;
      });

  // --------------------------------------------------------------- physical
  /// Cue-tip strike: short wooden tap with a leather-tip softness.
  List<double> _cueStrike() {
    final n = (_rate * 0.09).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004, decay: 3.2) *
          (0.7 * sin(2 * pi * 240 * t) * exp(-t * 60) +
              0.4 * sin(2 * pi * 480 * t) * exp(-t * 100) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 160));
    }
    return out;
  }

  /// Ball-to-ball clack: bright, hard, short.
  List<double> _clack() {
    final n = (_rate * 0.11).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.002, decay: 4.0) *
          (0.8 * sin(2 * pi * 2400 * t) * exp(-t * 90) +
              0.5 * sin(2 * pi * 3600 * t) * exp(-t * 130) +
              0.35 * (_rand.nextDouble() * 2 - 1) * exp(-t * 200));
    }
    return out;
  }

  /// Ball dropping into a pocket: wooden rattle + low thud.
  List<double> _pocketDrop() {
    final n = (_rate * 0.45).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final rattle = (_rand.nextDouble() * 2 - 1) * exp(-t * 22);
      out[i] = _env(i, n, attack: 0.004, decay: 1.8) *
          (0.55 * sin(2 * pi * 130 * t) * exp(-t * 14) +
              0.35 * sin(2 * pi * 260 * t) * exp(-t * 24) +
              0.28 * rattle);
    }
    return out;
  }

  /// Cushion bounce: dull rubber thud.
  List<double> _cushion() {
    final n = (_rate * 0.13).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.006, decay: 3.0) *
          (0.75 * sin(2 * pi * 150 * t) * exp(-t * 40) +
              0.25 * (_rand.nextDouble() * 2 - 1) * exp(-t * 120));
    }
    return out;
  }

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> cueHit() => _play(_clip('cue', _cueStrike));
  Future<void> ballClack() => _play(_clip('clack', _clack));
  Future<void> pocketDrop() => _play(_clip('pocket', _pocketDrop));
  Future<void> cushion() => _play(_clip('cushion', _cushion));
  Future<void> invalid() =>
      _play(_clip('invalid', () => _tone(150, 0.16, harmonics: 0.5)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> breakShot() => _play(
      _clip('break', () => _arp([196.0, 293.66, 392.0], 0.09, 0.02)));
  Future<void> pot() => _play(
      _clip('pot', () => _arp([523.25, 783.99], 0.12, 0.03)));
  Future<void> foul() => _play(
      _clip('foul', () => _arp([330.0, 220.0], 0.14, 0.05)));
  Future<void> win() => _play(_clip(
      'win', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.16, 0.03)));
  Future<void> lose() => _play(_clip(
      'lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
