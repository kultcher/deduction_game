# Balance sweep report

Records: 2000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `61ba493932`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 59.0% (55.9%–62.0%) | 3.15 | 0.69 | 1.07 | 2.37 | 8.4% | 0.25 |
| 10 NPCs, bot insight 1.0 | 1000 | 53.7% (50.6%–56.8%) | 4.38 | 1.11 | 1.59 | 2.58 | 8.1% | 0.48 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 590 (59.0%)
- Only two townsfolk remain and the demon still walks among them.: 410 (41.0%)
- Demon evidence on the board: 98.6% of games; good win rate 58.5% of 986
- Demon evidence reachable: 80.4% of games; good win rate 54.6% of 804
- Neither: 0.7% of games; good win rate 100.0% of 7
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 537 (53.7%)
- Only two townsfolk remain and the demon still walks among them.: 295 (29.5%)
- No good soul remains.: 165 (16.5%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 99.0% of games; good win rate 53.2% of 990
- Demon evidence reachable: 89.7% of games; good win rate 50.6% of 897
- Neither: 0.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| veteran | 73 | 72.6% | 927 | 57.9% | +14.7 (+4.0 to +25.4) **\*** |
| martyr | 88 | 50.0% | 912 | 59.9% | -9.9 (-20.8 to +1.1) |
| gravedigger | 283 | 52.7% | 717 | 61.5% | -8.9 (-15.7 to -2.0) **\*** |
| chronicler | 76 | 51.3% | 924 | 59.6% | -8.3 (-20.0 to +3.4) |
| dowser | 286 | 63.3% | 714 | 57.3% | +6.0 (-0.7 to +12.7) |
| clerk | 545 | 61.1% | 455 | 56.5% | +4.6 (-1.5 to +10.7) |
| monitor | 73 | 63.0% | 927 | 58.7% | +4.3 (-7.2 to +15.8) |
| psychologist | 67 | 55.2% | 933 | 59.3% | -4.0 (-16.4 to +8.3) |
| medium | 188 | 62.2% | 812 | 58.3% | +4.0 (-3.7 to +11.7) |
| archivist | 548 | 57.7% | 452 | 60.6% | -3.0 (-9.1 to +3.2) |
| lamplighter | 203 | 56.7% | 797 | 59.6% | -2.9 (-10.6 to +4.7) |
| registrar | 270 | 61.1% | 730 | 58.2% | +2.9 (-3.9 to +9.7) |
| nightwatch | 238 | 60.9% | 762 | 58.4% | +2.5 (-4.6 to +9.6) |
| sexton | 74 | 56.8% | 926 | 59.2% | -2.4 (-14.1 to +9.3) |
| warden | 229 | 57.2% | 771 | 59.5% | -2.3 (-9.6 to +5.0) |
| rumormonger | 504 | 59.9% | 496 | 58.1% | +1.9 (-4.2 to +8.0) |
| confessor | 224 | 57.6% | 776 | 59.4% | -1.8 (-9.2 to +5.5) |
| magistrate | 73 | 60.3% | 927 | 58.9% | +1.4 (-10.3 to +13.0) |
| surveyor | 508 | 58.5% | 492 | 59.6% | -1.1 (-7.2 to +5.0) |
| executor | 87 | 59.8% | 913 | 58.9% | +0.8 (-9.9 to +11.6) |
| augur | 193 | 58.5% | 807 | 59.1% | -0.6 (-8.3 to +7.2) |
| seer | 170 | 58.8% | 830 | 59.0% | -0.2 (-8.3 to +7.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 68.9% | 781 | 56.2% | +12.7 (+5.7 to +19.8) **\*** |
| poisoner | 325 | 52.3% | 675 | 62.2% | -9.9 (-16.5 to -3.4) **\*** |
| revenant | 221 | 57.0% | 779 | 59.6% | -2.5 (-9.9 to +4.8) |
| scion | 235 | 60.9% | 765 | 58.4% | +2.4 (-4.7 to +9.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 43.9% | 788 | 63.1% | -19.2 (-26.7 to -11.7) **\*** |
| marked | 195 | 64.6% | 805 | 57.6% | +7.0 (-0.6 to +14.5) |
| lovers | 208 | 63.9% | 792 | 57.7% | +6.2 (-1.1 to +13.6) |
| sleepwalker | 186 | 62.4% | 814 | 58.2% | +4.1 (-3.6 to +11.9) |
| muddler | 199 | 61.3% | 801 | 58.4% | +2.9 (-4.7 to +10.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 46.5% | 957 | 59.6% | -13.0 (-28.3 to +2.2) |
| 2 night-walkers | 636 | 61.8% | 364 | 54.1% | +7.7 (+1.3 to +14.0) **\*** |
| 3 night-walkers | 321 | 55.1% | 679 | 60.8% | -5.7 (-12.2 to +0.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.6 | 52.7% | 16.6% | 94.5% |
| clerk | 545 | 2.2 | 20.9% | 14.7% | 88.8% |
| surveyor | 508 | 2.3 | 23.0% | 11.4% | 92.5% |
| rumormonger | 504 | 2.2 | 26.4% | 15.9% | 91.9% |
| dowser | 286 | 1.8 | 46.2% | 9.1% | 84.6% |
| gravedigger | 283 | 2.1 | 39.2% | 13.8% | 85.2% |
| registrar | 270 | 2.1 | 35.9% | 5.6% | 79.6% |
| nightwatch | 238 | 2.0 | 40.3% | 14.3% | 84.9% |
| warden | 229 | 2.2 | 23.1% | 20.1% | 78.6% |
| confessor | 224 | 2.1 | 27.7% | 20.1% | 82.1% |
| lamplighter | 203 | 2.1 | 31.0% | 11.3% | 85.2% |
| augur | 193 | 2.2 | 31.1% | 15.0% | 78.8% |
| medium | 188 | 2.2 | 26.6% | 10.6% | 74.5% |
| seer | 170 | 1.9 | 45.9% | 12.4% | 84.1% |
| martyr | 88 | 2.5 | 17.0% | 10.2% | 86.4% |
| executor | 87 | 2.2 | 21.8% | 10.3% | 73.6% |
| chronicler | 76 | 2.5 | 23.7% | 14.5% | 80.3% |
| sexton | 74 | 2.5 | 13.5% | 21.6% | 64.9% |
| veteran | 73 | 2.7 | 9.6% | 12.3% | 82.2% |
| magistrate | 73 | 2.4 | 32.9% | 11.0% | 82.2% |
| monitor | 73 | 2.2 | 27.4% | 2.7% | 83.6% |
| psychologist | 67 | 2.4 | 22.4% | 13.4% | 82.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 145 | 0.0% | 65.5% |
| registrar | 145 | 0.0% | 46.9% |
| dowser | 138 | 0.0% | 62.3% |
| confessor | 134 | 0.0% | 66.4% |
| medium | 130 | 0.0% | 38.5% |
| lamplighter | 128 | 0.0% | 71.1% |
| gravedigger | 116 | 0.0% | 56.9% |
| surveyor | 113 | 0.0% | 49.6% |
| rumormonger | 108 | 0.0% | 51.9% |
| clerk | 104 | 0.0% | 51.9% |
| archivist | 100 | 0.0% | 59.0% |
| chronicler | 79 | 0.0% | 58.2% |
| magistrate | 79 | 0.0% | 60.8% |
| psychologist | 78 | 0.0% | 59.0% |
| seer | 76 | 0.0% | 34.2% |
| executor | 76 | 0.0% | 48.7% |
| augur | 69 | 0.0% | 59.4% |
| monitor | 64 | 0.0% | 31.2% |
| warden | 18 | 0.0% | 50.0% |
| martyr | 17 | 0.0% | 17.6% |
| veteran | 15 | 0.0% | 46.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 68.9% | 781 | 56.2% | +12.7 (+5.7 to +19.8) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 61.9% | 604 | 48.3% | +13.5 (+7.3 to +19.8) **\*** |
| chronicler | 137 | 46.7% | 863 | 54.8% | -8.1 (-17.1 to +0.9) |
| warden | 377 | 50.1% | 623 | 55.9% | -5.7 (-12.1 to +0.7) |
| dowser | 372 | 57.3% | 628 | 51.6% | +5.7 (-0.7 to +12.0) |
| archivist | 563 | 56.0% | 437 | 50.8% | +5.1 (-1.1 to +11.4) |
| confessor | 389 | 50.6% | 611 | 55.6% | -5.0 (-11.3 to +1.3) |
| medium | 384 | 56.5% | 616 | 51.9% | +4.6 (-1.8 to +10.9) |
| psychologist | 148 | 50.7% | 852 | 54.2% | -3.5 (-12.3 to +5.2) |
| sexton | 148 | 50.7% | 852 | 54.2% | -3.5 (-12.3 to +5.2) |
| seer | 225 | 51.1% | 775 | 54.5% | -3.3 (-10.8 to +4.1) |
| rumormonger | 590 | 52.4% | 410 | 55.6% | -3.2 (-9.5 to +3.0) |
| registrar | 377 | 51.7% | 623 | 54.9% | -3.2 (-9.6 to +3.2) |
| monitor | 144 | 56.2% | 856 | 53.3% | +3.0 (-5.8 to +11.7) |
| gravedigger | 358 | 52.2% | 642 | 54.5% | -2.3 (-8.7 to +4.2) |
| magistrate | 135 | 51.9% | 865 | 54.0% | -2.1 (-11.2 to +6.9) |
| veteran | 172 | 52.3% | 828 | 54.0% | -1.7 (-9.9 to +6.5) |
| executor | 147 | 55.1% | 853 | 53.5% | +1.6 (-7.1 to +10.4) |
| augur | 231 | 53.2% | 769 | 53.8% | -0.6 (-7.9 to +6.7) |
| clerk | 581 | 53.9% | 419 | 53.5% | +0.4 (-5.9 to +6.7) |
| lamplighter | 382 | 53.9% | 618 | 53.6% | +0.4 (-6.0 to +6.7) |
| surveyor | 588 | 53.6% | 412 | 53.9% | -0.3 (-6.6 to +6.0) |
| martyr | 156 | 53.8% | 844 | 53.7% | +0.2 (-8.3 to +8.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 64.6% | 559 | 45.1% | +19.5 (+13.5 to +25.6) **\*** |
| scion | 467 | 46.5% | 533 | 60.0% | -13.6 (-19.7 to -7.4) **\*** |
| poisoner | 620 | 49.8% | 380 | 60.0% | -10.2 (-16.5 to -3.9) **\*** |
| revenant | 472 | 55.7% | 528 | 51.9% | +3.8 (-2.4 to +10.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 41.7% | 784 | 57.0% | -15.3 (-22.8 to -7.9) **\*** |
| muddler | 191 | 61.3% | 809 | 51.9% | +9.3 (+1.6 to +17.1) **\*** |
| lovers | 195 | 59.0% | 805 | 52.4% | +6.6 (-1.2 to +14.3) |
| marked | 191 | 57.6% | 809 | 52.8% | +4.8 (-3.0 to +12.6) |
| sleepwalker | 207 | 50.7% | 793 | 54.5% | -3.8 (-11.4 to +3.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 48.4% | 909 | 54.2% | -5.9 (-16.7 to +4.9) |
| 4 night-walkers | 366 | 54.9% | 634 | 53.0% | +1.9 (-4.5 to +8.3) |
| 3 night-walkers | 543 | 53.8% | 457 | 53.6% | +0.2 (-6.0 to +6.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 13.6% | 16.4% | 93.9% |
| surveyor | 588 | 3.3 | 14.8% | 17.9% | 95.4% |
| clerk | 581 | 3.3 | 12.7% | 17.0% | 94.8% |
| archivist | 563 | 2.0 | 52.2% | 10.7% | 93.1% |
| nightwatch | 396 | 2.4 | 31.3% | 20.2% | 88.6% |
| confessor | 389 | 2.6 | 20.8% | 27.0% | 90.0% |
| medium | 384 | 3.0 | 19.5% | 7.3% | 86.2% |
| lamplighter | 382 | 3.0 | 21.5% | 14.1% | 90.6% |
| registrar | 377 | 2.7 | 27.1% | 10.1% | 86.2% |
| warden | 377 | 3.2 | 15.9% | 25.2% | 86.5% |
| dowser | 372 | 2.1 | 51.6% | 10.2% | 93.5% |
| gravedigger | 358 | 2.7 | 31.0% | 14.2% | 92.5% |
| augur | 231 | 2.9 | 24.2% | 15.2% | 83.5% |
| seer | 225 | 2.4 | 40.4% | 12.0% | 88.0% |
| veteran | 172 | 3.7 | 8.7% | 24.4% | 86.6% |
| martyr | 156 | 3.8 | 5.8% | 13.5% | 94.2% |
| sexton | 148 | 3.4 | 10.1% | 26.4% | 81.1% |
| psychologist | 148 | 3.0 | 18.2% | 13.5% | 89.2% |
| executor | 147 | 3.1 | 14.3% | 10.9% | 89.8% |
| monitor | 144 | 2.9 | 26.4% | 5.6% | 80.6% |
| chronicler | 137 | 3.1 | 14.6% | 17.5% | 86.9% |
| magistrate | 135 | 2.9 | 21.5% | 13.3% | 87.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 213 | 0.0% | 44.6% |
| dowser | 201 | 0.0% | 67.2% |
| archivist | 198 | 0.0% | 51.5% |
| gravedigger | 193 | 0.0% | 56.0% |
| clerk | 190 | 0.0% | 54.2% |
| confessor | 184 | 0.0% | 67.9% |
| rumormonger | 182 | 0.0% | 51.6% |
| surveyor | 176 | 0.0% | 50.0% |
| medium | 170 | 0.0% | 26.5% |
| lamplighter | 167 | 0.0% | 72.5% |
| nightwatch | 166 | 0.0% | 65.7% |
| magistrate | 125 | 0.0% | 56.8% |
| augur | 118 | 0.0% | 62.7% |
| chronicler | 108 | 0.0% | 52.8% |
| seer | 106 | 0.0% | 54.7% |
| monitor | 105 | 0.0% | 36.2% |
| psychologist | 104 | 0.0% | 56.7% |
| executor | 95 | 0.0% | 34.7% |
| sexton | 33 | 0.0% | 51.5% |
| veteran | 31 | 0.0% | 35.5% |
| martyr | 21 | 0.0% | 42.9% |
| warden | 18 | 0.0% | 44.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner + scion | 215 | 34.9% | 785 | 58.9% | -24.0 (-31.2 to -16.7) |
| breathstealer + demon | 441 | 64.6% | 559 | 45.1% | +19.5 (+13.5 to +25.6) |
| archivist + breathstealer | 243 | 67.5% | 757 | 49.3% | +18.2 (+11.3 to +25.1) |
| rumormonger + scion | 276 | 42.8% | 724 | 57.9% | -15.1 (-22.0 to -8.3) |
| breathstealer + surveyor | 261 | 64.8% | 739 | 49.8% | +15.0 (+8.1 to +21.8) |
| breathstealer + clerk | 253 | 64.0% | 747 | 50.2% | +13.8 (+6.9 to +20.7) |
| demon + scion | 467 | 46.5% | 533 | 60.0% | -13.6 (-19.7 to -7.4) |
| demon + nightwatch | 396 | 61.9% | 604 | 48.3% | +13.5 (+7.3 to +19.8) |
| breathstealer + rumormonger | 264 | 63.3% | 736 | 50.3% | +13.0 (+6.1 to +19.8) |
| archivist + nightwatch | 225 | 63.6% | 775 | 50.8% | +12.7 (+5.5 to +19.9) |
| clerk + nightwatch | 225 | 63.1% | 775 | 51.0% | +12.1 (+4.9 to +19.4) |
| scion + surveyor | 267 | 46.1% | 733 | 56.5% | -10.4 (-17.4 to -3.4) |
| archivist + dowser | 210 | 61.9% | 790 | 51.5% | +10.4 (+3.0 to +17.8) |
| demon + poisoner | 620 | 49.8% | 380 | 60.0% | -10.2 (-16.5 to -3.9) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 3 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 62.7 | 124.2 | 317.4 |
| 10 NPCs, bot insight 1.0 | 289.0 | 585.5 | 1672.8 |

Slowest seeds: 100419 (10 NPCs bot, 1673 s), 100485 (10 NPCs bot, 1521 s), 100474 (10 NPCs bot, 1435 s), 100761 (10 NPCs bot, 1426 s), 100828 (10 NPCs bot, 1408 s), 100839 (10 NPCs bot, 1305 s), 100829 (10 NPCs bot, 1160 s), 100307 (10 NPCs bot, 1071 s), 100441 (10 NPCs bot, 1065 s), 100357 (10 NPCs bot, 1040 s), 100429 (10 NPCs bot, 1032 s), 100755 (10 NPCs bot, 1024 s), 100597 (10 NPCs bot, 1008 s), 100487 (10 NPCs bot, 998 s), 100491 (10 NPCs bot, 992 s), 100721 (10 NPCs bot, 965 s), 100713 (10 NPCs bot, 963 s), 100421 (10 NPCs bot, 929 s), 100763 (10 NPCs bot, 923 s), 100319 (10 NPCs bot, 917 s)

