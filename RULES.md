# RULES.md — Pocket Billiards

Casual 8-ball pool on a wooden table with real felt. Rack 'em, claim a group,
sink the 8. The authoritative source of truth for the rules; the engine
(`lib/engine/pool_engine.dart`) enforces every section below.

## 1. Objective
Be the first player to legally pocket all balls of your group (solids 1–7 or
stripes 9–15), then legally pocket the 8-ball.

## 2. Setup
- 15 object balls racked in a triangle, apex on the foot spot; the 8-ball in
  the middle of the rack; the two back corners are one solid and one stripe.
- The cue ball starts at the head spot. Player 1 breaks.

## 3. Turn order
- Players alternate turns. Player 1 shoots first (the break).
- A player keeps shooting while they legally pocket one of their group balls
  (or any object ball while the table is open). A miss, a foul, or pocketing
  only the opponent's ball ends the turn.

## 4. Legal moves
- Strike the cue ball with the cue stick (drag back, release).
- While the table is open (after the break, before groups are claimed), any
  object ball except the 8 may be hit first.
- Once groups are claimed, the shooter must hit one of their own group balls
  first. When their group is cleared, the 8-ball becomes the legal target.

## 5. Illegal moves
- Hitting no object ball at all (foul — turn passes).
- Potting the cue ball (scratch — foul).
- Potting the 8-ball before the shooter's group is cleared (loss).

## 6. Captures
- Pocketing is permanent: potted balls stay down for the rest of the game.
- The first object ball potted after the break (on a non-foul shot) claims
  that ball's group for the shooter; the opponent takes the other group.

## 7. Special rules
- **Break:** the opening shot. Potting on the break claims the group as usual.
- **Scratch:** cue ball potted. Foul: the incoming player gets **ball in
  hand** — they may place the cue ball anywhere legal on the table.
- **Ball in hand placement** is illegal on top of another ball, inside a
  pocket mouth, or off the felt.

## 8. Scoring
- No points — the game is won or lost outright (see §9).

## 9. Winning conditions
- Legally pocket the 8-ball after your group is fully cleared (no foul on the
  same shot).

## 10. Draw conditions
- None. Every game ends with a winner.

## 11. AI strategy
- Easy: picks the shortest ball→pocket path but aims with ±9° noise and
  sometimes (18%) goes for the wrong ball entirely.
- Medium: same targeting with ±3.5° noise — a fair club player.
- Hard: ±1.2° noise, full-power control — punishes every mistake.
- The AI always shows its aim line and narrates ("lining up…", "shoots!")
  before striking — never a silent auto-play.

## 12. Edge cases
- 8-ball potted on the break → loss (early 8, §5).
- 8-ball potted on a scratch → loss.
- 8-ball potted while groups are open and the shot is otherwise legal →
  treated as an early 8 → loss (the 8 is only legal with a cleared group).
- Cue ball flies off with no ball hit → foul, turn passes (no ball in hand;
  only scratches grant ball in hand).
- Potting the opponent's ball along with your own → legal, turn continues.
- Potting only the opponent's ball → turn passes, no foul.

## 13. Test cases
1. Break shot pots a solid → shooter claims solids, shoots again.
2. Player pots a stripe, then misses → turn passes with stripes claimed.
3. Scratch on a pot → foul; rival places cue ball anywhere legal.
4. 8-ball potted with one solid remaining → shooter loses immediately.
5. Group cleared, 8-ball potted cleanly → shooter wins.
6. No ball hit → foul, turn passes, cue stays where it stopped.
7. Ball-in-hand placement on another ball → rejected, no state change.
8. AI (any difficulty) completes its turn visibly: aim line drawn, narration
   shown, strike animated — verified via phase transitions, never stuck.
