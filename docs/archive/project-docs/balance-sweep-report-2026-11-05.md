# Balance sweep report, 2026-11-05

Overnight autoplay sweep on **dynamic scripts** (a fresh random script per game, built
from every `ready` role), by Claude-Tally. 11,000 games on GitHub Actions from `main` at
`a0d9641` (runs 41978776824 and 41999201334). Tooling and record schema:
`docs/balance_sweep.md` in the repo. Full records: branches
`sweep-results/run-41978776824` and `sweep-results/run-41999201334`.

## What it found

1. **Good wins about a third to two-fifths of games with no player, about half with the
   bot.** No player: 34% at 7 NPCs, 40% at 10. The analyst bot: 55% at 7, 53% at 10.
   A bot that misses 40% of its cards: 49% at 7, 51% at 10. Intervals are about ±2
   points (±3 for the 1,000-game cell). Oddly, the town does better on its own at 10 than
   at 7.
2. **The player matters, in both directions.** On the same seed and deal, the bot turns
   a lost game into a win 23–30% of the time, and loses one the passive town would have
   won 9–11% of the time. Reading every card instead of 60% of them is worth only 2–6
   points, so persuasion and timing, not reading, look like the bot's limit.
3. **The Breathstealer is much the weakest minion; the Poisoner and the Scion are the
   strongest.** Games with a Breathstealer are 12–17 points better for good in every
   cell. Games with a Poisoner are 5–10 points worse. At 10 NPCs the Scion costs good
   15 points with the bot (8 without): it takes over the Demon in 41–52% of its 10-NPC
   games.
4. **Delusional is by far the most damaging secret**: −8 to −16 points in five of six
   cells. Lovers help a little at 7 NPCs (+7 to +8), Marked helps the passive 10-NPC town
   (+8).
5. **The Lamplighter is the strongest town gift, and its claim is nearly bulletproof.**
   With a Lamplighter in play good wins 11–14 points more at 10 NPCs and 8–11 at 7
   (with the bot). A true Lamplighter is hanged while good in only about 2% of games, and
   evil bluffing the Lamplighter is hanged in only 2–4% of bluffs. Every other bluff
   gets its claimer hanged 20–70% of the time. Evil could exploit this far more than it
   does.
6. **Some gifts hurt, or at least travel with losses.** The Gravedigger is −10 points at
   7 NPCs in all three cells; the Executor (−7 to −10) and Sexton (−9 at 10 NPCs, bot
   insight 0.6) look weak too. The Dowser, Night Watch and Lamplighter look strong. These
   are associations (the deal rules tie roles together), but the Gravedigger result is
   consistent enough to look into.
7. **The Demon goes for the Archivist and the Dowser first.** They're killed in the first
   two nights in 53–58% and 46–56% of their games. Meanwhile the Veteran, who survives
   the first attack, is hanged while good in 44% of its 7-NPC passive games (28% at 10
   with the bot).
8. **A common 10-NPC loss is the town hanging itself out.** "No good soul remains" ends
   28% of 10-NPC passive games and 15–16% of bot games: every good townsperson dead and
   the evil team intact. Wrongful executions run 1.2–1.4 per 10-NPC game.
9. **More night-walkers help good at 10 NPCs.** Deals with 3 night-walkers (counting the
   Demon) are 7–8 points worse for good; 5 night-walkers 9–15 points better. More people
   out means more sightings for the town to work with.
10. **Health is good, with three things to fix.** No crashes or timeouts in 11,000 games.
    13 bot games ran out the 600-command guard (stuck); 50 games had a shared-model
    fallback; and two games hit a **C# exception**:
    `IndexOutOfRangeException` in `CaseEvalKernel.ComputeClassLikeCore`
    (`workshop/cs/CaseEvalKernel.cs:890`), reached from a belief refresh after a night
    kill. It reproduces on seed 101032 (10 NPCs, passive, `--dynamic`).

## Caveats

- **Dynamic scripts, not the Default script.** These numbers don't compare directly with
  older Default-script runs. The experimental Brute is never dealt.
- **The bot is pre-M4.** It doesn't drive the podium press or the repositioned player
  turn yet. Bot win rates describe today's bot, not a skilled human.
- **Passive results mostly measure NPC meeting behaviour.**
- **Role effects are associations, not causes.** The deal rules (start-knowledge
  guarantees, night-walker bands) make roles travel together.
- Evil never double-claims ("contested 0%" in the bluff tables): there's no rival-claim
  logic yet (BACKLOG, "Evil backs into a bluff").
- Main's golden check was already red when the sweep ran (seeds 54875 and 692 diverge
  from `baseline_9187b09` at the final step). The sweep tooling doesn't change it.

---

## Full report


Records: 11000 games, 0 failed. Commit(s): `a0d9641e3b`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 0.6 | 2000 | 48.9% (46.7%–51.1%) | 3.23 | 0.86 | 0.91 | 2.39 | 5.6% | 0.26 |
| 7 NPCs, bot insight 1.0 | 2000 | 55.0% (52.8%–57.2%) | 3.08 | 0.81 | 1.00 | 2.30 | 8.4% | 0.25 |
| 7 NPCs, passive | 2000 | 34.0% (31.9%–36.1%) | 3.43 | 1.00 | 0.70 | 2.31 | 3.1% | 0.27 |
| 10 NPCs, bot insight 0.6 | 1000 | 50.8% (47.7%–53.9%) | 4.32 | 1.18 | 1.50 | 2.61 | 3.1% | 0.41 |
| 10 NPCs, bot insight 1.0 | 2000 | 52.6% (50.4%–54.8%) | 4.23 | 1.16 | 1.50 | 2.51 | 6.9% | 0.39 |
| 10 NPCs, passive | 2000 | 40.1% (38.0%–42.3%) | 4.42 | 1.41 | 1.27 | 2.52 | 2.5% | 0.43 |

### End reasons and solvability

**7 NPCs, bot insight 0.6** (n=2000)

- Only two townsfolk remain and the demon still walks among them.: 1014 (50.7%)
- The demon's host was executed.: 978 (48.9%)
- Time ran out: the demon survived 6 days.: 4 (0.2%)
- (none): 4 (0.2%)
- Demon evidence on the board: 99.1% of games; good win rate 48.8% of 1981
- Demon evidence reachable: 83.4% of games; good win rate 45.3% of 1668
- Neither: 0.4% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot insight 1.0** (n=2000)

- The demon's host was executed.: 1100 (55.0%)
- Only two townsfolk remain and the demon still walks among them.: 898 (44.9%)
- (none): 1 (0.1%)
- Time ran out: the demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 98.8% of games; good win rate 54.5% of 1976
- Demon evidence reachable: 81.3% of games; good win rate 49.9% of 1626
- Neither: 0.7% of games; good win rate 100.0% of 14
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=2000)

- Only two townsfolk remain and the demon still walks among them.: 1318 (65.9%)
- The demon's host was executed.: 679 (34.0%)
- Time ran out: the demon survived 6 days.: 3 (0.1%)
- Demon evidence on the board: 59.6% of games; good win rate 44.1% of 1192
- Demon evidence reachable: 99.5% of games; good win rate 33.6% of 1990
- Neither: 0.4% of games; good win rate 100.0% of 9
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 0.6** (n=1000)

- The demon's host was executed.: 508 (50.8%)
- Only two townsfolk remain and the demon still walks among them.: 327 (32.7%)
- No good soul remains.: 162 (16.2%)
- (none): 2 (0.2%)
- Time ran out: the demon survived 8 days.: 1 (0.1%)
- Demon evidence on the board: 99.6% of games; good win rate 50.8% of 996
- Demon evidence reachable: 90.0% of games; good win rate 48.7% of 900
- Neither: 0.1% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=2000)

- The demon's host was executed.: 1052 (52.6%)
- Only two townsfolk remain and the demon still walks among them.: 640 (32.0%)
- No good soul remains.: 296 (14.8%)
- Time ran out: the demon survived 8 days.: 6 (0.3%)
- (none): 6 (0.3%)
- Demon evidence on the board: 99.5% of games; good win rate 52.7% of 1990
- Demon evidence reachable: 89.0% of games; good win rate 50.2% of 1781
- Neither: 0.2% of games; good win rate 50.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=2000)

