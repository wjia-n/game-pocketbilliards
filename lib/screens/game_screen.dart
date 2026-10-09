import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/pool_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/billiards_themes.dart';
import '../theme/felt_ui.dart';

/// Landscape pool table screen. The engine owns all phases; this widget only
/// renders and forwards input.
///
/// Human aiming: touch and DRAG anywhere on the felt — the cue ball shoots
/// AWAY from your finger (pull-back style). Drag further = more power.
/// Release to shoot. The aim line + power meter preview the shot live.
class GameScreen extends StatefulWidget {
  final PoolEngine engine;
  final BilliardAudio audio;
  final BilliardSettings settings;

  const GameScreen(
      {super.key,
      required this.engine,
      required this.audio,
      required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _overHandled = false;
  Offset? _dragPos; // current finger pos in table units
  Offset? _dragStart;
  bool _paused = false;

  PoolEngine get _e => widget.engine;
  BilliardThemeDef get _t => BilliardThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.audio.startGameMusic();
    _e.onSfx = _onEngineSfx;
    _e.addListener(_onEngineChanged);
    _ticker = createTicker((_) => _e.pump())..start();
  }

  void _onEngineSfx(String kind) {
    switch (kind) {
      case 'cue':
        widget.audio.cueHit();
      case 'clack':
        widget.audio.ballClack();
      case 'pocket':
        widget.audio.pocketDrop();
      case 'cushion':
        widget.audio.cushion();
    }
  }

  void _onEngineChanged() {
    if (_e.over && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
    if (mounted) setState(() {});
  }

  Future<void> _onGameOver() async {
    final humanWon = !_e.players[_e.winner ?? 0].isBot;
    await widget.settings.recordGame(
        humanWon: humanWon, shots: _e.shotCount);
    if (humanWon) {
      widget.audio.win();
    } else {
      widget.audio.lose();
    }
    // Sensible review moment: a human just won, a few games in.
    if (humanWon && widget.settings.gamesPlayed >= 2) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _e.removeListener(_onEngineChanged);
    _e.disposeEngine();
    super.dispose();
  }

  Future<void> _pauseGame() async {
    widget.audio.click();
    setState(() => _paused = true);
    _e.setPaused(true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        theme: _t,
        audio: widget.audio,
        onResume: () {
          Navigator.of(context).pop();
          setState(() => _paused = false);
          _e.setPaused(false);
        },
        onRestart: () {
          Navigator.of(context).pop();
          setState(() {
            _overHandled = false;
            _paused = false;
          });
          _e.restart();
          _e.setPaused(false);
          widget.audio.gameStart();
        },
        onQuit: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
    // Dialog dismissed by any path: make sure we are unpaused on return.
    if (_paused && mounted) {
      setState(() => _paused = false);
      _e.setPaused(false);
    }
  }

  // ------------------------------------------------------------- aim input
  /// Convert a global touch point into table units.
  Offset? _toTableUnits(Offset global, BoxConstraints c) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(global);
    // The table canvas fills the available space; recompute the same layout
    // as the painter: fit 100x50 + rail margin into the box.
    const margin = 14.0;
    final avail = Size(c.maxWidth - margin * 2, c.maxHeight - margin * 2);
    final scale = min(avail.width / 112, avail.height / 62);
    final tablePx = Size(112 * scale, 62 * scale);
    final origin = Offset(
      (c.maxWidth - tablePx.width) / 2 + 6 * scale,
      (c.maxHeight - tablePx.height) / 2 + 6 * scale,
    );
    return Offset((local.dx - origin.dx) / scale, (local.dy - origin.dy) / scale);
  }

  void _onPanStart(DragStartDetails d, BoxConstraints c) {
    if (_e.phase == Phase.ballInHand &&
        !_e.current.isBot &&
        !_e.paused &&
        !_e.over) {
      final u = _toTableUnits(d.globalPosition, c);
      if (u == null) return;
      final ok = _e.placeCue(u);
      if (!ok) widget.audio.invalid();
      return;
    }
    if (_e.phase != Phase.aiming || _e.current.isBot || _e.paused || _e.over) {
      return;
    }
    _dragStart = _toTableUnits(d.globalPosition, c);
    _dragPos = _dragStart;
  }

  void _onPanUpdate(DragUpdateDetails d, BoxConstraints c) {
    if (_dragStart == null) return;
    _dragPos = _toTableUnits(d.globalPosition, c);
  }

  void _onPanEnd(BoxConstraints c) {
    if (_dragStart == null || _dragPos == null) {
      _dragStart = _dragPos = null;
      return;
    }
    final cue = _e.cue;
    if (!cue.active) {
      _dragStart = _dragPos = null;
      return;
    }
    final pull = cue.p - _dragPos!;
    final dist = pull.distance;
    if (dist > 4) {
      final dir = pull / dist;
      final power = (dist / 40).clamp(0.12, 1.0);
      _e.shoot(dir, power);
      if (_e.breakShot) widget.audio.breakShot();
    }
    _dragStart = _dragPos = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Felt.backdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                theme: t,
                engine: _e,
                settings: widget.settings,
                onPause: _pauseGame,
                onRestart: () {
                  widget.audio.click();
                  setState(() => _overHandled = false);
                  _e.restart();
                },
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, c) => GestureDetector(
                    onPanStart: (d) => _onPanStart(d, c),
                    onPanUpdate: (d) => _onPanUpdate(d, c),
                    onPanEnd: (_) => _onPanEnd(c),
                    onTapUp: (d) {
                      // Tap = quick place in ball-in-hand mode.
                      if (_e.phase == Phase.ballInHand && !_e.current.isBot) {
                        final u = _toTableUnits(d.globalPosition, c);
                        if (u != null && !_e.placeCue(u)) {
                          widget.audio.invalid();
                        }
                      }
                    },
                    child: CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _TablePainter(
                        engine: _e,
                        theme: t,
                        ballStyle: widget.settings.ballStyle,
                        cueStyle: widget.settings.cueStyle,
                        dragPos: _dragPos,
                      ),
                    ),
                  ),
                ),
              ),
              _BottomBar(theme: t, engine: _e),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar
