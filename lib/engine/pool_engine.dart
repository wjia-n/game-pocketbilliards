import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Table geometry: canonical 100 x 50 units. All physics runs in these units.
// ---------------------------------------------------------------------------
const double tableW = 100.0;
const double tableH = 50.0;
const double ballR = 1.05;
const double pocketR = 2.5;
const double cushionRest = 0.72;

/// Pocket centers: 4 corners + 2 side middles.
const List<Offset> pockets = [
  Offset(0, 0),
  Offset(tableW, 0),
  Offset(0, tableH),
  Offset(tableW, tableH),
  Offset(tableW / 2, 0),
  Offset(tableW / 2, tableH),
];

bool isEight(int n) => n == 8;
bool isCue(int n) => n == 0;
bool isSolid(int n) => n >= 1 && n <= 7;
bool isStripe(int n) => n >= 9 && n <= 15;

/// 0 = solids, 1 = stripes, -1 = open table.
int groupOf(int n) {
  if (isSolid(n)) return 0;
  if (isStripe(n)) return 1;
  return -1;
}

// ---------------------------------------------------------------------------
class PoolBall {
  final int n;
  Offset p;
  Offset v = Offset.zero;
  bool active = true;

  PoolBall(this.n, this.p);

  double get speed => v.distance;
  bool get moving => active && speed > 0.5;
}

class PoolPlayer {
  String name;
  final bool isBot;
  PoolPlayer({required this.name, required this.isBot});
}

enum BotDifficulty { easy, medium, hard }

/// Turn phases owned entirely by the engine. The UI only renders.
/// aiming/ballInHand = human input; aiThinking = visible bot aim narration;
/// cueStrike = cue animation before the impulse lands; rolling = physics;
/// settling = brief beat between shots; over = terminal.
enum Phase { aiming, ballInHand, aiThinking, cueStrike, rolling, settling, over }

/// Sound hook: 'cue', 'clack', 'pocket', 'cushion'.
typedef EngineSfx = void Function(String kind);

/// The engine owns ALL turn state. Physics pumps on [pump()] from the UI
/// ticker; every phase transition runs on the engine's own single timer;
/// a watchdog recovers any phase found without a live timer — stuck states
/// are impossible by construction.
class PoolEngine extends ChangeNotifier {
  final List<PoolPlayer> players;
  final BotDifficulty botDifficulty;

  int turn = 0; // 0 or 1
  Phase phase = Phase.aiming;
  List<int> groups = [-1, -1]; // -1 open, 0 solids, 1 stripes
  bool breakShot = true;
  bool over = false;
  int? winner;

  final List<PoolBall> balls = [];
  String banner = '';
  int shotCount = 0; // shots this game (stats)

  // AI visible-aim data (rendered by the UI during aiThinking).
  Offset aiAimFrom = Offset.zero;
  Offset aiAimTo = Offset.zero;
  int aiAimBall = -1;

  // Human strike data (cue animation).
  Offset strikeDir = const Offset(1, 0);
  double strikePower = 0.0;
  double strikeT = 0.0;

  // Last shot summary for narration.
  final List<int> pottedThisShot = [];
  bool cuePottedThisShot = false;
  bool objectBallHit = false;

  EngineSfx? onSfx;
  final Random _rand;
  Timer? _timer;
  Timer? _watchdog;
  bool _disposed = false;
  bool paused = false;
  DateTime _strikeStarted = DateTime.now();

  static const double _dt = 1 / 120;
  static const double _friction = 0.62; // speed factor per second
  static const double _stopSpeed = 1.2;

  PoolEngine({
    required this.players,
    this.botDifficulty = BotDifficulty.medium,
    Random? rand,
  }) : _rand = rand ?? Random() {
    _rack();
    banner = '${players[0].name} — break shot! Drag back to shoot.';
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    _afterPhase();
  }

  PoolPlayer get current => players[turn];
  PoolBall get cue =>
      balls.firstWhere((b) => b.n == 0, orElse: () => PoolBall(0, const Offset(25, 25)));

