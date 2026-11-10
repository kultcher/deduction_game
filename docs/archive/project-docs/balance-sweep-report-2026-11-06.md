# Balance sweep, Nov 6: M4 bot vs pre-M4 vs passive

Nov 6, 2026 · Claude-Tally · run `42174319660` at `0ca8654` (main `9a1b215` plus the `bot_pre_m4` sweep mode, PR #89) · results branch `sweep-results/run-42174319660`

## Headline

- **The M4 bot wins more at 10 NPCs:** 55.8% against 50.9% for the pre-M4 bot, on the same 2,000 seeds (+4.9 points, McNemar z = 4.0). At 7 NPCs it's +2.5 points on 978 shared seeds, not significant (z = 1.4).
- **Passive play at 10 NPCs fell sharply since the last run:** 30.0% against 42.6% at `501b83e` on the same 1,000 seeds (−12.6 points, z = −6.7). At 7 NPCs it's −2.2, within noise. The pre-M4 bot fell too, by 5.4 points at 10 NPCs (z = −2.8). M4 roughly makes that back (−1.9 against the old bot, not significant).
- **The player matters more than ever:** the bot beats passive by 26–27 points at both sizes.
- **M4 is slow:** about 1.7× the pre-M4 bot's time per game (median 300 s against 179 s at 10 NPCs, 70 s against 41 s at 7).

## Coverage

10,734 games, 0 failed, 0 stuck. The run shows as cancelled because the two 7-NPC bot cells each ran as a single shard and hit the 330-minute job limit. The shard cost table underestimated the new bot by 4×. The partial results uploaded.

| Cell | Games | Missing |
|---|---|---|
| 7 passive | 2,000 | none |
| 7 bot (M4) | 978 | 1,022, the tail of each of the shard's four process ranges, between seeds 100257 and 101999 |
| 7 bot (pre-M4) | 1,756 | 244, tails between seeds 100454 and 101999 |
| 10 passive, bot, bot (pre-M4) | 2,000 each | none |

PR #89 now carries measured costs (seconds per game per core: 7 bot 85, 10 bot 350, 7 pre-M4 50, 10 pre-M4 210). A top-up of the missing 7-NPC seeds would take about 1.5 hours.

## Win rates

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game |
|---|---|---|---|---|---|
| 7 NPCs, bot (M4) | 978 | 59.7% (56.6–62.7) | 3.19 | 0.63 | 1.08 |
| 7 NPCs, bot (pre-M4) | 1,756 | 58.4% (56.1–60.7) | 3.11 | 0.72 | 1.06 |
| 7 NPCs, passive | 2,000 | 34.8% (32.7–36.9) | 3.55 | 0.92 | 0.75 |
| 10 NPCs, bot (M4) | 2,000 | 55.8% (53.6–57.9) | 4.35 | 1.02 | 1.59 |
| 10 NPCs, bot (pre-M4) | 2,000 | 50.9% (48.7–53.1) | 4.37 | 1.15 | 1.54 |
| 10 NPCs, passive | 2,000 | 28.7% (26.8–30.8) | 4.78 | 1.50 | 1.10 |

## Paired comparisons

Each pair uses the seeds present in both cells. "Discordant" counts the seeds where only one side won (A only / B only).

| Comparison | Seeds | A | B | Difference | Discordant | z |
|---|---|---|---|---|---|---|
| 10: M4 vs pre-M4 | 2,000 | 55.8% | 50.9% | +4.9 | 349 / 252 | 4.0 |
| 7: M4 vs pre-M4 | 978 | 59.7% | 57.3% | +2.5 | 150 / 126 | 1.4 |
| 10: M4 vs passive | 2,000 | 55.8% | 28.7% | +27.0 | 705 / 165 | 18.3 |
| 7: M4 vs passive | 978 | 59.7% | 33.4% | +26.3 | 349 / 92 | 12.2 |
| 10: passive now vs `501b83e` | 1,000 | 30.0% | 42.6% | −12.6 | 113 / 239 | −6.7 |
| 7: passive now vs `501b83e` | 1,000 | 35.4% | 37.6% | −2.2 | 132 / 154 | −1.3 |
| 10: pre-M4 now vs old bot | 1,000 | 50.9% | 56.3% | −5.4 | 166 / 220 | −2.8 |
| 10: M4 now vs old bot | 1,000 | 54.4% | 56.3% | −1.9 | 181 / 200 | −1.0 |

## What changed in 10-NPC passive play (seeds 100000–100999, then vs now)

- **Evil is executed less:** 1.34 → 1.11 per game, mostly on days 2 and 3 (0.42 → 0.33 and 0.49 → 0.35).
- **Good is executed more:** 1.30 → 1.52, with the extra losses on day 5 and later.
- **More talk:** shares 39.2 → 48.0 (+23%), lies 13.5 → 16.8 (+24%), fake info 7.4 → 8.0, nominations 9.5 → 11.6.
- **Longer games, fewer survivors:** 4.39 → 4.72 days; good survival 29% → 20%.
- **At 7 NPCs most of this is flat,** apart from shares (+26%) and lies (+14%).

**Not established: which change caused the drop.** Twenty PRs landed between `501b83e` and `9a1b215`. The extra sharing points at NPC openness (#77), and the rise in lies suggests liars' lies now travel further too, but evidence honesty (#74), M2c/M2d, step 0 and step 0b all move NPC beliefs as well.

A per-seed bisect won't work: any change reshuffles the random rolls, so the seeds that flipped regress to the mean at the first commit that changes play. That points at the wrong commit. What does work is a 10-NPC passive cell of about 1,000 seeds at each candidate commit. Five commits (#74, #77, #78 M2d, #81 step 0, #86 step 0b) take about 15 shard jobs and 1.5 hours on Actions.

## M4 bot detail (10 NPCs, against pre-M4)

- **Fewer wrongful executions:** 1.15 → 1.02 per game. Evil executions 1.54 → 1.59. Player nominations 2.92 → 2.65, as M4's higher nomination bar intends.
- **Demon identified:** 72.2% → 77.0% of games. But "identified but lost" is high in both (27.8% and 29.5%), against 24.1% for the old bot.