class _TopBar extends StatelessWidget {
  final BilliardThemeDef theme;
  final PoolEngine engine;
  final BilliardSettings settings;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  const _TopBar(
      {required this.theme,
      required this.engine,
      required this.settings,
      required this.onPause,
      required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _PlayerCard(theme: theme, engine: engine, seat: 0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                engine.banner,
                style: Felt.body(12, theme: theme),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _PlayerCard(theme: theme, engine: engine, seat: 1),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.accentLight),
            tooltip: 'Restart',
            onPressed: onRestart,
          ),
          IconButton(
            icon: Icon(Icons.pause, color: theme.accentLight),
            tooltip: 'Pause',
            onPressed: onPause,
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final BilliardThemeDef theme;
  final PoolEngine engine;
  final int seat;
  const _PlayerCard(
      {required this.theme, required this.engine, required this.seat});

  @override
  Widget build(BuildContext context) {
    final p = engine.players[seat];
    final active = engine.turn == seat && !engine.over;
    final g = engine.groups[seat];
    final rem = engine.remainingFor(seat);
    final label = g == -1
        ? (engine.breakShot ? 'break' : 'open')
        : g == 0
            ? 'solids'
            : 'stripes';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? theme.accent.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.35),
        border: Border.all(
            color: active ? theme.accentLight : theme.accent.withValues(alpha: 0.4),
            width: active ? 2 : 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.isBot) const Text('🤖 ', style: TextStyle(fontSize: 12)),
              Text(
                p.name.length > 12 ? '${p.name.substring(0, 12)}…' : p.name,
                style: Felt.label(12,
                    theme: theme,
                    color: active ? theme.woodDark : theme.ivory),
              ),
            ],
          ),
          Text(
            rem >= 0 ? '$label • $rem left' : label,
            style: Felt.body(10,
                theme: theme,
                color: active
                    ? theme.woodDark.withValues(alpha: 0.85)
                    : theme.ivory.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- bottom bar
class _BottomBar extends StatelessWidget {
  final BilliardThemeDef theme;
  final PoolEngine engine;
  const _BottomBar({required this.theme, required this.engine});

  @override
  Widget build(BuildContext context) {
    String hint;
    if (engine.over) {
      hint = 'Game over — well played!';
    } else if (engine.phase == Phase.ballInHand) {
      hint = 'Tap the felt to place the cue ball.';
    } else if (engine.current.isBot) {
      hint = 'Watch ${engine.current.name} play…';
    } else {
      hint = 'Drag back from the ball to aim & power — release to shoot.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(hint,
                style: Felt.body(11,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.65)),
                textAlign: TextAlign.center),
          ),
          if (engine.over)
            FeltButton(
              label: 'Play Again',
              width: 150,
              fontSize: 15,
              theme: theme,
              onTap: () => engine.restart(),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- pause dlg
class _PauseDialog extends StatelessWidget {
  final BilliardThemeDef theme;
  final BilliardAudio audio;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseDialog(
      {required this.theme,
      required this.audio,
      required this.onResume,
      required this.onRestart,
      required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [theme.woodMid, theme.woodDark]),
          border: Border.all(color: theme.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: Felt.display(26, theme: theme)),
            const SizedBox(height: 18),
            FeltButton(
                label: 'Resume',
                theme: theme,
                onTap: () {
                  audio.click();
                  onResume();
                }),
            const SizedBox(height: 10),
            FeltButton(
                label: 'Restart',
                theme: theme,
                onTap: () {
                  audio.click();
                  onRestart();
                }),
            const SizedBox(height: 10),
            FeltButton(
                label: 'Quit to Menu',
                theme: theme,
                onTap: () {
                  audio.click();
                  onQuit();
                }),
          ],
        ),
      ),
    );
  }
}

