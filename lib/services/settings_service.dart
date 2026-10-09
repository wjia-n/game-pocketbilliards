import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/billiards_themes.dart';

/// Persisted settings + stats for Pocket Billiards.
///
/// Player names are stored as ONE JSON string (`_kNamesJson`). Android's
/// SharedPreferences stores StringLists as an unordered StringSet, which
/// scrambles order on every restart — setStringList is never used for
/// ordered data. A one-time migration reads the legacy StringList key.
class BilliardSettings extends ChangeNotifier {
  static const _kMusic = 'pb_music_on';
  static const _kSfx = 'pb_sfx_on';
  static const _kVolume = 'pb_volume';
  static const _kMode = 'pb_mode'; // 0 = vs AI, 1 = pass-and-play
  static const _kDifficulty = 'pb_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNames = 'pb_player_names'; // legacy unordered StringList key
  static const _kNamesJsonLegacy =
      'pb_player_names_json'; // legacy JSON key (v1)
  static const _kNamesJson = 'pocketbilliards_player_names_json';
  static const _kTheme = 'pb_theme_id';
  static const _kBallStyle = 'pb_ball_style';
  static const _kCueStyle = 'pb_cue_style';
  static const _kWins = 'pb_wins';
  static const _kGames = 'pb_games_played';
  static const _kBestShots = 'pb_best_shots'; // fewest shots to win, 0 = none
  static const _kIsPro = 'pb_is_pro';
  static const _kCustomPrefix = 'pb_custom_';

  static const defaultNames = ['You', 'Shark AI'];

  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int mode = 0; // 0 = vs AI, 1 = pass-and-play (2 players)
  int difficulty = 1; // medium default
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int ballStyle = 0;
  int cueStyle = 0;
  int wins = 0;
  int gamesPlayed = 0;
  int bestShots = 0;
  bool isPro = false;

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'felt': 0xFF1E5B40,
    'feltDark': 0xFF14402E,
    'woodDark': 0xFF2A1708,
    'woodMid': 0xFF5A3618,
    'woodLight': 0xFF7D5228,
    'accent': 0xFFC9A227,
  };

  BilliardThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return BilliardThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      woodLight: c('woodLight'),
      accent: c('accent'),
      accentLight: const Color(0xFFE8CE7A),
      accentDark: const Color(0xFF8A6D1A),
      ivory: const Color(0xFFF5EFE0),
      felt: c('felt'),
      feltDark: c('feltDark'),
      cushionTop: c('felt'),
      pocket: const Color(0xFF0B0B0D),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    // Prefer the order-safe JSON key; fall back to the legacy JSON key once,
    // then the legacy StringList key once (one-time migration).
    final namesRaw = p.getString(_kNamesJson) ?? p.getString(_kNamesJsonLegacy);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    ballStyle = (p.getInt(_kBallStyle) ?? 0).clamp(0, BallStyles.names.length - 1);
    cueStyle = (p.getInt(_kCueStyle) ?? 0).clamp(0, CueStyles.names.length - 1);
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestShots = p.getInt(_kBestShots) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.remove(_kNamesJsonLegacy); // drop the legacy JSON key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBallStyle, ballStyle);
    await p.setInt(_kCueStyle, cueStyle);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestShots, bestShots);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || BilliardThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (CueStyles.isPro(cueStyle)) {
      cueStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return;
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 1) return; // hard mode is a Pro feature
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || BilliardThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.names.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setCueStyle(int v) async {
    v = v.clamp(0, CueStyles.names.length - 1);
    if (!isPro && CueStyles.isPro(v)) return;
    cueStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human (non-bot) player won.
  Future<void> recordGame({required bool humanWon, required int shots}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestShots == 0 || shots < bestShots) bestShots = shots;
    }
    notifyListeners();
    await _save();
  }
}
