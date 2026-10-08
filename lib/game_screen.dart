import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Pocket Billiards — casual 8-ball: rack 'em, claim a group, sink the 8.
class PocketBilliardsScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const PocketBilliardsScreen(
      {super.key, required this.players, required this.callbacks});

  @override
  State<PocketBilliardsScreen> createState() => _PocketBilliardsScreenState();
}

class _Ball {
  Offset p;
  Offset v = Offset.zero;
  final int n; // 0 = cue, 1-7 solids, 8 eight, 9-15 stripes
  bool active = true;
  _Ball(this.n, this.p);
  bool get isCue => n == 0;
  bool get isEight => n == 8;
  bool get isSolid => n >= 1 && n <= 7;
}

class _PocketBilliardsScreenState extends State<PocketBilliardsScreen>
    with SingleTickerProviderStateMixin {
  final rnd = Random();
  late Ticker _ticker;
  Duration _last = Duration.zero;

  final List<_Ball> balls = [];
  Size table = Size.zero;
  int turn = 0;
  bool over = false;
  bool rolling = false;
  bool breakShot = true;
  // group: -1 unassigned, 0 solids, 1 stripes — per player
  late List<int> group;
  Offset? dragPos;
  List<int> pottedThisShot = [];
  bool cuePotted = false;
  String msg = '';

  double get _br => 11; // ball radius px
  double get _pr => 20; // pocket radius px

  List<Offset> get _pockets => [
        Offset(_pr * 0.7, _pr * 0.7),
        Offset(table.width / 2, _pr * 0.55),
        Offset(table.width - _pr * 0.7, _pr * 0.7),
        Offset(_pr * 0.7, table.height - _pr * 0.7),
        Offset(table.width / 2, table.height - _pr * 0.55),
        Offset(table.width - _pr * 0.7, table.height - _pr * 0.7),
      ];

  @override
  void initState() {
    super.initState();
    group = List.filled(widget.players.length, -1);
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rack();
      _maybeBot();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _rack() {
    balls.clear();
    final w = table.width, h = table.height;
    balls.add(_Ball(0, Offset(w * 0.25, h * 0.5)));
    // triangle rack, apex at 0.68w
    final order = [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15];
    int k = 0;
    final dx = _br * 2.05, dy = _br * 2.02;
    for (int row = 0; row < 5; row++) {
      for (int i = 0; i <= row; i++) {
        balls.add(_Ball(order[k++],
            Offset(w * 0.68 + row * dx, h * 0.5 + (i - row / 2) * dy)));
      }
    }
    setState(() {
      msg = '${widget.players[0].name} to break! 💥';
    });
    widget.callbacks.setActivePlayer(0);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMilliseconds / 1000.0;
    _last = elapsed;
    if (!mounted || over || dt <= 0 || dt > 0.1 || !rolling) return;
    setState(() => _physics(dt));
    if (balls.every((b) => !b.active || b.v == Offset.zero)) {
      rolling = false;
      _resolveTurn();
    }
  }

  void _physics(double dt) {
    // move + friction
    for (final b in balls) {
      if (!b.active) continue;
      b.p += b.v * dt;
      b.v *= (1 - min(1.0, 1.1 * dt));
      if (b.v.distance < 9) b.v = Offset.zero;
    }
    // cushions
    for (final b in balls) {
      if (!b.active) continue;
      if (b.p.dx < _br || b.p.dx > table.width - _br) {
        b.v = Offset(-b.v.dx * 0.75, b.v.dy);
        b.p = Offset(b.p.dx.clamp(_br, table.width - _br), b.p.dy);
      }
      if (b.p.dy < _br || b.p.dy > table.height - _br) {
        b.v = Offset(b.v.dx, -b.v.dy * 0.75);
        b.p = Offset(b.p.dx, b.p.dy.clamp(_br, table.height - _br));
      }
    }
    // pockets
    for (final b in balls) {
      if (!b.active) continue;
      for (final pk in _pockets) {
        if ((b.p - pk).distance < _pr) {
          b.active = false;
          b.v = Offset.zero;
          if (b.isCue) {
            cuePotted = true;
          } else {
            pottedThisShot.add(b.n);
          }
          Sfx.tap();
          break;
        }
      }
    }
    // ball-ball collisions
    final act = balls.where((b) => b.active).toList();
    for (int i = 0; i < act.length; i++) {
      for (int j = i + 1; j < act.length; j++) {
        final a = act[i], c = act[j];
        final delta = c.p - a.p;
        final d = delta.distance;
        if (d < _br * 2 && d > 0.01) {
          final n = delta / d;
          final overlap = _br * 2 - d;
          a.p -= n * overlap / 2;
          c.p += n * overlap / 2;
          final rel = (a.v - c.v).dx * n.dx + (a.v - c.v).dy * n.dy;
          if (rel > 0) {
            final imp = n * rel * 0.96;
            a.v -= imp;
            c.v += imp;
          }
        }
      }
    }
  }

  _Ball get _cue => balls.firstWhere((b) => b.isCue);

  void _shoot(Offset dir, double power) {
    if (rolling || over || power < 20) return;
    setState(() {
      pottedThisShot = [];
      cuePotted = false;
      _cue.v = dir * power * 5.2;
      rolling = true;
      dragPos = null;
    });
    Sfx.move();
  }

  bool _groupCleared(int pi) {
    if (group[pi] == -1) return false;
    final wantSolid = group[pi] == 0;
    return !balls.any((b) => b.active && !b.isCue && !b.isEight && (b.isSolid == wantSolid));
  }

  void _resolveTurn() {
    final me = turn;
    final eightDown = pottedThisShot.contains(8);
    // re-spot cue if scratched
    if (cuePotted) {
      final c = _cue;
      c.active = true;
      c.p = Offset(table.width * 0.25, table.height * 0.5);
    }
    if (eightDown) {
      if (_groupCleared(me) || (breakShot && group[me] == -1)) {
        _endGame(me, 'sank the 8-ball! 🎱🏆');
      } else {
        final other = (me + 1) % widget.players.length;
        _endGame(other, '${widget.players[me].name} sank the 8-ball early! 😱');
      }
      return;
    }
    bool keepTurn = false;
    final mine = pottedThisShot.where((n) => n != 8).toList();
    if (group[me] == -1 && mine.isNotEmpty) {
      group[me] = mine.first <= 7 ? 0 : 1;
      final other = (me + 1) % widget.players.length;
      if (widget.players.length > 1) group[other] = 1 - group[me];
      keepTurn = true;
      msg = '${widget.players[me].name} claims ${group[me] == 0 ? 'SOLIDS 🔴' : 'STRIPES 🔵'}!';
    } else if (group[me] != -1) {
      final wantSolid = group[me] == 0;
      if (mine.any((n) => (n <= 7) == wantSolid)) {
        keepTurn = true;
      }
    }
    if (breakShot) breakShot = false;
    if (cuePotted) {
      keepTurn = false;
      msg = 'Scratch! Cue ball re-spotted. 😅';
    }
    widget.players[me].score += mine.length;
    widget.callbacks.refreshHud();
    if (!keepTurn) {
      turn = (turn + 1) % widget.players.length;
      widget.callbacks.setActivePlayer(turn);
    } else if (msg.isEmpty) {
      msg = 'Nice pot! Shoot again 🎯';
    }
    setState(() {});
    _maybeBot();
  }

  void _maybeBot() {
    if (over || rolling || !widget.players[turn].isBot) return;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || over || rolling || !widget.players[turn].isBot) return;
      _botShoot();
    });
  }

  void _botShoot() {
    final me = turn;
    final wantSolid = group[me] == 0;
    List<_Ball> targets = balls
        .where((b) =>
            b.active &&
            !b.isCue &&
            !b.isEight &&
            (group[me] == -1 || b.isSolid == wantSolid))
        .toList();
    if (targets.isEmpty) {
      // only the 8 left (or unassigned weirdness): go for the 8
      targets = balls.where((b) => b.active && b.isEight).toList();
    }
    if (targets.isEmpty) return;
    final cue = _cue;
    // pick target+nearest pocket
    _Ball? bestBall;
    Offset? bestPocket;
    double bestD = 1e9;
    for (final b in targets) {
      for (final pk in _pockets) {
        final d = (b.p - cue.p).distance + (b.p - pk).distance * 0.7;
        if (d < bestD) {
          bestD = d;
          bestBall = b;
          bestPocket = pk;
        }
      }
    }
    final tb = bestBall!, pk = bestPocket!;
    final toPocket = (pk - tb.p).distance < 1 ? const Offset(1, 0) : (pk - tb.p) / (pk - tb.p).distance;
    final ghost = tb.p - toPocket * _br * 2;
    var dir = (ghost - cue.p);
    dir = dir.distance < 1 ? const Offset(1, 0) : dir / dir.distance;
    // error
    final err = (rnd.nextDouble() - 0.5) * 0.10;
    final cosE = cos(err), sinE = sin(err);
    dir = Offset(dir.dx * cosE - dir.dy * sinE, dir.dx * sinE + dir.dy * cosE);
    final power = (140 + rnd.nextDouble() * 130).clamp(60.0, 230.0);
    _shoot(dir, power);
  }

  void _endGame(int winnerIdx, String how) {
    setState(() => over = true);
    final w = widget.players[winnerIdx];
    Sfx.win();
    widget.callbacks.finish(
      winner: w,
      headline: '${w.name} wins — $how',
      subline: 'Rack \'em again? 🎱',
    );
  }

  Color _ballColor(int n, GameTheme t) {
    if (n == 0) return t.text;
    final hue = (n * 47) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.65,
            t.dark ? 0.55 : 0.45)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final current = widget.players[turn];
    final humanTurn = !current.isBot && !rolling && !over;
    return Column(
      children: [
        if (!over)
          TurnBanner(
              player: current,
              action: current.isBot ? ' is lining up… 🤖' : ', your shot! 🎱'),
        _statusBar(t),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: LayoutBuilder(builder: (_, c) {
              table = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                onPanStart: (d) {
                  if (!humanTurn) return;
                  if ((_cue.p - d.localPosition).distance < 90) {
                    setState(() => dragPos = d.localPosition);
                  }
                },
                onPanUpdate: (d) {
                  if (dragPos == null || !humanTurn) return;
                  setState(() => dragPos = d.localPosition);
                },
                onPanEnd: (_) {
                  if (dragPos == null || !humanTurn) return;
                  final pull = _cue.p - dragPos!;
                  final power = pull.distance.clamp(0.0, 230.0);
                  final dir = pull.distance < 1
                      ? Offset.zero
                      : pull / pull.distance;
                  _shoot(dir, power);
                },
                child: CustomPaint(
                  painter: _TablePainter(
                    t: t,
                    balls: balls,
                    pockets: _pockets,
                    cue: _cue,
                    dragPos: humanTurn ? dragPos : null,
                    ballColor: _ballColor,
                    br: _br,
                    pr: _pr,
                  ),
                  child: Container(),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            over
                ? 'Game over! 🎉'
                : msg.isEmpty
                    ? (humanTurn
                        ? 'Pull back from the cue ball & release 🎯'
                        : '')
                    : msg,
            style: TextStyle(
                color: t.text, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _statusBar(GameTheme t) {
    String g(int i) =>
        group[i] == -1 ? '❓' : (group[i] == 0 ? '🔴 solids' : '🔵 stripes');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: t.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < widget.players.length; i++)
            Text('${widget.players[i].emoji} ${g(i)}',
                style: TextStyle(
                    color: i == turn ? t.accent : t.muted,
                    fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  final GameTheme t;
  final List<_Ball> balls;
  final List<Offset> pockets;
  final _Ball cue;
  final Offset? dragPos;
  final Color Function(int, GameTheme) ballColor;
  final double br, pr;

  _TablePainter({
    required this.t,
    required this.balls,
    required this.pockets,
    required this.cue,
    required this.dragPos,
    required this.ballColor,
    required this.br,
    required this.pr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // rails + felt
    canvas.drawRRect(
        RRect.fromLTRBR(0, 0, size.width, size.height,
            const Radius.circular(20)),
        Paint()..color = t.muted.withValues(alpha: 0.55));
    canvas.drawRRect(
        RRect.fromLTRBR(14, 14, size.width - 14, size.height - 14,
            const Radius.circular(14)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              t.primary.withValues(alpha: 0.5),
              t.primary.withValues(alpha: 0.3)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    // pockets
    for (final p in pockets) {
      canvas.drawCircle(p, pr, Paint()..color = t.background);
    }
    // cue stick + aim while dragging
    if (dragPos != null && cue.active) {
      final pull = (cue.p - dragPos!).distance.clamp(0.0, 230.0);
      final dir = pull < 1
          ? Offset.zero
          : (cue.p - dragPos!) / (cue.p - dragPos!).distance;
      if (dir != Offset.zero) {
        final aimPaint = Paint()
          ..color = t.text.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        var p = cue.p + dir * (br + 4);
        for (int i = 0; i < 6; i++) {
          canvas.drawCircle(p, 2.5, aimPaint);
          p += dir * 22;
        }
        // cue stick behind
        final stickPaint = Paint()
          ..color = t.secondary
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(cue.p - dir * (br + 10 + pull * 0.5),
            cue.p - dir * (br + 90 + pull * 0.5), stickPaint);
      }
    }
    // balls
    for (final b in balls) {
      if (!b.active) continue;
      final col = b.isEight ? t.background : ballColor(b.n, t);
      final isStripe = !b.isCue && !b.isEight && b.n > 8;
      if (isStripe) {
        canvas.drawCircle(
            b.p, br, Paint()..color = t.text.withValues(alpha: 0.95));
        canvas.drawRect(
            Rect.fromCenter(center: b.p, width: br * 2, height: br),
            Paint()..color = col);
      } else {
        canvas.drawCircle(b.p, br, Paint()..color = col);
      }
      if (!b.isCue) {
        canvas.drawCircle(
            b.p,
            br * 0.45,
            Paint()
              ..color =
                  isStripe ? col : t.text.withValues(alpha: 0.95));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TablePainter o) => true;
}