// ================================================================= TABLE =
class _TablePainter extends CustomPainter {
  final PoolEngine engine;
  final BilliardThemeDef theme;
  final int ballStyle;
  final int cueStyle;
  final Offset? dragPos;

  _TablePainter({
    required this.engine,
    required this.theme,
    required this.ballStyle,
    required this.cueStyle,
    required this.dragPos,
  });

  late double _s; // px per unit
  late Offset _o; // play-area origin in px

  Offset _to(Offset u) => _o + Offset(u.dx * _s, u.dy * _s);

  @override
  void paint(Canvas canvas, Size size) {
    // Fit table (100x50 play + 6-unit rail margin each side) into size.
    _s = min(size.width / 112, size.height / 62);
    final tablePx = Size(112 * _s, 62 * _s);
    final origin = Offset(
      (size.width - tablePx.width) / 2,
      (size.height - tablePx.height) / 2,
    );
    _o = origin + Offset(6 * _s, 6 * _s);

    _drawRails(canvas, origin, tablePx);
    _drawFelt(canvas);
    _drawPockets(canvas);
    _drawSights(canvas, origin, tablePx);
    _drawBalls(canvas);
    _drawAim(canvas);
  }

  void _drawRails(Canvas canvas, Offset origin, Size tablePx) {
    final rect = Rect.fromLTWH(origin.dx, origin.dy, tablePx.width, tablePx.height);
    // Outer shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(6), Radius.circular(26 * _s)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    // Wooden rail with bevel: dark edge → mid wood → light inner lip.
    final wood = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [theme.woodLight, theme.woodMid, theme.woodDark],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(20 * _s)),
      wood,
    );
    // Brass inner trim.
    final inner = rect.deflate(4.2 * _s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(14 * _s)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * _s
        ..color = theme.accent,
    );
  }

  void _drawFelt(Canvas canvas) {
    final rect = Rect.fromLTWH(_o.dx, _o.dy, tableW * _s, tableH * _s);
    // Cloth with a soft center glow (overhead lamp feel).
    final felt = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 1.1,
        colors: [theme.felt, theme.feltDark],
      ).createShader(rect);
    canvas.drawRect(rect, felt);
    // Cushion bevel strip.
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * _s
        ..color = theme.cushionTop,
    );
  }

  void _drawPockets(Canvas canvas) {
    for (final pk in pockets) {
      final c = _to(pk);
      // Brass rim.
      canvas.drawCircle(
          c, (pocketR + 0.55) * _s, Paint()..color = theme.accentDark);
      // Dark mouth with inner depth.
      canvas.drawCircle(
        c,
        pocketR * _s,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF000000), theme.pocket],
          ).createShader(Rect.fromCircle(center: c, radius: pocketR * _s)),
      );
    }
  }

  void _drawSights(Canvas canvas, Offset origin, Size tablePx) {
    // Diamond sights on the rails.
    final dot = Paint()..color = theme.accentLight;
    for (int i = 1; i < 7; i++) {
      if (i == 3 || i == 4) continue; // skip side pockets zone approx
      final x = origin.dx + tablePx.width * i / 8;
      canvas.drawCircle(Offset(x, origin.dy + 2.1 * _s), 0.55 * _s, dot);
      canvas.drawCircle(
          Offset(x, origin.dy + tablePx.height - 2.1 * _s), 0.55 * _s, dot);
    }
    for (int i = 1; i < 3; i++) {
      final y = origin.dy + tablePx.height * i / 4;
      canvas.drawCircle(Offset(origin.dx + 2.1 * _s, y), 0.55 * _s, dot);
      canvas.drawCircle(
          Offset(origin.dx + tablePx.width - 2.1 * _s, y), 0.55 * _s, dot);
    }
  }

  void _drawBalls(Canvas canvas) {
    // Shadows first, then balls.
    for (final b in engine.balls) {
      if (!b.active) continue;
      final c = _to(b.p);
      canvas.drawCircle(
        c + Offset(0.5 * _s, 0.7 * _s),
        ballR * _s,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
    }
    for (final b in engine.balls) {
      if (!b.active) continue;
      _drawBall(canvas, b);
    }
  }

  void _drawBall(Canvas canvas, PoolBall b) {
    final c = _to(b.p);
    final r = ballR * _s;
    final base = ballColor(b.n);
    // Ball body with gloss highlight (finish varies by style).
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.15,
        colors: [
          _finish(base, highlight: true),
          base,
          _finish(base, highlight: false),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, body);
    // Style accents.
    if (ballStyle == 4) {
      // Pearl sheen ring.
      canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, 0.12 * _s)
            ..color = Colors.white.withValues(alpha: 0.5));
    } else if (ballStyle == 5) {
      // Marble swirl arc.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.6),
        0.4,
        2.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, 0.16 * _s)
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    } else if (ballStyle == 7) {
      // Onyx & gold rim.
      canvas.drawCircle(
          c,
          r * 0.96,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, 0.14 * _s)
            ..color = const Color(0xFFD4AF37).withValues(alpha: 0.7));
    }
    if (isCue(b.n)) {
      // Cue ball: tiny red dot like a real measles ball.
      canvas.drawCircle(
          c + Offset(r * 0.3, -r * 0.25), r * 0.12, Paint()..color = const Color(0xFFB03A2E));
      return;
    }
    if (isStripe(b.n)) {
      // White band around the middle for stripes.
      canvas.drawRect(
        Rect.fromCenter(center: c, width: r * 2, height: r * 1.05),
        Paint()..color = const Color(0xFFF5F2EA),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, 0.1 * _s)
          ..color = Colors.black.withValues(alpha: 0.25),
      );
    }
    // Number circle.
    final nc = _to(b.p);
    canvas.drawCircle(nc, r * 0.52, Paint()..color = const Color(0xFFF5F2EA));
    final tp = TextPainter(
      text: TextSpan(
        text: '${b.n}',
        style: TextStyle(
          fontSize: r * 0.62,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, nc - Offset(tp.width / 2, tp.height / 2));
  }

  Color _finish(Color base, {required bool highlight}) {
    switch (ballStyle) {
      case 2: // Vintage ivory patina.
        return highlight
            ? Color.lerp(base, const Color(0xFFF2EAD0), 0.35)!
            : Color.lerp(base, const Color(0xFF8A7A5A), 0.3)!;
      case 3: // Matte: flatten the gloss.
        return highlight
            ? Color.lerp(base, Colors.white, 0.12)!
            : Color.lerp(base, Colors.black, 0.25)!;
      case 6: // Copper tint.
        return highlight
            ? Color.lerp(base, const Color(0xFFFFD9A0), 0.4)!
            : Color.lerp(base, const Color(0xFF7A4A20), 0.35)!;
      case 7: // Onyx darken.
        return Color.lerp(base, Colors.black, highlight ? 0.1 : 0.45)!;
      default:
        return highlight
            ? Color.lerp(base, Colors.white, 0.45)!
            : Color.lerp(base, Colors.black, 0.42)!;
    }
  }

  void _drawAim(Canvas canvas) {
    final e = engine;
    if (e.over || e.paused) return;
    final cue = e.cue;
    if (e.phase == Phase.aiThinking && cue.active) {
      // Visible bot aim: dashed line + target highlight.
      final from = _to(e.aiAimFrom);
      final to = _to(e.aiAimTo);
      _dashedLine(canvas, from, to, Colors.white.withValues(alpha: 0.75));
      canvas.drawCircle(
        from,
        ballR * _s + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.accentLight,
      );
      return;
    }
    if (e.phase == Phase.aiming &&
        !e.current.isBot &&
        cue.active &&
        dragPos != null) {
      final pull = cue.p - dragPos!;
      final dist = pull.distance;
      if (dist < 3) return;
      final dir = pull / dist;
      final power = (dist / 40).clamp(0.12, 1.0);
      final from = _to(cue.p);
      final to = _to(cue.p + dir * (14 + power * 26));
      _dashedLine(canvas, from, to, Colors.white.withValues(alpha: 0.8));
      _drawCueStick(canvas, cue.p, -dir, pullback: 3 + power * 9, striking: false);
      // Power meter arc above the cue ball.
      final sweep = power * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: from, radius: (ballR + 2.6) * _s),
        -pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2, 0.5 * _s)
          ..strokeCap = StrokeCap.round
          ..color = theme.accentLight,
      );
      return;
    }
    if (e.phase == Phase.cueStrike && cue.active) {
      // Cue stick drives forward into the ball during the strike.
      final t = e.strikeT.clamp(0.0, 1.0);
      final pullback = (1 - t) * (3 + e.strikePower * 9) - t * 2;
      _drawCueStick(canvas, cue.p, -e.strikeDir,
          pullback: pullback, striking: true);
    }
    if (e.phase == Phase.ballInHand && !e.current.isBot) {
      // Pulsing ghost marker inviting placement.
      final c = _to(cue.active ? cue.p : const Offset(25, 25));
      canvas.drawCircle(
        c,
        (ballR + 1.2) * _s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.accentLight.withValues(alpha: 0.8),
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dash = 6.0;
    const gap = 5.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    double d = ballR * _s + 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = max(2, 0.35 * _s)
      ..strokeCap = StrokeCap.round;
    while (d < total) {
      final e = min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * e, paint);
      d = e + gap;
    }
  }

  void _drawCueStick(
      Canvas canvas, Offset ballU, Offset backDir, {required double pullback, required bool striking}) {
    final tipU = ballU + backDir * (ballR + 0.6 + pullback);
    final endU = tipU + backDir * 26;
    final tip = _to(tipU);
    final end = _to(endU);
    final colors = _cueColors();
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromPoints(tip, end))
      ..strokeWidth = max(3, 0.85 * _s)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tip, end, paint);
    // Tip.
    canvas.drawCircle(tip, max(2, 0.5 * _s), Paint()..color = const Color(0xFFD8C9A8));
    if (striking) return;
    // Grip rings near the butt.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = theme.accent.withValues(alpha: 0.85)
      ..strokeWidth = max(2, 0.4 * _s);
    for (final f in [0.72, 0.78]) {
      final p = tip + (end - tip) * f;
      canvas.drawCircle(p, paint.strokeWidth / 2 + 1, ringPaint);
    }
  }

  List<Color> _cueColors() {
    switch (cueStyle) {
      case 1:
        return [const Color(0xFF1E1A16), const Color(0xFF0C0A08)];
      case 2:
        return [const Color(0xFF9A5A34), const Color(0xFF5E3418)];
      case 3:
        return [const Color(0xFF6E2F3A), const Color(0xFF3E1620)];
      case 4:
        return [const Color(0xFF3A3F44), const Color(0xFF141619)];
      case 5:
        return [const Color(0xFFD8C9A8), const Color(0xFF8A7A5A)];
      case 6:
        return [const Color(0xFFB08D3E), const Color(0xFF6E5514)];
      case 7:
        return [const Color(0xFFE8CE7A), const Color(0xFF9A7B1E)];
      default:
        return [const Color(0xFFC89A5E), const Color(0xFF7A5228)];
    }
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}