  // ------------------------------------------------------------ rack setup
  void _rack() {
    balls.clear();
    balls.add(PoolBall(0, const Offset(25, 25)));
    // Triangle rack, apex at (75, 25), 8-ball in the middle.
    const apex = Offset(75, 25);
    final dx = ballR * 2 * 0.92;
    final dy = ballR * 2 * 1.02;
    final order = _rackOrder();
    int i = 0;
    for (int row = 0; row < 5; row++) {
      for (int k = 0; k <= row; k++) {
        final p = Offset(
          apex.dx + row * dx,
          apex.dy + (k - row / 2) * dy,
        );
        balls.add(PoolBall(order[i++], p));
      }
    }
  }

  List<int> _rackOrder() {
    // 8 in the middle (index 4); corners one solid + one stripe; rest mixed.
    final rest = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
      ..shuffle(_rand);
    final order = <int>[rest[0], rest[1], rest[2], rest[3], 8];
    order.addAll(rest.sublist(4));
    // Guarantee opposite corners: force index 0 solid, index 14 stripe.
    if (isStripe(order[0])) {
      final s = order.indexWhere(isSolid);
      final tmp = order[0];
      order[0] = order[s];
      order[s] = tmp;
    }
    if (isSolid(order[14])) {
      final s = order.indexWhere(isStripe);
      final tmp = order[14];
      order[14] = order[s];
      order[s] = tmp;
    }
    return order;
  }

