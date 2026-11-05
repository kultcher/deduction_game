# Balance sweep report

Records: 1000 games, 0 failed. Commit(s): `a0d9641e3b`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 0.6 | 1000 | 50.8% (47.7%–53.9%) | 4.32 | 1.18 | 1.50 | 2.61 | 3.1% | 0.41 |

### End reasons and solvability

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

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

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

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 2 — seeds 100422 (10 NPCs, bot), 100132 (10 NPCs, bot)
- Failed games (crash or timeout): 0
- Games with engine errors: 1
  - Most common lines:
    - 1× `ERROR: System.IndexOutOfRangeException: Index was outside the bounds of the array.`
    - 1× `SCRIPT ERROR: Invalid call. Nonexistent function 'CaseEvalEvaluatePosterior' in base 'CSharpScript'.`
    - 1× `SCRIPT ERROR: Invalid access to property or key 'impossible' on a base object of type 'Dictionary'.`
- Shared-model fallbacks: 5 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 10 NPCs, bot insight 0.6 | 119.9 | 242.6 | 672.9 |

Slowest seeds: 100745 (10 NPCs bot, 673 s), 100918 (10 NPCs bot, 659 s), 100684 (10 NPCs bot, 628 s), 100676 (10 NPCs bot, 569 s), 100972 (10 NPCs bot, 533 s), 100679 (10 NPCs bot, 468 s), 100457 (10 NPCs bot, 468 s), 100487 (10 NPCs bot, 451 s), 100397 (10 NPCs bot, 438 s), 100766 (10 NPCs bot, 422 s), 100932 (10 NPCs bot, 414 s), 100636 (10 NPCs bot, 412 s), 100767 (10 NPCs bot, 404 s), 100311 (10 NPCs bot, 388 s), 100362 (10 NPCs bot, 367 s), 100034 (10 NPCs bot, 367 s), 100911 (10 NPCs bot, 366 s), 100266 (10 NPCs bot, 365 s), 100986 (10 NPCs bot, 363 s), 100966 (10 NPCs bot, 363 s)

