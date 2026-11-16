# Balance sweep, Nov 14: the Breathstealer hunt (#157) and the connections model

Nov 14, 2026 · Claude-Tally · brief by Claude-Bailiff, for Michael. All runs start at seed 100000, so cells of the same size and mode pair game for game.

| Run | Commit | Cells |
|---|---|---|
| `43575847733` (base) | `b4e382e` = `5ac25ab` (main just before the hunt) + the #156 sweep tooling | 7 and 10 NPCs × bot, passive; 1,000 each |
| `43575857218` (new) | `9b2ca88` = main after the hunt (#157, `548413f`) and #156 | the same |
| `43575866761` | `9b2ca88`, connections on | 7 NPCs × bot, passive; 1,000 each |
| `43575875420` | `9b2ca88`, connections on | 10 NPCs × bot; **300 games (partial by design)** |

- The Breathstealer PR merged before the sweep started, so "new" is main, not the branch head.
- #156 (merged before the runs) adds the `_connections` cell suffix and the Breathstealer record fields (`breath_*`, `tools/breath_stats.gd`). Both commits carry it, so their records match.
- Results branches: `sweep-results/run-<id>`.

## Headline

- **The hunt changes nothing outside Breathstealer deals.** Every non-Breathstealer game plays out identically on both commits (781 of 781 at 7 NPCs, 559 of 559 at 10).
- **The Breathstealer silences far more often:** on 83–92% of its living days, against 62–72% before. That matches Bailiff's 40-seed probe.
- **Breathstealer deals still lean strongly toward good,** 18–32 points above other deals. The expected narrowing didn't happen:

  | Cell | Breathstealer deals, base → new | Paired | Other deals |
  |---|---|---|---|
  | 7 bot | 78.1% → 80.4% | +2.3 (30 / 25, z +0.7) | 61.7% |
  | 7 passive | 62.6% → 60.7% | −1.8 (33 / 37, z −0.5) | 36.5% |
  | 10 bot | 74.8% → 74.1% | −0.7 (70 / 73, z −0.3) | 53.7% |
  | 10 passive | 54.6% → 59.2% | +4.5 (84 / 64, z +1.6) | 27.5% |

  In 219 (7 NPCs) and 440 (10 NPCs) deals, almost every game changes course (only 11–39 identical), but the outcomes cancel.
- **The silenced town doesn't fix on the Breathstealer more.** At the meeting that it silences someone, it's the town's top suspect in 49% of cases at 7-NPC bot (56% before) and 28% at 10-NPC bot (34% before). Passive cells are flat.
- **Connections on is about level with off:** 7 bot −2.0 (z −1.3), 7 passive −0.8 (z −0.5), 10 bot +5.7 on 300 seeds (z +1.9). Passive games take about 3× longer (median 13 s against 4 s). 10-NPC bot games take about 35% longer (435 s against 323 s).
- **Since Nov 9, the bot and 7-NPC passive cells are up** (unpaired against run `42564439458`):
  - 7 bot 59.3% → 65.3%;
  - 10 bot 55.2% → 63.0%;
  - 7 passive 35.9% → 42.2%;
  - 10 passive is flat (39.0% → 39.5%).

  Several merges lie between, not tested apart: #135 sighter contests, #136 Gravedigger bluffs, #137 Phase 5, #149, #152.

## Win rates

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game |
|---|---|---|---|---|---|
| 7 NPCs, bot, base | 1000 | 65.3% (62.3–68.2) | 3.03 | 0.64 | 1.21 |
| 7 NPCs, bot, new | 1000 | 65.8% (62.8–68.7) | 3.04 | 0.61 | 1.21 |
| 7 NPCs, passive, base | 1000 | 42.2% (39.2–45.3) | 3.44 | 0.82 | 0.88 |
| 7 NPCs, passive, new | 1000 | 41.8% (38.8–44.9) | 3.44 | 0.82 | 0.88 |
| 10 NPCs, bot, base | 999 | 63.0% (59.9–65.9) | 4.16 | 0.98 | 1.75 |
| 10 NPCs, bot, new | 999 | 62.7% (59.6–65.6) | 4.17 | 0.99 | 1.71 |
| 10 NPCs, passive, base | 1000 | 39.5% (36.5–42.6) | 4.58 | 1.32 | 1.41 |
| 10 NPCs, passive, new | 1000 | 41.5% (38.5–44.6) | 4.54 | 1.27 | 1.43 |
| 7 NPCs, bot, connections on | 1000 | 63.8% (60.8–66.7) | 2.99 | 0.63 | 1.16 |
| 7 NPCs, passive, connections on | 1000 | 41.0% (38.0–44.1) | 3.54 | 0.77 | 0.86 |
| 10 NPCs, bot, connections on (partial) | 300 | 69.7% (64.2–74.6) | 4.01 | 0.86 | 1.80 |

## New against base (paired seeds)

| Cell | Base | New | Diff | Discordant (new only / base only) | z | Identical games |
|---|---|---|---|---|---|---|
| 7 bot | 65.3% | 65.8% | +0.5 | 30 / 25 | +0.7 | 820 |
| 7 passive | 42.2% | 41.8% | −0.4 | 33 / 37 | −0.5 | 792 |
| 10 bot | 63.0% | 62.7% | −0.3 | 70 / 73 | −0.3 | 579 |
| 10 passive | 39.5% | 41.5% | +2.0 | 84 / 64 | +1.6 | 571 |

## The Breathstealer

| Cell | Deals | Living days | Silenced | Silenced / living days, base → new | Top suspect after a silencing, base → new | Mean rank among the living, base → new |
|---|---|---|---|---|---|---|
| 7 bot | 219 | 484 → 503 | 322 → 445 | 66.5% → **88.5%** | 56.0% → 48.7% | 1.73 → 1.87 of 5.5 |
| 7 passive | 219 | 619 → 615 | 381 → 511 | 61.6% → **83.1%** | 56.4% → 52.9% | 1.76 → 1.79 of 5.3 |
| 10 bot | 440 | 1,351 → 1,363 | 970 → 1,250 | 71.8% → **91.7%** | 33.5% → 27.6% | 2.80 → 3.02 of 7.7 |
| 10 passive | 441 | 1,496 → 1,489 | 1,049 → 1,353 | 70.1% → **90.9%** | 31.6% → 32.7% | 2.72 → 2.69 of 7.4 |

- **Suppression isn't visible in the record.** `breath_suppressed` (the `silence_suppressed` event) is 0 everywhere: when the Sexton's bell suppresses it, the Breathstealer doesn't steal a breath at all. So the share above is over all its living days, suppressed ones included. The Sexton is rare, though (74 of 1,000 7-NPC deals).
- **No failed breaths** (poisoned tries) in any cell.
- **The rank** is the Breathstealer's place by the good townsfolk's mean suspicion at the end of the meeting where its silence takes hold (1 = most suspected). It measures the town's reading after the silencing, not the presence panel itself. The hunt's extra silences don't make the town pick it out more; at 10-NPC bot it's slightly less often the top suspect.

## Connections model on against off (new commit, paired)

| Cell | Off | On | Diff | Discordant (on only / off only) | z | Identical games |
|---|---|---|---|---|---|---|
| 7 bot | 65.8% | 63.8% | −2.0 | 117 / 137 | −1.3 | 266 |
| 7 passive | 41.8% | 41.0% | −0.8 | 113 / 121 | −0.5 | 115 |
| 10 bot (300 seeds) | 64.0% | 69.7% | +5.7 | 50 / 33 | +1.9 | 34 |

- It changes how almost every game unfolds (only 12–27% identical), but not the overall rate at 7 NPCs. The 10-NPC gain is on 300 seeds and borderline; a full cell would settle it.
- Executions are much the same. At 10 NPCs, connections hang slightly fewer good people (0.86 against 0.99 a game) and slightly more evil ones (1.80 against 1.71).

**Game time** (seconds per game on one runner core):

| Cell | Off: median / p90 / max | On: median / p90 / max |
|---|---|---|
| 7 bot | 65 / 128 / 300 | 63 / 129 / 381 |
| 7 passive | 4 / 6 / 15 | 13 / 21 / 53 |
| 10 bot | 323 / 680 / 1,724 | 435 / 858 / 1,698 |

No timeouts with connections on.

## Vote shape (guardrail)

| Cell | Votes/game | Unanimous but the nominee | Only the nominator | Evil nominations/game | …carried | …hanged |
|---|---|---|---|---|---|---|
| 7 bot, base / new | 4.9 / 4.9 | 21.2% / 20.7% | 28.3% / 28.4% | 2.01 / 2.04 | 15.4% / 14.6% | 14.7% / 13.8% |
| 7 passive, base / new | 6.3 / 6.3 | 17.8% / 17.8% | 39.2% / 39.8% | 2.89 / 2.90 | 25.9% / 25.6% | 24.2% / 24.0% |
| 10 bot, base / new | 9.0 / 9.2 | 14.1% / 13.0% | 26.8% / 27.0% | 3.87 / 3.90 | 14.5% / 14.5% | 13.5% / 13.4% |
| 10 passive, base / new | 10.7 / 10.6 | 10.8% / 10.7% | 32.1% / 31.8% | 5.07 / 5.04 | 25.8% / 25.4% | 22.6% / 22.0% |
| 7 bot, connections | 4.7 | 22.0% | 28.4% | 1.92 | 14.3% | 12.9% |
| 7 passive, connections | 6.3 | 17.1% | 41.0% | 2.94 | 24.1% | 22.5% |
| 10 bot, connections (300) | 8.1 | 14.1% | 25.9% | 3.56 | 11.5% | 9.8% |

No sign of herding in any cell.

## Role effects (good wins when dealt against not dealt; new commit)

Flagged where the gap is 8 points or more at |z| ≥ 2.5 (40+ games each side). Most are steady across both commits and earlier sweeps.

| Role | 7 bot | 7 passive | 10 bot | 10 passive |
|---|---|---|---|---|
| Breathstealer (Minion) | **+18.6** | **+24.2** | **+20.4** | **+31.6** |
| Poisoner (Minion) | | −14.1 | | −14.1 |
| Scion (Minion) | | | −14.3 | |
| Revenant (Minion) | −10.1 | | | −10.4 |
| Delusional (secret) | | −14.7 | −11.7 | |
| Night Watch | +9.0 | +14.1 | | +12.8 |
| Dowser | +11.2 | | | |
| Registrar | | +9.2 | | |
| Gravedigger | | −11.5 | | |
| Confessor | | | −9.2 | |
| Chronicler | | | −14.7 (136 deals) | |

- **The Breathstealer is the outlier by far,** and the hunt didn't move it. Possible reasons, not checked:
  - a silenced townsperson costs good less than it costs evil to have a Minion that can't lie at meetings;
  - the silence itself points at the Breathstealer.
- **Gifts that lean against good** when dealt: Confessor (10 bot; −11.8 at base) and Chronicler (10 bot). Gravedigger (7 passive; −14.0 at base) predates #136's bluff change.
- **Delusional** stays the strongest secret against good, as on Nov 9.

## Health

- **Timeouts:** one game per commit, both 10-NPC bot (base seed 100446, new seed 100429), hitting the 30-minute game limit (`exit -9`).
- **Stuck:** none.
- **Engine errors:** none.
- All 9,300 other games completed.
