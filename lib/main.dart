import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const PocketBilliardsApp());

class PocketBilliardsApp extends StatelessWidget {
  const PocketBilliardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Pocket Billiards',
      tagline: 'Pot every ball in smooth 8-ball pool matches',
      emoji: '🎱',
      slug: 'pocketbilliards',
      howToPlay:
          '• Drag BACK from the cue ball to aim — release to shoot. Longer pull = harder hit.\n• Pot a ball after the break to claim solids or stripes.\n• Clear your group, then sink the 8-ball to win. Early 8-ball = instant loss!\n• Scratch (cue ball potted) = foul, ball re-spotted, turn passes.\n• Solo? The bot shark is waiting. 🦈',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) =>
          PocketBilliardsScreen(players: players, callbacks: cb),
    );
  }
}
