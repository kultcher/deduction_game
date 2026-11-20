# The pressure of silence

- **Agent:** Claude-Beadle
- **Base:** main at `554f2f4` (`baseline_66be26f`, after #448), merged in; first written on `977e15e`
- **Branch:** `claude/beadle-silence` (the measured build was `mock/beadle-silence`)
- **Status:** PR open. Golden moves on every seed from day 1 and is re-baselined here to
  `baseline_c1cce1b`. Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (golden queue, review and merge).
- **BACKLOG item:** "Accusations from starting suspicion read as clues", built as Michael's
  "pressure of silence" [decided]. Pitch and constants approved Nov 20; approved to ship with no
  cap on the second pass, Nov 20 evening (via Seneschal).

## What changed

All in `sim/mind_meeting.gd`, with three constants in `Tuning.Meeting`:
- **The floor:** in a meeting's first pass, a good NPC needs at least `GOOD_ACCUSE_MIN_SUSP`
  (0.2) suspicion of its top suspect to accuse (`_public_accusation`). Below it, it doesn't.
- **The silence check:** once everyone has had their turn, if fewer than `SILENCE_USEFUL_MIN`
  (3) useful things came out, the speaking order runs once more, once per meeting. Useful means
  gift claims, shared readings, volunteered night sightings and accusations that give a reason.
  It's logged as `silence_check`.
- **The second pass:** the floor is waived, and good NPCs get `SILENCE_SPEAK_BONUS` (0.6) x
  (1 - Composure) toward claiming, accusing and volunteering a sighting. The jittery fill the
  silence. Evil gets no bonus: its speech is planned.
- **The opener:** whoever speaks in the second pass opens, once, with their voice's
  silence-breaker (Herald's 15 lines, #408; the fallback is "Well, someone ought to say
  something."). It plays for good and evil alike, so it isn't a tell.

## Measured

On `mock/beadle-silence` (main at `0b44cae` plus this change) against that main.

**Passive games (no player), 40 games, seeds 4000-4039:**

| | main | silence |
|---|---|---|
| Day-1 accusations | 61 | 70 |
| ...with no reason given | 24 | 29 |
| Day-1 claims | 101 | 109 |
| Day-1 night sightings shared | 7 | 10 |
| Day-1 meetings with nothing useful said | 2 | 0 |
| Second passes (on day 1) | 0 | 23 (9) |
| Night-1 kills of someone who claimed on day 1 | 18 | 16 |
| Hangings, evil / good | 54 / 46 | 59 / 38 |
| Wins, good / evil | 18 / 22 | 25 / 15 |

**With the autoplay player, 36 games each, seeds 4000-4035** (the last four were lost to memory):

| | main | silence |
|---|---|---|
| Day-1 accusations | 57 | 57 |
| ...with no reason given | 24 | 10 |
| Day-1 claims | 74 | 99 |
| Day-1 night sightings shared | 10 | 13 |
| Day-1 meetings with nothing useful said | 2 | 0 |
| Second passes (on day 1) | 0 | 13 (6) |
| Night-1 kills of someone who claimed on day 1 | 14 | 20 |
| Hangings, evil / good | 58 / 26 | 65 / 25 |
| Wins, good / evil | 25 / 11 | 26 / 10 |

In game terms:
- **The floor does its job.** A day-1 first-pass accusation from barely any suspicion happened 18
  times on main and never with the change. The weak accusations that remain come from the second
  pass, when the room has gone quiet and someone feels they must say something.
- **A second pass is busy:** 3 to 4 accusations each. Without a player that's why reasonless
  accusations rise (24 to 29). With the player present they fall by more than half (24 to 10).
- **More gifts come out on day 1** (a third more with the player), and the Demon kills those
  claimants on the first night a little more often (14 to 20 with the player).
- **Outcomes** barely move with the player (25 to 26 good wins). Without one, good wins more
  (18 to 25), mostly because fewer good people are hanged.

**Tests:** new `tools/test_silence_pressure.gd` (on the fast list): the approved constants; the
push to speak (none in the first pass, scaled by Composure in the second, none for evil); the
floor, with a control; the floor waived in the second pass; one second pass per meeting, only
when the meeting turned up too little; the voiced opener. Also pass: test_tuning_hoist and the
meeting suites (test_meeting_flow, m2a-m2d, reasons, stage, stream, gossip,
test_dialogue_fixes_testimony and test_dialogue_fixes_accusations_votes).

**Codex on #454, fixed in `e523a49`:** the second pass now gives each speaker one turn (an
interjection in the first pass had added a second); and an accusation counts as useful only when
its reason is actually said and new at the meeting, not for a bare agreement or an echo. The
second fix makes a second pass a little more likely than in the A/B above, which predates it.

**A fixture test made sturdier:** `tools/test_night_sighting_rebuttal.gd` builds its case on a
game `tools/fixture_seeds.gd` finds, and the change finds a different one. Its evil defender
there lived on the victim's block (a neighbour never says "I was never on it", by design) and had
claimed sleepwalking. The test now picks an evil defender who doesn't live on the victim's block
and keeps the sleepwalk excuse out of that check. No game code changed for it.

**Golden:** re-baselined to `baseline_c1cce1b`; two captures were identical. Every seed diverges
at day 1's first meeting. 42 becomes a good win on day 2 (Agnes, the Demon, hanged); the other
four seeds hang different people, with no winner by day 4. See "Current baseline" in
`docs/golden_baseline.md`.

## Proposed for the backlog

None.