  // ------------------------------------------------------------- lifecycle
  void _arm(Duration d, void Function() fn) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (_disposed) return;
      if (paused) {
        // Paused mid-transition: re-arm instead of dropping the transition —
        // a pause during the settle window must not eat the shot resolution.
        _arm(d, fn);
        return;
      }
      fn();
    });
  }

  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    switch (phase) {
      case Phase.cueStrike:
        _applyStrike(); // strike animation lost its timer: fire it
      case Phase.aiThinking:
        _startAiThinking(); // AI never started: restart it
      case Phase.rolling:
        // Ticker lost its beat with everything stopped: settle the shot.
        if (!balls.any((b) => b.moving)) {
          phase = Phase.settling;
          notifyListeners();
          _finishShot();
        }
      case Phase.settling:
        _finishShot(); // phase-guarded; resolves the shot, then advances
      case Phase.aiming:
        if (current.isBot) {
          _startAiThinking();
        } else if (!cue.active) {
          phase = Phase.ballInHand;
          banner = 'Foul — place the cue ball, ${current.name}.';
          notifyListeners();
        }
      case Phase.ballInHand:
        if (!current.isBot && !cue.active) _respawnCue();
      case Phase.over:
        break;
    }
  }

  void setPaused(bool v) {
    paused = v;
    if (!v) _recover(); // resumed: make sure nothing is stranded
    notifyListeners();
  }

  // ----------------------------------------------------------------- input
  /// Human releases a pull-back shot. [dir] unit vector, [power] 0..1.
  /// Silently ignored unless the human is aiming — impossible states can't
  /// be forced from the UI.
  void shoot(Offset dir, double power) {
    if (over || paused) return;
    if (phase != Phase.aiming || current.isBot) return;
    if (dir == Offset.zero) return;
    if (!cue.active) return;
    strikeDir = dir / dir.distance;
    strikePower = power.clamp(0.08, 1.0);
    strikeT = 0.0;
    phase = Phase.cueStrike;
    _strikeStarted = DateTime.now();
    banner = '${current.name} shoots…';
    onSfx?.call('cue');
    notifyListeners();
    _arm(const Duration(milliseconds: 320), _applyStrike);
  }

  void _applyStrike() {
    if (phase != Phase.cueStrike || _disposed || paused) return;
    final speed = 60 + strikePower * 240;
    cue.v = strikeDir * speed;
    shotCount++;
    pottedThisShot.clear();
    cuePottedThisShot = false;
    objectBallHit = false;
    phase = Phase.rolling;
    notifyListeners();
  }

  /// Ball-in-hand placement. Returns true if the spot is legal.
  bool placeCue(Offset p) {
    if (phase != Phase.ballInHand || current.isBot || paused) return false;
    if (!_spotFree(p)) return false;
    _respawnCue(p);
    phase = Phase.aiming;
    banner = 'Drag back to shoot, ${current.name}.';
    notifyListeners();
    return true;
  }

  bool _spotFree(Offset p) {
    if (p.dx < ballR || p.dx > tableW - ballR) return false;
    if (p.dy < ballR || p.dy > tableH - ballR) return false;
    for (final pk in pockets) {
      if ((p - pk).distance < pocketR + ballR) return false;
    }
    for (final b in balls) {
      if (b.active && !isCue(b.n) && (b.p - p).distance < ballR * 2.05) {
        return false;
      }
    }
    return true;
  }

  void _respawnCue([Offset? at]) {
    final c = balls.firstWhere((b) => b.n == 0);
    c.active = true;
    c.v = Offset.zero;
    c.p = at ?? const Offset(25, 25);
  }

  // --------------------------------------------------------------- physics
  /// Advance the simulation one frame. Called by the UI ticker.
  void pump() {
    if (paused || _disposed || over) return;
    if (phase == Phase.cueStrike) {
      strikeT = DateTime.now()
              .difference(_strikeStarted)
              .inMilliseconds /
          320.0;
      notifyListeners();
      return;
    }
    if (phase != Phase.rolling) return;
    for (int s = 0; s < 2; s++) {
      _step(_dt / 2);
    }
    if (!balls.any((b) => b.moving)) {
      for (final b in balls) {
        b.v = Offset.zero;
      }
      phase = Phase.settling;
      notifyListeners();
      _arm(const Duration(milliseconds: 650), _finishShot);
    } else {
      notifyListeners();
    }
  }

  void _step(double dt) {
    final f = pow(_friction, dt).toDouble();
    for (final b in balls) {
      if (!b.active) continue;
      if (b.v == Offset.zero) continue;
      b.v *= f;
      if (b.speed < _stopSpeed) b.v = Offset.zero;
      b.p += b.v * dt;
      // Pockets first: capture before cushions can bounce off corners.
      bool sunk = false;
      for (final pk in pockets) {
        if ((b.p - pk).distance < pocketR) {
          _sink(b);
          sunk = true;
          break;
        }
      }
      if (sunk || !b.active) continue;
      // Cushions.
      final r = ballR;
      if (b.p.dx < r) {
        b.p = Offset(r, b.p.dy);
        _bounce(b, const Offset(1, 0));
      } else if (b.p.dx > tableW - r) {
        b.p = Offset(tableW - r, b.p.dy);
        _bounce(b, const Offset(-1, 0));
      }
      if (b.p.dy < r) {
        b.p = Offset(b.p.dx, r);
        _bounce(b, const Offset(0, 1));
      } else if (b.p.dy > tableH - r) {
        b.p = Offset(b.p.dx, tableH - r);
        _bounce(b, const Offset(0, -1));
      }
    }
    // Ball-ball collisions.
    final act = balls.where((b) => b.active).toList();
    for (int i = 0; i < act.length; i++) {
      for (int j = i + 1; j < act.length; j++) {
        _collide(act[i], act[j]);
      }
    }
  }

  void _bounce(PoolBall b, Offset normal) {
    final vn = b.v.dx * normal.dx + b.v.dy * normal.dy;
    if (vn >= 0) return;
    final v = b.v - normal * (vn * (1 + cushionRest));
    b.v = v;
    if (vn.abs() > 25) onSfx?.call('cushion');
  }

  void _collide(PoolBall a, PoolBall b) {
    final d = b.p - a.p;
    final dist = d.distance;
    final minD = ballR * 2;
    if (dist >= minD || dist == 0) return;
    final n = d / dist;
    // Separate overlap.
    final overlap = (minD - dist) / 2;
    a.p -= n * overlap;
    b.p += n * overlap;
    // Equal-mass elastic collision along the normal.
    final rel = (b.v - a.v);
    final vn = rel.dx * n.dx + rel.dy * n.dy;
    if (vn >= 0) return;
    const rest = 0.96;
    final impulse = -(1 + rest) * vn / 2;
    a.v -= n * impulse;
    b.v += n * impulse;
    if (!isCue(a.n) || !isCue(b.n)) objectBallHit = true;
    if (vn.abs() > 18) onSfx?.call('clack');
  }

  void _sink(PoolBall b) {
    b.active = false;
    b.v = Offset.zero;
    if (isCue(b.n)) {
      cuePottedThisShot = true;
    } else {
      pottedThisShot.add(b.n);
    }
    onSfx?.call('pocket');
    notifyListeners();
  }

  // ----------------------------------------------------------- shot rules
  void _finishShot() {
    if (phase != Phase.settling || _disposed) return;
    final shooter = turn;
    final foul = cuePottedThisShot || !objectBallHit;

    // --- 8-ball outcomes first.
    if (pottedThisShot.contains(8)) {
      final cleared = _groupCleared(shooter);
      if (cleared && !foul) {
        _endGame(shooter, '${current.name} sinks the 8 — wins!');
      } else {
        final loser = shooter;
        final winBy = 1 - shooter;
        _endGame(winBy,
            'Early 8-ball! ${players[loser].name} loses — ${players[winBy].name} wins!');
      }
      return;
    }

    // --- group assignment on open table.
    if (groups[shooter] == -1 && !foul) {
      for (final n in pottedThisShot) {
        final g = groupOf(n);
        if (g != -1) {
          groups[shooter] = g;
          groups[1 - shooter] = 1 - g;
          banner =
              '${players[shooter].name} claims ${g == 0 ? 'solids' : 'stripes'}!';
          break;
        }
      }
    }

    final ownPotted = pottedThisShot
        .where((n) => groups[shooter] != -1 && groupOf(n) == groups[shooter])
        .isNotEmpty;

    breakShot = false;

    if (cuePottedThisShot) {
      // Scratch: cue comes back in hand for the incoming player.
      _respawnCue();
      cue.active = false;
      turn = 1 - shooter;
      phase = current.isBot ? Phase.aiming : Phase.ballInHand;
      if (current.isBot) _respawnCue();
      banner = 'Scratch! Foul — ${current.name} has ball in hand.';
      notifyListeners();
      _afterPhase();
      return;
    }

    if (foul) {
      turn = 1 - shooter;
      banner = 'Foul — no ball hit. ${current.name}\'s turn.';
    } else if (ownPotted ||
        (groups[shooter] == -1 && pottedThisShot.isNotEmpty)) {
      // Keep shooting.
      turn = shooter;
      banner = 'Nice pot, ${current.name} — shoot again!';
    } else {
      turn = 1 - shooter;
      banner = '${current.name}\'s turn.';
    }
    phase = Phase.aiming;
    notifyListeners();
    _afterPhase();
  }

  bool _groupCleared(int pi) {
    final g = groups[pi];
    if (g == -1) return false;
    return !balls.any((b) =>
        b.active && !isCue(b.n) && !isEight(b.n) && groupOf(b.n) == g);
  }

  /// Balls the shooter may legally hit first.
  List<PoolBall> legalTargets(int pi) {
    final g = groups[pi];
    if (g == -1) {
      return balls
          .where((b) => b.active && !isCue(b.n) && !isEight(b.n))
          .toList();
    }
    if (_groupCleared(pi)) {
      return balls.where((b) => b.active && isEight(b.n)).toList();
    }
    return balls
        .where(
            (b) => b.active && !isCue(b.n) && !isEight(b.n) && groupOf(b.n) == g)
        .toList();
  }

  void _endGame(int winnerIdx, String message) {
    over = true;
    winner = winnerIdx;
    phase = Phase.over;
    banner = message;
    notifyListeners();
  }

  void _afterPhase() {
    if (_disposed || over || paused) return;
    if (current.isBot && (phase == Phase.aiming || phase == Phase.ballInHand)) {
      _startAiThinking();
    }
  }

  // ------------------------------------------------------------------- AI
  /// Visible AI turn: narration + animated aim line, then a real strike.
  /// Never silent — the player always sees what the bot is doing.
  void _startAiThinking() {
    if (_disposed || over || paused || !current.isBot) return;
    if (phase == Phase.aiThinking) return;
    if (phase == Phase.ballInHand) _respawnCue();
    phase = Phase.aiThinking;
    banner = '🤖 ${current.name} is lining up the shot…';
    _computeAiShot();
    notifyListeners();
    final ms = switch (botDifficulty) {
      BotDifficulty.easy => 1500,
      BotDifficulty.medium => 1900,
      BotDifficulty.hard => 2400,
    };
    _arm(Duration(milliseconds: ms), _aiStrike);
  }

  void _aiStrike() {
    if (_disposed || over || paused) return;
    if (phase != Phase.aiThinking) return;
    banner = '🤖 ${current.name} shoots!';
    onSfx?.call('cue');
    final dir = aiAimTo - aiAimFrom;
    if (dir == Offset.zero || !cue.active) {
      // Degenerate aim — nudge and continue rather than stall.
      phase = Phase.aiming;
      _recover();
      return;
    }
    strikeDir = dir / dir.distance;
    strikePower = _aiPower;
    strikeT = 0.0;
    phase = Phase.cueStrike;
    _strikeStarted = DateTime.now();
    notifyListeners();
    _arm(const Duration(milliseconds: 320), _applyStrike);
  }

  double _aiPower = 0.4;

  void _computeAiShot() {
    final c = cue;
    aiAimFrom = c.p;
    final targets = legalTargets(turn);
    if (targets.isEmpty || !c.active) {
      aiAimTo = c.p + const Offset(10, 0);
      _aiPower = 0.2;
      return;
    }
    // Score each target by travel distance: ball→nearest pocket + cue→ball.
    PoolBall? best;
    Offset bestPocket = pockets.first;
    double bestScore = double.infinity;
    for (final t in targets) {
      for (final pk in pockets) {
        final d1 = (t.p - pk).distance;
        final d2 = (c.p - t.p).distance;
        final s = d1 * 1.2 + d2;
        if (s < bestScore) {
          bestScore = s;
          best = t;
          bestPocket = pk;
        }
      }
    }
    final target = best!;
    aiAimBall = target.n;
    // Ghost-ball: aim the cue ball at the point that sends [target] at the
    // pocket.
    final toPocket = (bestPocket - target.p);
    final ghost = target.p - (toPocket / toPocket.distance) * ballR * 2;
    // Difficulty = aim noise. Easy also sometimes picks a silly pocket ball.
    final noiseDeg = switch (botDifficulty) {
      BotDifficulty.easy => 9.0,
      BotDifficulty.medium => 3.5,
      BotDifficulty.hard => 1.2,
    };
    if (botDifficulty == BotDifficulty.easy && _rand.nextDouble() < 0.18) {
      // Occasionally goes for a wrong ball entirely — very beatable.
      final others = balls
          .where((b) => b.active && !isCue(b.n) && b.n != target.n)
          .toList();
      if (others.isNotEmpty) {
        final wrong = others[_rand.nextInt(others.length)];
        aiAimTo = wrong.p;
        aiAimBall = wrong.n;
        _aiPower = 0.25 + _rand.nextDouble() * 0.3;
        return;
      }
    }
    final aim = ghost - c.p;
    final ang = atan2(aim.dy, aim.dx) +
        _rand.nextDouble() * 2 * noiseDeg * pi / 180 -
        noiseDeg * pi / 180;
    final dist = aim.distance;
    aiAimTo = c.p + Offset(cos(ang), sin(ang)) * (dist + 20);
    final base = switch (botDifficulty) {
      BotDifficulty.easy => 0.35,
      BotDifficulty.medium => 0.45,
      BotDifficulty.hard => 0.55,
    };
    _aiPower = (base + dist / tableW * 0.55).clamp(0.15, 0.95);
  }

  // ---------------------------------------------------------- test hooks
  @visibleForTesting
  void testApplyStrike() => _applyStrike();

  @visibleForTesting
  void testSettleNow() {
    phase = Phase.settling;
    _finishShot();
  }

  @visibleForTesting
  void testSink(int n) {
    final b = balls.firstWhere((bb) => bb.n == n);
    _sink(b);
  }

  @visibleForTesting
  void testClearGroup(int pi) {
    final g = groups[pi];
    for (final b in balls) {
      if (!isCue(b.n) && !isEight(b.n) && (g == -1 || groupOf(b.n) == g)) {
        if (g != -1 && pi == 0 && groupOf(b.n) != g) continue;
        b.active = false;
      }
    }
  }

  // ----------------------------------------------------------------- util
  /// Remaining balls per player for the score cards.
  int remainingFor(int pi) {
    final g = groups[pi];
    if (g == -1) return -1; // open table
    return balls
        .where((b) =>
            b.active && !isCue(b.n) && !isEight(b.n) && groupOf(b.n) == g)
        .length;
  }

  void restart() {
    _timer?.cancel();
    _timer = null;
    turn = 0;
    phase = Phase.aiming;
    groups = [-1, -1];
    breakShot = true;
    over = false;
    winner = null;
    shotCount = 0;
    pottedThisShot.clear();
    cuePottedThisShot = false;
    _rack();
    banner = '${players[0].name} — break shot! Drag back to shoot.';
    notifyListeners();
    _afterPhase();
  }

  void disposeEngine() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