- The demon's host was executed.: 802 (40.1%)
- Only two townsfolk remain and the demon still walks among them.: 625 (31.2%)
- No good soul remains.: 568 (28.4%)
- Time ran out: the demon survived 8 days.: 5 (0.2%)
- Demon evidence on the board: 74.9% of games; good win rate 44.5% of 1497
- Demon evidence reachable: 99.8% of games; good win rate 40.0% of 1996
- Neither: 0.2% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 0.6

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 583 | 41.7% | 1417 | 51.9% | -10.2 (-15.0 to -5.4) **\*** |
| lamplighter | 419 | 55.1% | 1581 | 47.2% | +7.9 (+2.5 to +13.2) **\*** |
| dowser | 591 | 54.3% | 1409 | 46.6% | +7.7 (+2.9 to +12.5) **\*** |
| psychologist | 126 | 42.1% | 1874 | 49.4% | -7.3 (-16.2 to +1.6) |
| martyr | 161 | 42.9% | 1839 | 49.4% | -6.6 (-14.6 to +1.4) |
| sexton | 155 | 43.9% | 1845 | 49.3% | -5.5 (-13.6 to +2.7) |
| medium | 377 | 44.8% | 1623 | 49.8% | -5.0 (-10.6 to +0.6) |
| warden | 476 | 52.5% | 1524 | 47.8% | +4.8 (-0.4 to +9.9) |
| seer | 351 | 52.4% | 1649 | 48.2% | +4.3 (-1.5 to +10.0) |
| magistrate | 138 | 46.4% | 1862 | 49.1% | -2.7 (-11.3 to +5.9) |
| monitor | 152 | 51.3% | 1848 | 48.7% | +2.6 (-5.7 to +10.9) |
| confessor | 433 | 50.8% | 1567 | 48.4% | +2.4 (-2.9 to +7.8) |
| nightwatch | 464 | 50.6% | 1536 | 48.4% | +2.3 (-2.9 to +7.5) |
| executor | 149 | 47.0% | 1851 | 49.1% | -2.1 (-10.4 to +6.3) |
| archivist | 1099 | 48.2% | 901 | 49.7% | -1.5 (-5.9 to +2.9) |
| rumormonger | 1069 | 48.3% | 931 | 49.6% | -1.4 (-5.7 to +3.0) |
| chronicler | 135 | 49.6% | 1865 | 48.8% | +0.8 (-8.0 to +9.5) |
| augur | 357 | 48.5% | 1643 | 49.0% | -0.5 (-6.3 to +5.2) |
| registrar | 539 | 48.6% | 1461 | 49.0% | -0.4 (-5.3 to +4.5) |
| surveyor | 1003 | 48.8% | 997 | 49.0% | -0.3 (-4.7 to +4.1) |
| veteran | 147 | 49.0% | 1853 | 48.9% | +0.1 (-8.3 to +8.5) |
| clerk | 1076 | 48.9% | 924 | 48.9% | -0.0 (-4.4 to +4.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 57.8% | 1540 | 46.2% | +11.6 (+6.4 to +16.7) **\*** |
| poisoner | 658 | 41.9% | 1342 | 52.3% | -10.4 (-15.0 to -5.7) **\*** |
| revenant | 447 | 52.1% | 1553 | 48.0% | +4.2 (-1.1 to +9.4) |
| scion | 435 | 46.7% | 1565 | 49.5% | -2.9 (-8.2 to +2.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 424 | 38.4% | 1576 | 51.7% | -13.3 (-18.5 to -8.0) **\*** |
| marked | 386 | 53.1% | 1614 | 47.9% | +5.2 (-0.3 to +10.8) |
| sleepwalker | 385 | 52.5% | 1615 | 48.0% | +4.4 (-1.1 to +10.0) |
| muddler | 392 | 51.0% | 1608 | 48.4% | +2.6 (-2.9 to +8.2) |
| lovers | 413 | 50.4% | 1587 | 48.5% | +1.8 (-3.6 to +7.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 50.5% | 1903 | 48.8% | +1.7 (-8.5 to +11.9) |
| 3 night-walkers | 633 | 48.2% | 1367 | 49.2% | -1.0 (-5.8 to +3.7) |
| 2 night-walkers | 1270 | 49.1% | 730 | 48.5% | +0.6 (-3.9 to +5.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 1.6 | 55.2% | 19.5% | 94.0% |
| clerk | 1076 | 2.4 | 20.8% | 23.2% | 93.6% |
| rumormonger | 1069 | 2.4 | 25.0% | 22.1% | 91.4% |
| surveyor | 1003 | 2.2 | 27.6% | 19.8% | 91.9% |
| dowser | 591 | 1.9 | 47.4% | 9.8% | 82.9% |
| gravedigger | 583 | 2.2 | 37.7% | 21.4% | 89.5% |
| registrar | 539 | 2.2 | 38.6% | 10.2% | 80.5% |
| warden | 476 | 2.5 | 20.0% | 20.6% | 79.2% |
| nightwatch | 464 | 2.1 | 33.2% | 17.0% | 85.3% |
| confessor | 433 | 2.2 | 33.9% | 10.6% | 82.9% |
| lamplighter | 419 | 2.3 | 30.1% | 3.3% | 84.7% |
| medium | 377 | 2.4 | 27.3% | 11.9% | 84.9% |
| augur | 357 | 2.3 | 30.3% | 10.4% | 80.1% |
| seer | 351 | 2.0 | 43.6% | 10.0% | 81.2% |
| martyr | 161 | 2.6 | 15.5% | 20.5% | 83.2% |
| sexton | 155 | 2.5 | 18.7% | 24.5% | 75.5% |
| monitor | 152 | 2.3 | 34.9% | 7.2% | 78.3% |
| executor | 149 | 2.5 | 32.2% | 16.8% | 76.5% |
| veteran | 147 | 3.1 | 4.1% | 25.9% | 86.4% |
| magistrate | 138 | 2.3 | 23.2% | 15.9% | 87.0% |
| chronicler | 135 | 2.2 | 31.1% | 20.7% | 76.3% |
| psychologist | 126 | 2.5 | 27.8% | 15.1% | 84.9% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 280 | 0.0% | 55.7% |
| registrar | 279 | 0.0% | 49.1% |
| confessor | 268 | 0.0% | 47.4% |
| lamplighter | 262 | 0.0% | 9.2% |
| medium | 254 | 0.0% | 28.7% |
| dowser | 248 | 0.0% | 54.0% |
| gravedigger | 227 | 0.0% | 60.4% |
| surveyor | 226 | 0.0% | 49.6% |
| clerk | 226 | 0.0% | 53.5% |
| rumormonger | 211 | 0.0% | 51.7% |
| archivist | 202 | 0.0% | 63.9% |
| chronicler | 175 | 0.0% | 50.9% |
| executor | 160 | 0.0% | 45.6% |
| psychologist | 159 | 0.0% | 37.7% |
| seer | 154 | 0.0% | 52.6% |
| monitor | 153 | 0.0% | 34.6% |
| magistrate | 151 | 0.0% | 53.6% |
| augur | 136 | 0.0% | 39.7% |
| warden | 37 | 0.0% | 40.5% |
| veteran | 31 | 0.0% | 38.7% |
| martyr | 27 | 0.0% | 22.2% |
| sexton | 23 | 0.0% | 52.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger + poisoner | 218 | 38.5% | 1782 | 50.2% | -11.6 (-18.5 to -4.8) |
| breathstealer + demon | 460 | 57.8% | 1540 | 46.2% | +11.6 (+6.4 to +16.7) |
| lamplighter + rumormonger | 225 | 58.7% | 1775 | 47.7% | +11.0 (+4.2 to +17.8) |
| clerk + poisoner | 361 | 39.9% | 1639 | 50.9% | -11.0 (-16.6 to -5.4) |
| breathstealer + surveyor | 220 | 58.6% | 1780 | 47.7% | +10.9 (+4.0 to +17.8) |
| gravedigger + surveyor | 288 | 39.6% | 1712 | 50.5% | -10.9 (-17.0 to -4.8) |
| poisoner + rumormonger | 372 | 40.1% | 1628 | 50.9% | -10.9 (-16.4 to -5.3) |
| clerk + lamplighter | 227 | 58.1% | 1773 | 47.7% | +10.4 (+3.6 to +17.3) |
| demon + poisoner | 658 | 41.9% | 1342 | 52.3% | -10.4 (-15.0 to -5.7) |
| demon + gravedigger | 583 | 41.7% | 1417 | 51.9% | -10.2 (-15.0 to -5.4) |

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 419 | 63.5% | 1581 | 52.8% | +10.7 (+5.5 to +16.0) **\*** |
| martyr | 161 | 45.3% | 1839 | 55.8% | -10.5 (-18.5 to -2.5) **\*** |
| gravedigger | 583 | 47.7% | 1417 | 58.0% | -10.3 (-15.1 to -5.5) **\*** |
| dowser | 591 | 60.2% | 1409 | 52.8% | +7.4 (+2.7 to +12.2) **\*** |
| sexton | 155 | 48.4% | 1845 | 55.6% | -7.2 (-15.4 to +1.0) |
| psychologist | 126 | 48.4% | 1874 | 55.4% | -7.0 (-16.0 to +2.0) |
| magistrate | 138 | 59.4% | 1862 | 54.7% | +4.7 (-3.8 to +13.2) |
| archivist | 1099 | 52.9% | 901 | 57.6% | -4.7 (-9.1 to -0.4) **\*** |
| nightwatch | 464 | 58.2% | 1536 | 54.0% | +4.2 (-1.0 to +9.3) |
| chronicler | 135 | 58.5% | 1865 | 54.7% | +3.8 (-4.8 to +12.4) |
| surveyor | 1003 | 56.5% | 997 | 53.5% | +3.1 (-1.3 to +7.4) |
| veteran | 147 | 52.4% | 1853 | 55.2% | -2.8 (-11.2 to +5.6) |
| medium | 377 | 53.8% | 1623 | 55.3% | -1.4 (-7.0 to +4.2) |
| warden | 476 | 54.2% | 1524 | 55.2% | -1.0 (-6.2 to +4.1) |
| clerk | 1076 | 55.5% | 924 | 54.4% | +1.0 (-3.3 to +5.4) |
| registrar | 539 | 55.7% | 1461 | 54.8% | +0.9 (-4.0 to +5.8) |
| rumormonger | 1069 | 54.6% | 931 | 55.4% | -0.8 (-5.2 to +3.6) |
| executor | 149 | 55.7% | 1851 | 54.9% | +0.8 (-7.5 to +9.1) |
| monitor | 152 | 54.6% | 1848 | 55.0% | -0.4 (-8.7 to +7.8) |
| seer | 351 | 54.7% | 1649 | 55.1% | -0.4 (-6.1 to +5.4) |
| confessor | 433 | 55.2% | 1567 | 54.9% | +0.3 (-5.0 to +5.5) |
| augur | 357 | 54.9% | 1643 | 55.0% | -0.1 (-5.8 to +5.6) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 64.1% | 1540 | 52.3% | +11.9 (+6.8 to +16.9) **\*** |
| poisoner | 658 | 50.9% | 1342 | 57.0% | -6.1 (-10.7 to -1.4) **\*** |
| scion | 435 | 52.2% | 1565 | 55.8% | -3.6 (-8.9 to +1.7) |
| revenant | 447 | 54.4% | 1553 | 55.2% | -0.8 (-6.1 to +4.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 424 | 44.8% | 1576 | 57.7% | -12.9 (-18.3 to -7.6) **\*** |
| lovers | 413 | 61.5% | 1587 | 53.3% | +8.2 (+2.9 to +13.5) **\*** |
| muddler | 392 | 58.4% | 1608 | 54.2% | +4.3 (-1.2 to +9.7) |
| sleepwalker | 385 | 56.9% | 1615 | 54.6% | +2.3 (-3.2 to +7.8) |
| marked | 386 | 53.9% | 1614 | 55.3% | -1.4 (-6.9 to +4.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 59.8% | 1903 | 54.8% | +5.0 (-5.0 to +15.0) |
| 2 night-walkers | 1270 | 54.1% | 730 | 56.6% | -2.5 (-7.0 to +2.0) |
| 3 night-walkers | 633 | 56.1% | 1367 | 54.5% | +1.6 (-3.1 to +6.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 1.6 | 53.5% | 19.8% | 94.3% |
| clerk | 1076 | 2.3 | 21.8% | 18.2% | 92.6% |
| rumormonger | 1069 | 2.3 | 24.3% | 21.0% | 90.8% |
| surveyor | 1003 | 2.1 | 25.9% | 18.7% | 92.1% |
| dowser | 591 | 1.8 | 49.4% | 10.2% | 82.1% |
| gravedigger | 583 | 2.1 | 37.4% | 19.0% | 87.5% |
| registrar | 539 | 2.1 | 34.3% | 9.5% | 77.9% |
| warden | 476 | 2.4 | 21.6% | 18.5% | 78.6% |
| nightwatch | 464 | 2.1 | 33.0% | 16.4% | 83.2% |
| confessor | 433 | 2.1 | 32.3% | 13.2% | 81.8% |
| lamplighter | 419 | 2.1 | 28.2% | 4.1% | 84.0% |
| medium | 377 | 2.2 | 24.9% | 12.7% | 77.7% |
| augur | 357 | 2.3 | 30.5% | 7.6% | 76.2% |
| seer | 351 | 2.0 | 40.7% | 12.5% | 79.8% |
| martyr | 161 | 2.4 | 14.9% | 20.5% | 84.5% |
| sexton | 155 | 2.3 | 20.0% | 25.2% | 76.1% |
| monitor | 152 | 2.3 | 28.3% | 9.2% | 77.6% |
| executor | 149 | 2.3 | 28.9% | 14.8% | 77.2% |
| veteran | 147 | 3.1 | 2.0% | 21.1% | 83.0% |
| magistrate | 138 | 2.1 | 28.3% | 16.7% | 80.4% |
| chronicler | 135 | 2.1 | 28.1% | 15.6% | 77.0% |
| psychologist | 126 | 2.4 | 23.0% | 13.5% | 83.3% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 277 | 0.0% | 66.1% |
| registrar | 274 | 0.0% | 55.8% |
| confessor | 271 | 0.0% | 52.4% |
| lamplighter | 260 | 0.0% | 13.5% |
| medium | 251 | 0.0% | 35.1% |
| dowser | 250 | 0.0% | 61.2% |
| clerk | 226 | 0.0% | 57.1% |
| surveyor | 226 | 0.0% | 50.4% |
| gravedigger | 225 | 0.0% | 69.8% |
| rumormonger | 214 | 0.0% | 56.5% |
| archivist | 203 | 0.0% | 66.5% |
| chronicler | 172 | 0.0% | 58.7% |
| executor | 163 | 0.0% | 47.9% |
| psychologist | 157 | 0.0% | 40.1% |
| monitor | 150 | 0.0% | 38.0% |
| seer | 149 | 0.0% | 51.7% |
| magistrate | 147 | 0.0% | 55.1% |
| augur | 132 | 0.0% | 42.4% |
| warden | 38 | 0.0% | 44.7% |
| veteran | 30 | 0.0% | 43.3% |
| martyr | 25 | 0.0% | 32.0% |
| sexton | 24 | 0.0% | 29.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + surveyor | 220 | 65.9% | 1780 | 53.7% | +12.3 (+5.6 to +18.9) |
| breathstealer + demon | 460 | 64.1% | 1540 | 52.3% | +11.9 (+6.8 to +16.9) |
| breathstealer + clerk | 252 | 65.1% | 1748 | 53.5% | +11.5 (+5.2 to +17.9) |
| clerk + lamplighter | 227 | 65.2% | 1773 | 53.7% | +11.5 (+4.9 to +18.1) |
| archivist + gravedigger | 321 | 45.8% | 1679 | 56.8% | -11.0 (-16.9 to -5.0) |
| gravedigger + poisoner | 218 | 45.4% | 1782 | 56.2% | -10.8 (-17.8 to -3.8) |
| demon + lamplighter | 419 | 63.5% | 1581 | 52.8% | +10.7 (+5.5 to +16.0) |
| demon + gravedigger | 583 | 47.7% | 1417 | 58.0% | -10.3 (-15.1 to -5.5) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 583 | 26.4% | 1417 | 37.1% | -10.6 (-15.0 to -6.3) **\*** |
| executor | 149 | 24.8% | 1851 | 34.7% | -9.9 (-17.1 to -2.6) **\*** |
| dowser | 591 | 40.8% | 1409 | 31.1% | +9.7 (+5.1 to +14.3) **\*** |
| nightwatch | 464 | 41.4% | 1536 | 31.7% | +9.7 (+4.6 to +14.7) **\*** |
| monitor | 152 | 25.7% | 1848 | 34.6% | -9.0 (-16.2 to -1.7) **\*** |
| warden | 476 | 39.1% | 1524 | 32.3% | +6.7 (+1.8 to +11.7) **\*** |
| martyr | 161 | 28.6% | 1839 | 34.4% | -5.8 (-13.2 to +1.5) |
| medium | 377 | 29.4% | 1623 | 35.0% | -5.6 (-10.7 to -0.4) **\*** |
| surveyor | 1003 | 36.6% | 997 | 31.3% | +5.3 (+1.2 to +9.4) **\*** |
| lamplighter | 419 | 37.9% | 1581 | 32.9% | +5.1 (-0.1 to +10.2) |
| psychologist | 126 | 38.1% | 1874 | 33.7% | +4.4 (-4.3 to +13.2) |
| clerk | 1076 | 32.2% | 924 | 35.9% | -3.7 (-7.8 to +0.5) |
| augur | 357 | 31.1% | 1643 | 34.6% | -3.5 (-8.8 to +1.8) |
| chronicler | 135 | 31.1% | 1865 | 34.2% | -3.0 (-11.1 to +5.1) |
| archivist | 1099 | 32.7% | 901 | 35.5% | -2.9 (-7.0 to +1.3) |
| confessor | 433 | 35.6% | 1567 | 33.5% | +2.1 (-3.0 to +7.1) |
| sexton | 155 | 32.3% | 1845 | 34.1% | -1.8 (-9.5 to +5.8) |
| registrar | 539 | 32.7% | 1461 | 34.4% | -1.8 (-6.4 to +2.9) |
| magistrate | 138 | 32.6% | 1862 | 34.0% | -1.4 (-9.6 to +6.7) |
| veteran | 147 | 32.7% | 1853 | 34.1% | -1.4 (-9.3 to +6.5) |
| seer | 351 | 34.5% | 1649 | 33.8% | +0.6 (-4.8 to +6.1) |
| rumormonger | 1069 | 33.9% | 931 | 34.0% | -0.2 (-4.3 to +4.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 45.2% | 1540 | 30.6% | +14.6 (+9.5 to +19.7) **\*** |
| poisoner | 658 | 28.7% | 1342 | 36.5% | -7.8 (-12.1 to -3.5) **\*** |
| revenant | 447 | 30.0% | 1553 | 35.1% | -5.1 (-10.0 to -0.3) **\*** |
| scion | 435 | 34.0% | 1565 | 33.9% | +0.1 (-4.9 to +5.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 424 | 21.0% | 1576 | 37.4% | -16.4 (-21.0 to -11.9) **\*** |
| lovers | 413 | 39.5% | 1587 | 32.5% | +7.0 (+1.7 to +12.2) **\*** |
| sleepwalker | 385 | 38.2% | 1615 | 32.9% | +5.2 (-0.1 to +10.6) |
| muddler | 392 | 37.0% | 1608 | 33.2% | +3.8 (-1.5 to +9.1) |
| marked | 386 | 35.0% | 1614 | 33.7% | +1.3 (-4.0 to +6.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 41.2% | 1903 | 33.6% | +7.7 (-2.4 to +17.7) |
| 2 night-walkers | 1270 | 32.0% | 730 | 37.3% | -5.2 (-9.6 to -0.9) **\*** |
| 3 night-walkers | 633 | 36.7% | 1367 | 32.7% | +4.0 (-0.6 to +8.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 1.7 | 58.3% | 21.2% | 94.9% |
| clerk | 1076 | 2.6 | 22.6% | 29.3% | 93.8% |
| rumormonger | 1069 | 2.5 | 25.9% | 27.3% | 93.3% |
| surveyor | 1003 | 2.5 | 26.4% | 26.7% | 93.9% |
| dowser | 591 | 1.9 | 56.3% | 9.3% | 87.1% |
| gravedigger | 583 | 2.2 | 45.8% | 22.5% | 87.7% |
| registrar | 539 | 2.3 | 38.6% | 11.5% | 84.0% |
| warden | 476 | 2.6 | 22.3% | 18.3% | 80.0% |
| nightwatch | 464 | 2.2 | 36.6% | 15.7% | 85.8% |
| confessor | 433 | 2.4 | 37.0% | 11.8% | 87.8% |
| lamplighter | 419 | 2.4 | 32.0% | 1.9% | 85.2% |
| medium | 377 | 2.4 | 31.6% | 15.6% | 83.6% |
| augur | 357 | 2.5 | 33.3% | 10.1% | 82.9% |
| seer | 351 | 2.1 | 47.6% | 13.7% | 84.0% |
| martyr | 161 | 2.8 | 18.6% | 31.1% | 84.5% |
| sexton | 155 | 2.7 | 20.6% | 32.3% | 80.6% |
| monitor | 152 | 2.6 | 31.6% | 15.8% | 81.6% |
| executor | 149 | 2.5 | 31.5% | 23.5% | 82.6% |
| veteran | 147 | 3.4 | 5.4% | 44.2% | 89.1% |
| magistrate | 138 | 2.3 | 35.5% | 18.1% | 88.4% |
| chronicler | 135 | 2.5 | 30.4% | 15.6% | 84.4% |
| psychologist | 126 | 2.6 | 22.2% | 15.1% | 85.7% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 279 | 0.0% | 49.8% |
| nightwatch | 275 | 0.0% | 26.2% |
| confessor | 268 | 0.0% | 31.7% |
| lamplighter | 266 | 0.0% | 1.9% |
| medium | 261 | 0.0% | 19.5% |
| dowser | 249 | 0.0% | 40.6% |
| surveyor | 226 | 0.0% | 36.7% |
| clerk | 226 | 0.0% | 46.9% |
| gravedigger | 225 | 0.0% | 52.4% |
| rumormonger | 213 | 0.0% | 45.5% |
| archivist | 202 | 0.0% | 57.4% |
| chronicler | 174 | 0.0% | 44.8% |
| executor | 164 | 0.0% | 36.6% |
| psychologist | 159 | 0.0% | 23.9% |
| magistrate | 154 | 0.0% | 42.9% |
| monitor | 153 | 0.0% | 28.1% |
| seer | 152 | 0.0% | 33.6% |
| augur | 136 | 0.0% | 25.7% |
| warden | 42 | 0.0% | 26.2% |
| veteran | 30 | 0.0% | 23.3% |
| martyr | 27 | 0.0% | 37.0% |
| sexton | 24 | 0.0% | 45.8% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| archivist + breathstealer | 254 | 47.6% | 1746 | 32.0% | +15.7 (+9.2 to +22.2) |
| breathstealer + demon | 460 | 45.2% | 1540 | 30.6% | +14.6 (+9.5 to +19.7) |
| clerk + gravedigger | 309 | 22.0% | 1691 | 36.1% | -14.1 (-19.3 to -9.0) |
| breathstealer + surveyor | 220 | 45.9% | 1780 | 32.5% | +13.4 (+6.5 to +20.4) |
| nightwatch + surveyor | 230 | 44.3% | 1770 | 32.6% | +11.7 (+5.0 to +18.5) |
| archivist + revenant | 256 | 23.8% | 1744 | 35.4% | -11.6 (-17.3 to -5.9) |
| breathstealer + clerk | 252 | 44.0% | 1748 | 32.5% | +11.6 (+5.0 to +18.1) |
| nightwatch + rumormonger | 251 | 43.8% | 1749 | 32.5% | +11.3 (+4.8 to +17.8) |
| demon + gravedigger | 583 | 26.4% | 1417 | 37.1% | -10.6 (-15.0 to -6.3) |
| dowser + surveyor | 277 | 43.0% | 1723 | 32.5% | +10.5 (+4.2 to +16.7) |
| dowser + rumormonger | 321 | 42.7% | 1679 | 32.3% | +10.4 (+4.5 to +16.3) |
| breathstealer + rumormonger | 251 | 43.0% | 1749 | 32.6% | +10.4 (+3.9 to +16.9) |
| clerk + poisoner | 361 | 25.5% | 1639 | 35.8% | -10.3 (-15.4 to -5.3) |

### 10 NPCs, bot insight 0.6

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 382 | 59.4% | 618 | 45.5% | +14.0 (+7.7 to +20.3) **\*** |
| executor | 147 | 42.9% | 853 | 52.2% | -9.3 (-18.0 to -0.6) **\*** |
| sexton | 148 | 43.2% | 852 | 52.1% | -8.9 (-17.5 to -0.2) **\*** |
| clerk | 581 | 47.8% | 419 | 54.9% | -7.0 (-13.3 to -0.8) **\*** |
| augur | 231 | 45.5% | 769 | 52.4% | -7.0 (-14.3 to +0.4) |
| registrar | 377 | 54.9% | 623 | 48.3% | +6.6 (+0.2 to +13.0) **\*** |
| chronicler | 137 | 46.7% | 863 | 51.4% | -4.7 (-13.7 to +4.3) |
| monitor | 144 | 54.2% | 856 | 50.2% | +3.9 (-4.9 to +12.7) |
| gravedigger | 358 | 48.3% | 642 | 52.2% | -3.9 (-10.3 to +2.6) |
| psychologist | 148 | 48.0% | 852 | 51.3% | -3.3 (-12.0 to +5.4) |
| confessor | 389 | 52.7% | 611 | 49.6% | +3.1 (-3.2 to +9.5) |
| nightwatch | 396 | 52.5% | 604 | 49.7% | +2.9 (-3.5 to +9.2) |
| seer | 225 | 48.9% | 775 | 51.4% | -2.5 (-9.9 to +5.0) |
| veteran | 172 | 49.4% | 828 | 51.1% | -1.7 (-9.9 to +6.5) |
| martyr | 156 | 51.9% | 844 | 50.6% | +1.3 (-7.2 to +9.9) |
| magistrate | 135 | 51.9% | 865 | 50.6% | +1.2 (-7.8 to +10.3) |
| warden | 377 | 51.5% | 623 | 50.4% | +1.1 (-5.3 to +7.5) |
| archivist | 563 | 51.2% | 437 | 50.3% | +0.8 (-5.4 to +7.1) |
| rumormonger | 590 | 51.0% | 410 | 50.5% | +0.5 (-5.8 to +6.8) |
| medium | 384 | 51.0% | 616 | 50.6% | +0.4 (-6.0 to +6.8) |
| surveyor | 588 | 50.9% | 412 | 50.7% | +0.1 (-6.2 to +6.4) |
| dowser | 372 | 50.8% | 628 | 50.8% | +0.0 (-6.4 to +6.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 60.1% | 559 | 43.5% | +16.6 (+10.5 to +22.8) **\*** |
| scion | 467 | 43.0% | 533 | 57.6% | -14.6 (-20.7 to -8.4) **\*** |
| poisoner | 620 | 48.1% | 380 | 55.3% | -7.2 (-13.6 to -0.8) **\*** |
| revenant | 472 | 53.4% | 528 | 48.5% | +4.9 (-1.3 to +11.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 44.9% | 784 | 52.4% | -7.5 (-15.0 to -0.0) **\*** |
| muddler | 191 | 54.5% | 809 | 49.9% | +4.5 (-3.3 to +12.4) |
| sleepwalker | 207 | 53.1% | 793 | 50.2% | +3.0 (-4.7 to +10.6) |
| lovers | 195 | 51.3% | 805 | 50.7% | +0.6 (-7.2 to +8.4) |
| marked | 191 | 50.8% | 809 | 50.8% | -0.0 (-7.9 to +7.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 64.8% | 909 | 49.4% | +15.4 (+5.1 to +25.8) **\*** |
| 3 night-walkers | 543 | 47.0% | 457 | 55.4% | -8.4 (-14.6 to -2.2) **\*** |
| 4 night-walkers | 366 | 53.0% | 634 | 49.5% | +3.5 (-2.9 to +9.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 14.1% | 22.7% | 94.2% |
| surveyor | 588 | 3.3 | 16.5% | 23.0% | 94.9% |
| clerk | 581 | 3.4 | 10.8% | 25.6% | 96.6% |
| archivist | 563 | 2.0 | 54.0% | 13.0% | 94.5% |
| nightwatch | 396 | 2.5 | 31.3% | 17.9% | 89.6% |
| confessor | 389 | 2.9 | 20.6% | 16.5% | 88.9% |
| medium | 384 | 2.9 | 20.6% | 11.5% | 85.7% |
| lamplighter | 382 | 3.0 | 24.1% | 1.6% | 90.1% |
| warden | 377 | 3.2 | 15.9% | 22.0% | 84.1% |
| registrar | 377 | 2.7 | 26.3% | 9.0% | 84.4% |
| dowser | 372 | 2.1 | 49.5% | 12.6% | 90.1% |
| gravedigger | 358 | 2.5 | 31.0% | 20.4% | 91.3% |
| augur | 231 | 3.2 | 17.7% | 7.8% | 85.7% |
| seer | 225 | 2.4 | 35.6% | 12.0% | 86.7% |
| veteran | 172 | 3.8 | 2.9% | 26.2% | 89.0% |
| martyr | 156 | 3.5 | 9.0% | 15.4% | 89.7% |
| psychologist | 148 | 2.8 | 30.4% | 12.8% | 79.1% |
| sexton | 148 | 3.4 | 11.5% | 33.1% | 85.8% |
| executor | 147 | 3.2 | 17.0% | 15.6% | 90.5% |
| monitor | 144 | 2.9 | 18.1% | 9.7% | 83.3% |
| chronicler | 137 | 2.8 | 20.4% | 17.5% | 82.5% |
| magistrate | 135 | 2.6 | 31.9% | 14.8% | 83.7% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 215 | 0.0% | 52.6% |
| dowser | 201 | 0.0% | 63.2% |
| archivist | 197 | 0.0% | 61.4% |
| gravedigger | 194 | 0.0% | 69.1% |
| clerk | 190 | 0.0% | 66.3% |
| confessor | 183 | 0.0% | 47.5% |
| rumormonger | 181 | 0.0% | 58.6% |
| surveyor | 176 | 0.0% | 52.3% |
| medium | 169 | 0.0% | 24.3% |
| lamplighter | 164 | 0.0% | 3.7% |
| nightwatch | 163 | 0.0% | 66.3% |
| magistrate | 129 | 0.0% | 61.2% |
| augur | 121 | 0.0% | 42.1% |
| chronicler | 111 | 0.0% | 49.5% |
| psychologist | 108 | 0.0% | 32.4% |
| monitor | 107 | 0.0% | 37.4% |
| seer | 103 | 0.0% | 62.1% |
| executor | 97 | 0.0% | 48.5% |
| sexton | 33 | 0.0% | 51.5% |
| veteran | 27 | 0.0% | 37.0% |
| martyr | 20 | 0.0% | 50.0% |
| warden | 20 | 0.0% | 35.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner + scion | 215 | 34.4% | 785 | 55.3% | -20.9 (-28.1 to -13.6) |
| breathstealer + surveyor | 261 | 63.6% | 739 | 46.3% | +17.3 (+10.5 to +24.2) |
| breathstealer + demon | 441 | 60.1% | 559 | 43.5% | +16.6 (+10.5 to +22.8) |
| lamplighter + rumormonger | 212 | 63.2% | 788 | 47.5% | +15.7 (+8.4 to +23.1) |
| clerk + scion | 273 | 39.6% | 727 | 55.0% | -15.5 (-22.3 to -8.6) |
| demon + scion | 467 | 43.0% | 533 | 57.6% | -14.6 (-20.7 to -8.4) |
| demon + lamplighter | 382 | 59.4% | 618 | 45.5% | +14.0 (+7.7 to +20.3) |
| archivist + breathstealer | 243 | 61.3% | 757 | 47.4% | +13.9 (+6.8 to +21.0) |
| archivist + lamplighter | 207 | 60.9% | 793 | 48.2% | +12.7 (+5.2 to +20.2) |
| rumormonger + scion | 276 | 41.7% | 724 | 54.3% | -12.6 (-19.5 to -5.8) |
| breathstealer + rumormonger | 264 | 59.8% | 736 | 47.6% | +12.3 (+5.4 to +19.2) |
| scion + surveyor | 267 | 43.4% | 733 | 53.5% | -10.0 (-17.0 to -3.1) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 777 | 61.0% | 1223 | 47.3% | +13.7 (+9.3 to +18.2) **\*** |
| executor | 328 | 46.6% | 1672 | 53.8% | -7.1 (-13.0 to -1.2) **\*** |
| sexton | 310 | 48.1% | 1690 | 53.4% | -5.4 (-11.4 to +0.7) |
| archivist | 1117 | 50.3% | 883 | 55.5% | -5.2 (-9.6 to -0.8) **\*** |
| augur | 453 | 49.4% | 1547 | 53.5% | -4.1 (-9.3 to +1.2) |
| chronicler | 273 | 49.1% | 1727 | 53.2% | -4.1 (-10.5 to +2.3) |
| warden | 773 | 50.3% | 1227 | 54.0% | -3.7 (-8.2 to +0.8) |
| seer | 468 | 49.8% | 1532 | 53.5% | -3.7 (-8.8 to +1.5) |
| nightwatch | 773 | 54.7% | 1227 | 51.3% | +3.5 (-1.0 to +7.9) |
| dowser | 711 | 54.7% | 1289 | 51.4% | +3.3 (-1.3 to +7.8) |
| surveyor | 1166 | 53.7% | 834 | 51.1% | +2.6 (-1.8 to +7.0) |
| gravedigger | 761 | 51.0% | 1239 | 53.6% | -2.6 (-7.1 to +1.9) |
| psychologist | 293 | 51.2% | 1707 | 52.8% | -1.6 (-7.8 to +4.5) |
| registrar | 718 | 53.6% | 1282 | 52.0% | +1.6 (-3.0 to +6.2) |
| medium | 720 | 53.6% | 1280 | 52.0% | +1.6 (-3.0 to +6.1) |
| confessor | 785 | 53.5% | 1215 | 52.0% | +1.5 (-3.0 to +6.0) |
| magistrate | 286 | 51.7% | 1714 | 52.7% | -1.0 (-7.2 to +5.3) |
| martyr | 320 | 51.9% | 1680 | 52.7% | -0.9 (-6.8 to +5.1) |
| clerk | 1181 | 52.8% | 819 | 52.3% | +0.6 (-3.9 to +5.0) |
| monitor | 305 | 52.8% | 1695 | 52.6% | +0.2 (-5.9 to +6.3) |
| rumormonger | 1158 | 52.7% | 842 | 52.5% | +0.2 (-4.2 to +4.6) |
| veteran | 324 | 52.5% | 1676 | 52.6% | -0.2 (-6.1 to +5.8) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| scion | 913 | 44.0% | 1087 | 59.8% | -15.8 (-20.1 to -11.4) **\*** |
| breathstealer | 893 | 60.9% | 1107 | 45.9% | +15.0 (+10.7 to +19.4) **\*** |
| revenant | 950 | 55.5% | 1050 | 50.0% | +5.5 (+1.1 to +9.8) **\*** |
| poisoner | 1244 | 50.7% | 756 | 55.7% | -5.0 (-9.5 to -0.5) **\*** |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 427 | 48.7% | 1573 | 53.7% | -4.9 (-10.3 to +0.4) |
| marked | 385 | 55.8% | 1615 | 51.8% | +4.0 (-1.5 to +9.5) |
| muddler | 384 | 55.2% | 1616 | 52.0% | +3.2 (-2.3 to +8.8) |
| sleepwalker | 426 | 50.9% | 1574 | 53.0% | -2.1 (-7.5 to +3.2) |
| lovers | 378 | 52.9% | 1622 | 52.5% | +0.4 (-5.2 to +6.0) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 177 | 61.0% | 1823 | 51.8% | +9.2 (+1.7 to +16.8) **\*** |
| 3 night-walkers | 1105 | 49.0% | 895 | 57.1% | -8.1 (-12.5 to -3.8) **\*** |
| 4 night-walkers | 718 | 56.1% | 1282 | 50.6% | +5.5 (+1.0 to +10.1) **\*** |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 1181 | 3.3 | 12.9% | 22.8% | 94.2% |
| surveyor | 1166 | 3.2 | 17.5% | 20.2% | 92.5% |
| rumormonger | 1158 | 3.3 | 13.0% | 23.4% | 93.6% |
| archivist | 1117 | 1.9 | 53.4% | 13.8% | 94.4% |
| confessor | 785 | 2.7 | 23.8% | 14.5% | 87.8% |
| lamplighter | 777 | 2.9 | 23.2% | 2.3% | 89.2% |
| nightwatch | 773 | 2.5 | 29.0% | 19.8% | 88.2% |
| warden | 773 | 3.2 | 15.7% | 21.5% | 83.8% |
| gravedigger | 761 | 2.5 | 30.2% | 20.5% | 90.3% |
| medium | 720 | 2.9 | 19.3% | 9.0% | 85.1% |
| registrar | 718 | 2.7 | 26.2% | 10.0% | 85.7% |
| dowser | 711 | 2.2 | 45.6% | 11.8% | 91.0% |
| seer | 468 | 2.5 | 36.5% | 11.8% | 82.5% |
| augur | 453 | 3.1 | 20.5% | 7.5% | 84.3% |
| executor | 328 | 3.0 | 21.3% | 11.6% | 83.2% |
| veteran | 324 | 3.9 | 4.3% | 27.5% | 86.4% |
| martyr | 320 | 3.5 | 9.7% | 17.8% | 86.2% |
| sexton | 310 | 3.3 | 9.7% | 34.2% | 83.5% |
| monitor | 305 | 3.1 | 18.0% | 12.1% | 80.3% |
| psychologist | 293 | 3.1 | 19.1% | 9.6% | 82.3% |
| magistrate | 286 | 2.6 | 29.0% | 16.1% | 85.0% |
| chronicler | 273 | 2.9 | 20.1% | 18.3% | 85.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 406 | 0.0% | 68.7% |
| registrar | 398 | 0.0% | 48.7% |
| archivist | 391 | 0.0% | 60.4% |
| rumormonger | 386 | 0.0% | 61.9% |
| gravedigger | 374 | 0.0% | 72.2% |
| clerk | 365 | 0.0% | 59.7% |
| confessor | 349 | 0.0% | 46.7% |
| surveyor | 348 | 0.0% | 54.6% |
| medium | 343 | 0.0% | 21.6% |
| lamplighter | 326 | 0.0% | 3.7% |
| nightwatch | 325 | 0.0% | 72.0% |
| magistrate | 240 | 0.0% | 63.7% |
| chronicler | 233 | 0.0% | 61.4% |
| monitor | 231 | 0.0% | 35.1% |
| augur | 222 | 0.0% | 37.8% |
| psychologist | 219 | 0.0% | 31.1% |
| seer | 212 | 0.0% | 55.2% |
| executor | 209 | 0.0% | 44.5% |
| warden | 60 | 0.0% | 51.7% |
| sexton | 50 | 0.0% | 38.0% |
| veteran | 45 | 0.0% | 44.4% |
| martyr | 45 | 0.0% | 31.1% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner + scion | 396 | 35.1% | 1604 | 56.9% | -21.8 (-27.1 to -16.5) |
| breathstealer + lamplighter | 364 | 69.5% | 1636 | 48.8% | +20.7 (+15.4 to +26.0) |
| scion + seer | 202 | 36.1% | 1798 | 54.4% | -18.3 (-25.3 to -11.3) |
| demon + scion | 913 | 44.0% | 1087 | 59.8% | -15.8 (-20.1 to -11.4) |
| breathstealer + revenant | 239 | 66.1% | 1761 | 50.8% | +15.3 (+8.9 to +21.8) |
| breathstealer + demon | 893 | 60.9% | 1107 | 45.9% | +15.0 (+10.7 to +19.4) |
| dowser + lamplighter | 262 | 65.6% | 1738 | 50.6% | +15.0 (+8.8 to +21.2) |
| confessor + lamplighter | 219 | 65.3% | 1781 | 51.0% | +14.3 (+7.5 to +21.0) |
| lamplighter + registrar | 268 | 64.6% | 1732 | 50.8% | +13.8 (+7.6 to +20.0) |
| demon + lamplighter | 777 | 61.0% | 1223 | 47.3% | +13.7 (+9.3 to +18.2) |
| breathstealer + registrar | 294 | 64.3% | 1706 | 50.6% | +13.7 (+7.7 to +19.7) |
| breathstealer + surveyor | 525 | 62.7% | 1475 | 49.0% | +13.6 (+8.8 to +18.5) |
| lamplighter + nightwatch | 229 | 64.6% | 1771 | 51.0% | +13.6 (+7.0 to +20.2) |
| rumormonger + scion | 522 | 42.7% | 1478 | 56.1% | -13.4 (-18.3 to -8.4) |
| lamplighter + medium | 219 | 64.4% | 1781 | 51.2% | +13.2 (+6.5 to +20.0) |
| augur + scion | 214 | 41.1% | 1786 | 54.0% | -12.9 (-19.8 to -5.9) |
| gravedigger + scion | 333 | 42.0% | 1667 | 54.7% | -12.7 (-18.5 to -6.9) |
| lamplighter + surveyor | 462 | 62.3% | 1538 | 49.7% | +12.7 (+7.6 to +17.7) |
| breathstealer + poisoner | 412 | 62.6% | 1588 | 50.0% | +12.6 (+7.3 to +17.9) |
| breathstealer + clerk | 532 | 61.7% | 1468 | 49.3% | +12.3 (+7.5 to +17.2) |
| clerk + scion | 547 | 43.7% | 1453 | 56.0% | -12.3 (-17.1 to -7.4) |
| lamplighter + revenant | 374 | 62.6% | 1626 | 50.3% | +12.3 (+6.8 to +17.7) |
| breathstealer + rumormonger | 520 | 61.2% | 1480 | 49.6% | +11.6 (+6.7 to +16.5) |
| archivist + scion | 512 | 44.3% | 1488 | 55.4% | -11.1 (-16.1 to -6.1) |
| breathstealer + medium | 350 | 61.7% | 1650 | 50.7% | +11.0 (+5.4 to +16.7) |
| breathstealer + confessor | 353 | 61.5% | 1647 | 50.7% | +10.8 (+5.2 to +16.4) |
| breathstealer + nightwatch | 379 | 61.2% | 1621 | 50.6% | +10.6 (+5.2 to +16.1) |
| archivist + lamplighter | 420 | 61.0% | 1580 | 50.4% | +10.6 (+5.3 to +15.8) |
| clerk + lamplighter | 448 | 60.7% | 1552 | 50.3% | +10.5 (+5.3 to +15.6) |
| breathstealer + dowser | 304 | 61.2% | 1696 | 51.1% | +10.1 (+4.2 to +16.1) |
| scion + warden | 378 | 44.4% | 1622 | 54.5% | -10.1 (-15.6 to -4.5) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 777 | 47.5% | 1223 | 35.4% | +12.1 (+7.7 to +16.5) **\*** |
| nightwatch | 773 | 44.4% | 1227 | 37.4% | +7.0 (+2.5 to +11.4) **\*** |
| chronicler | 273 | 35.2% | 1727 | 40.9% | -5.7 (-11.8 to +0.4) |
| sexton | 310 | 35.8% | 1690 | 40.9% | -5.1 (-10.9 to +0.7) |
| rumormonger | 1158 | 38.1% | 842 | 42.9% | -4.8 (-9.1 to -0.4) **\*** |
| dowser | 711 | 43.2% | 1289 | 38.4% | +4.8 (+0.3 to +9.3) **\*** |
| seer | 468 | 37.0% | 1532 | 41.1% | -4.1 (-9.1 to +0.9) |
| gravedigger | 761 | 37.7% | 1239 | 41.6% | -3.9 (-8.3 to +0.6) |
| archivist | 1117 | 38.4% | 883 | 42.2% | -3.8 (-8.2 to +0.5) |
| monitor | 305 | 37.7% | 1695 | 40.5% | -2.8 (-8.7 to +3.1) |
| augur | 453 | 38.2% | 1547 | 40.7% | -2.5 (-7.6 to +2.6) |
| clerk | 1181 | 41.1% | 819 | 38.7% | +2.4 (-2.0 to +6.7) |
| veteran | 324 | 38.3% | 1676 | 40.5% | -2.2 (-8.0 to +3.6) |
| martyr | 320 | 38.8% | 1680 | 40.4% | -1.6 (-7.4 to +4.2) |
| surveyor | 1166 | 40.7% | 834 | 39.2% | +1.5 (-2.8 to +5.9) |
| executor | 328 | 39.0% | 1672 | 40.3% | -1.3 (-7.1 to +4.5) |
| magistrate | 286 | 39.2% | 1714 | 40.3% | -1.1 (-7.2 to +5.0) |
| registrar | 718 | 39.6% | 1282 | 40.4% | -0.9 (-5.3 to +3.6) |
| psychologist | 293 | 40.6% | 1707 | 40.0% | +0.6 (-5.5 to +6.7) |
| confessor | 785 | 40.4% | 1215 | 39.9% | +0.5 (-3.9 to +4.9) |
| warden | 773 | 40.4% | 1227 | 39.9% | +0.4 (-4.0 to +4.8) |
| medium | 720 | 40.3% | 1280 | 40.0% | +0.3 (-4.2 to +4.8) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 893 | 49.6% | 1107 | 32.4% | +17.2 (+12.9 to +21.5) **\*** |
| poisoner | 1244 | 36.3% | 756 | 46.4% | -10.2 (-14.6 to -5.7) **\*** |
| scion | 913 | 35.6% | 1087 | 43.9% | -8.3 (-12.6 to -4.0) **\*** |
| revenant | 950 | 40.5% | 1050 | 39.7% | +0.8 (-3.5 to +5.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 427 | 32.3% | 1573 | 42.2% | -9.9 (-15.0 to -4.8) **\*** |
| marked | 385 | 46.5% | 1615 | 38.6% | +7.9 (+2.4 to +13.4) **\*** |
| sleepwalker | 426 | 35.9% | 1574 | 41.2% | -5.3 (-10.5 to -0.2) **\*** |
| muddler | 384 | 44.3% | 1616 | 39.1% | +5.2 (-0.3 to +10.7) |
| lovers | 378 | 42.9% | 1622 | 39.5% | +3.4 (-2.1 to +8.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 177 | 46.9% | 1823 | 39.4% | +7.5 (-0.2 to +15.1) |
| 3 night-walkers | 1105 | 36.8% | 895 | 44.1% | -7.3 (-11.6 to -3.0) **\*** |
| 4 night-walkers | 718 | 43.5% | 1282 | 38.2% | +5.2 (+0.7 to +9.7) **\*** |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 1181 | 3.4 | 11.9% | 32.4% | 95.6% |
| surveyor | 1166 | 3.4 | 15.3% | 28.1% | 95.5% |
| rumormonger | 1158 | 3.4 | 14.3% | 29.3% | 95.0% |
| archivist | 1117 | 2.0 | 57.6% | 16.6% | 96.0% |
| confessor | 785 | 2.9 | 24.7% | 13.5% | 92.1% |
| lamplighter | 777 | 2.9 | 24.3% | 3.5% | 89.3% |
| warden | 773 | 3.3 | 15.4% | 23.7% | 89.1% |
| nightwatch | 773 | 2.5 | 33.8% | 20.6% | 89.5% |
| gravedigger | 761 | 2.6 | 31.0% | 21.8% | 89.4% |
| medium | 720 | 2.9 | 22.9% | 10.6% | 88.9% |
| registrar | 718 | 2.9 | 28.6% | 13.6% | 88.2% |
| dowser | 711 | 2.0 | 57.0% | 9.6% | 91.1% |
| seer | 468 | 2.4 | 42.1% | 15.6% | 88.7% |
| augur | 453 | 3.3 | 18.3% | 11.9% | 87.2% |
| executor | 328 | 3.3 | 17.4% | 16.5% | 89.0% |
| veteran | 324 | 4.1 | 2.5% | 39.8% | 91.0% |
| martyr | 320 | 3.7 | 9.4% | 23.1% | 88.1% |
| sexton | 310 | 3.4 | 11.3% | 37.7% | 83.9% |
| monitor | 305 | 3.2 | 21.0% | 15.7% | 85.6% |
| psychologist | 293 | 3.2 | 19.5% | 13.3% | 85.3% |
| magistrate | 286 | 2.6 | 29.7% | 15.4% | 86.0% |
| chronicler | 273 | 2.9 | 21.6% | 20.9% | 89.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 415 | 0.0% | 51.8% |
| registrar | 405 | 0.0% | 50.9% |
| archivist | 395 | 0.0% | 55.7% |
| rumormonger | 385 | 0.0% | 54.8% |
| gravedigger | 383 | 0.0% | 65.8% |
| clerk | 368 | 0.0% | 58.2% |
| confessor | 358 | 0.0% | 34.4% |
| surveyor | 346 | 0.0% | 49.1% |
| medium | 342 | 0.0% | 17.8% |
| nightwatch | 336 | 0.0% | 50.9% |
| lamplighter | 330 | 0.0% | 0.9% |
| magistrate | 247 | 0.0% | 54.7% |
| chronicler | 242 | 0.0% | 47.5% |
| monitor | 233 | 0.0% | 24.0% |
| augur | 224 | 0.0% | 25.4% |
| psychologist | 218 | 0.0% | 24.3% |
| seer | 214 | 0.0% | 51.9% |
| executor | 211 | 0.0% | 33.2% |
| warden | 59 | 0.0% | 45.8% |
| veteran | 50 | 0.0% | 38.0% |
| sexton | 50 | 0.0% | 40.0% |
| martyr | 46 | 0.0% | 13.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + lamplighter | 364 | 59.9% | 1636 | 35.7% | +24.2 (+18.6 to +29.7) |
| poisoner + scion | 396 | 24.7% | 1604 | 43.9% | -19.1 (-24.0 to -14.2) |
| breathstealer + dowser | 304 | 54.9% | 1696 | 37.4% | +17.5 (+11.4 to +23.5) |
| breathstealer + demon | 893 | 49.6% | 1107 | 32.4% | +17.2 (+12.9 to +21.5) |
| breathstealer + nightwatch | 379 | 52.8% | 1621 | 37.1% | +15.6 (+10.1 to +21.2) |
| dowser + lamplighter | 262 | 53.1% | 1738 | 38.1% | +14.9 (+8.4 to +21.4) |
| breathstealer + clerk | 532 | 50.9% | 1468 | 36.2% | +14.8 (+9.9 to +19.7) |
| breathstealer + surveyor | 525 | 50.7% | 1475 | 36.3% | +14.3 (+9.4 to +19.3) |
| lamplighter + nightwatch | 229 | 52.4% | 1771 | 38.5% | +13.9 (+7.0 to +20.7) |
| breathstealer + revenant | 239 | 51.9% | 1761 | 38.5% | +13.4 (+6.7 to +20.1) |
| lamplighter + warden | 218 | 51.8% | 1782 | 38.7% | +13.2 (+6.2 to +20.2) |
| lamplighter + surveyor | 462 | 49.6% | 1538 | 37.3% | +12.3 (+7.2 to +17.5) |
| breathstealer + scion | 242 | 50.8% | 1758 | 38.6% | +12.2 (+5.5 to +18.9) |
| breathstealer + confessor | 353 | 50.1% | 1647 | 37.9% | +12.2 (+6.5 to +17.9) |
| demon + lamplighter | 777 | 47.5% | 1223 | 35.4% | +12.1 (+7.7 to +16.5) |
| archivist + breathstealer | 491 | 48.7% | 1509 | 37.3% | +11.4 (+6.3 to +16.4) |
| archivist + poisoner | 693 | 32.9% | 1307 | 43.9% | -11.0 (-15.4 to -6.6) |
| rumormonger + scion | 522 | 32.0% | 1478 | 43.0% | -11.0 (-15.7 to -6.2) |
| confessor + lamplighter | 219 | 49.8% | 1781 | 38.9% | +10.9 (+3.9 to +17.9) |
| gravedigger + poisoner | 482 | 32.0% | 1518 | 42.7% | -10.7 (-15.6 to -5.9) |
| archivist + lamplighter | 420 | 48.6% | 1580 | 37.8% | +10.7 (+5.4 to +16.1) |
| breathstealer + medium | 350 | 48.9% | 1650 | 38.2% | +10.6 (+4.9 to +16.4) |
| dowser + nightwatch | 267 | 49.1% | 1733 | 38.7% | +10.3 (+3.9 to +16.8) |
| poisoner + seer | 300 | 31.3% | 1700 | 41.6% | -10.3 (-16.1 to -4.6) |
| demon + poisoner | 1244 | 36.3% | 756 | 46.4% | -10.2 (-14.6 to -5.7) |
| clerk + lamplighter | 448 | 48.0% | 1552 | 37.8% | +10.2 (+5.0 to +15.4) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 0.6 | 2000 | 525 (26.2%) | 226 (11.3%) | 453 | 796 |
| 7 | 7 NPCs, bot insight 1.0 | 2000 | 595 (29.8%) | 174 (8.7%) | 505 | 726 |
| 10 | 10 NPCs, bot insight 0.6 | 1000 | 229 (22.9%) | 121 (12.1%) | 279 | 371 |
| 10 | 10 NPCs, bot insight 1.0 | 2000 | 465 (23.2%) | 215 (10.8%) | 587 | 733 |

## Health

- Stuck games (guard exhausted): 13 — seeds 100351 (7 NPCs, bot), 100947 (10 NPCs, bot), 101332 (10 NPCs, bot), 100185 (7 NPCs, bot), 100897 (7 NPCs, bot), 100548 (7 NPCs, bot), 100265 (10 NPCs, bot), 101890 (7 NPCs, bot), 100411 (10 NPCs, bot), 100459 (10 NPCs, bot), 100029 (10 NPCs, bot), 100422 (10 NPCs, bot), 100132 (10 NPCs, bot)
- Failed games (crash or timeout): 0
- Games with engine errors: 2
  - Most common lines:
    - 2× `ERROR: System.IndexOutOfRangeException: Index was outside the bounds of the array.`
    - 2× `SCRIPT ERROR: Invalid call. Nonexistent function 'CaseEvalEvaluatePosterior' in base 'CSharpScript'.`
    - 1× `SCRIPT ERROR: Invalid access to property or key 'people' on a base object of type 'Dictionary'.`
    - 1× `SCRIPT ERROR: Invalid access to property or key 'impossible' on a base object of type 'Dictionary'.`
- Shared-model fallbacks: 50 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 0.6 | 22.0 | 43.5 | 161.6 |
| 7 NPCs, bot insight 1.0 | 38.2 | 76.5 | 216.8 |
| 7 NPCs, passive | 3.8 | 6.5 | 24.0 |
| 10 NPCs, bot insight 0.6 | 119.9 | 242.6 | 672.9 |
| 10 NPCs, bot insight 1.0 | 172.2 | 361.5 | 1102.5 |
| 10 NPCs, passive | 38.1 | 70.4 | 248.5 |

Slowest seeds: 101847 (10 NPCs bot, 1102 s), 100217 (10 NPCs bot, 1045 s), 100147 (10 NPCs bot, 947 s), 100204 (10 NPCs bot, 872 s), 100871 (10 NPCs bot, 870 s), 101812 (10 NPCs bot, 837 s), 101918 (10 NPCs bot, 828 s), 101543 (10 NPCs bot, 821 s), 101996 (10 NPCs bot, 779 s), 101167 (10 NPCs bot, 759 s), 101581 (10 NPCs bot, 749 s), 101821 (10 NPCs bot, 741 s), 101864 (10 NPCs bot, 741 s), 101865 (10 NPCs bot, 730 s), 100255 (10 NPCs bot, 727 s), 101174 (10 NPCs bot, 724 s), 100168 (10 NPCs bot, 691 s), 100509 (10 NPCs bot, 676 s), 101141 (10 NPCs bot, 676 s), 100745 (10 NPCs bot, 673 s)

