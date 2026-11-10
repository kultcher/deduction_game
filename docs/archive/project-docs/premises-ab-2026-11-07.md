# Premises steps 1–3: A/B sweep

Nov 7, 2026 · Claude-Tally · runs `42331033313` (base `0743a76`, main just before step 1), `42331041617` (step 1, `3d0f210`) and `42331050248` (steps 1–3, main `226d566`). All use the M4 bot, seeds 100000–100999, dynamic scripts and unchanged attention budgets. Results are on the `sweep-results/run-<id>` branches.

**Follow-up (Nov 7 evening, Claude-Bailiff):** the step 3 slowdown is fixed on main.
- **PR #99** (`346d88c`, `baseline_5ba1d64`, same games): graded challenges take r from the holds evaluation, and skip the cause when the effect is zero, which covers 91% of challenges.
- **PR #100** (`33c18bc`, `baseline_7034f36`, decided with Michael): bare NPC defences, which have no grounds, aren't graded at all. They bring nothing new, and the listener's beliefs already rest on the rest of the evidence. They still count through the older challenge rules. This is a small behaviour change: about 4e-5 in suspicion, with the same final results in the golden games.

One game at 10 NPCs: passive went from 71 s to 35 s to about 20 s (26 s at step 2), and the M4 bot from 214 s to 152 s to about 112 s. See "Time per game" below. A re-sweep on current main should confirm the timeouts are gone.

## Headline

- **Steps 1–3 don't move outcomes.** On the same seeds:
  - Step 1 vs base: 7 NPCs +0.1 points (z 0.1); 10 NPCs −0.6 (z −0.5).
  - Steps 2–3 on top of step 1: 7 NPCs 0.0 (1 seed differs each way); 10 NPCs −0.3 (2/5 discordant).
  - Wrong executions, Demon found, and "identified but lost" are flat too.
  - Caveat (Bailiff): the M4 bot only files "X is evil" cases. It never uses suspicious or secret premises or reading challenges, so this measures side effects on NPC play, not the value of steps 2–3 to a human player.
- **Step 3 makes games much slower** (fixed since; see the follow-up above). At 10 NPCs:
  - Passive: median 140 s per game, against 24 s at base, so 5.8× slower, with the same outcomes (6/5 discordant).
  - Bot: median 504 s against 317 s at step 1.
  - 33 bot games hit the 30-minute per-game limit, and 114 passive games are missing because their shards hit the job limit.
  - The cause is step 3 (#95). A local timing of one passive game is 26 s at step 1, 26 s at step 2 and 105 s at step 3.
- **"Identified but lost" is about 38% of the games where the bot identifies the Demon, at 10 NPCs.** The Nov 6 "29.5%" was a share of all games, not of games where the Demon was identified. Both are flat across steps 1–3.

## Win rates (paired on shared seeds)

| Comparison | Seeds | A | B | Difference | Discordant (A only / B only) | z |
|---|---|---|---|---|---|---|
| 7, step 1 vs base | 1,000 | 58.6% | 58.5% | +0.1 | 46 / 45 | 0.1 |
| 7, steps 1–3 vs step 1 | 1,000 | 58.6% | 58.6% | 0.0 | 1 / 1 | 0.0 |
| 10, step 1 vs base | 1,000 | 52.5% | 53.1% | −0.6 | 85 / 91 | −0.5 |
| 10, steps 1–3 vs step 1 | 963 | 53.3% | 53.6% | −0.3 | 2 / 5 | −1.1 |
| 10, steps 1–3 vs base | 963 | 53.3% | 53.8% | −0.5 | 78 / 83 | −0.4 |
| 10 passive, steps 1–3 vs base | 886 | 30.4% | 30.2% | +0.1 | 6 / 5 | 0.3 |

Steps 2–3 barely change any game: 7 of 963 seeds at 10 NPCs and 2 of 1,000 at 7 have a different outcome from step 1. Step 1 changes about 18% of games at 10 NPCs, but the changes cancel out.

## Acceptance numbers (10 NPCs, M4 bot)

| | Base | Step 1 | Steps 1–3 |
|---|---|---|---|
| Good executions per game (wrong nominations that got through) | 1.10 | 1.13 | 1.13 |
| Evil executions per game | 1.58 | 1.56 | 1.56 |
| Player nominations per game | 2.71 | 2.70 | 2.64 |
| Demon identified | 77.8% | 76.3% | 76.4% |
| Identified but lost (of identified) | 37.8% | 38.5% | 37.8% |
| Workshop cases filed per game | 3.60 | 3.56 | 3.51 |

At 7 NPCs everything is within ±0.05 per game. Identified but lost is 32.8% → 31.9% → 31.9%.

The steps-1–3 columns use 963 seeds. The other columns use all 1,000.

## Time per game

| Cell | Base | Step 1 | Steps 1–3 |
|---|---|---|---|
| 7 bot, median / p90 | 55 / — s | 64 s | 77 / 168 s |
| 10 bot, median / p90 / p99 | 295 / 600 / 1,035 s | 317 s | 504 / 1,101 / 1,714 s, plus 33 timeouts at 1,800 s |
| 10 passive, median / p90 / max | 24 / 43 / 123 s | — | 140 / 348 / 1,569 s |

Step 1 adds about 7–16% (the second union pass). Step 3 roughly doubles the bot's time and multiplies passive play by about 6. In passive play the player never files a case, so the cost comes from NPC defences. Every defence becomes a reading challenge in each listener's ledger, and `ReadingChallenges.graded_challenge` runs three full `CaseEval.evaluate` calls per challenge (holds, source good, source evil), plus more for failed gifts. That repeats at every belief refresh, for every listener holding the challenge. Earlier measurements put one full evaluation at 30–117 ms.

Possible fixes, for whoever owns step 3:
- cache the graded result per challenge and evidence state;
- or take q, f, r and the evil share from one world enumeration, as masks over the same worlds.

**What was done (Claude-Bailiff, PRs #99 and #100).** Caching doesn't help here: 541 of 586 graded inputs in a passive game were distinct. Every challenge in a passive game and in an M4-bot game was a bare defence: no grounds, hearing 0.03–0.05.

#99 removed two of the three evaluations without changing any decision:
- **r's prior** now comes from the holds evaluation, because a case's prior doesn't depend on its cards. It agreed with the separate "good" evaluation to 1e-14.
- **The cause is skipped when the effect is zero.** The source-evil and Delusional evaluations only ever scale the effect.

The source-evil share can't be taken from one evaluation shared across challenges: people's posteriors depend on the case's conclusion, and the gap was up to 0.058. A per-world memo of the "before" role fits saved nothing.

#100 stopped grading bare defences.

| One game, 10 NPCs | Main before | #99 | #100 |
|---|---|---|---|
| Passive, seed 100000 | 71 s | 35 s | ~20 s |
| M4 bot, seed 100003 | 214 s | 152 s | ~112 s (measured with an equivalent prototype) |

### Coverage on main

- **10 bot:** 963 of 1,000 games. 33 timed out and 4 were lost to shard caps. The timed-out seeds are long games: at step 1 they averaged 6.2 days and good won only 21%. So main's unpaired rate (53.3%) is flattered slightly. The paired rows leave those seeds out of both sides.
- **10 passive:** 886 of 1,000.
- **7 bot:** complete.

## Sanity check against the Nov 6 sweep (`42174319660` at `0ca8654`)

- **10 bot:** base 53.1% vs Nov 6's 54.4% (−1.3, z −0.8). Consistent.
- **10 passive:** identical apart from 5 seeds.
- **7 bot:** base 57.4% vs Nov 6's 62.8% on the 505 seeds both have (−5.3, z −3.0). Something between `9a1b215` and `0743a76` lowered the 7-NPC bot: #90 (maintenance), #91 (Nov 6 fixes) or #94 (haunt learning). Not yet investigated.

## Still open

- The 10-NPC passive drop since `501b83e` (42.6% → 30%) is still unexplained. A fresh-cell check at five candidate commits is on offer.
- The 7-NPC bot drop above.
- A re-sweep of current main (`33c18bc`) to confirm the timeouts are gone.
