# Balance sweep report

Records: 2000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `3d0f21054f`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 58.6% (55.5%–61.6%) | 3.15 | 0.68 | 1.07 | 2.35 | 8.5% | 0.24 |
| 10 NPCs, bot insight 1.0 | 1000 | 52.5% (49.4%–55.6%) | 4.34 | 1.13 | 1.56 | 2.61 | 7.2% | 0.49 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 586 (58.6%)
- Only two townsfolk remain and the demon still walks among them.: 414 (41.4%)
- Demon evidence on the board: 98.9% of games; good win rate 58.1% of 989
- Demon evidence reachable: 79.3% of games; good win rate 53.5% of 793
- Neither: 0.8% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 525 (52.5%)
- Only two townsfolk remain and the demon still walks among them.: 311 (31.1%)
- No good soul remains.: 161 (16.1%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 99.5% of games; good win rate 52.3% of 995
- Demon evidence reachable: 89.8% of games; good win rate 50.7% of 898
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 283 | 49.8% | 717 | 62.1% | -12.2 (-19.1 to -5.4) **\*** |
| registrar | 270 | 65.6% | 730 | 56.0% | +9.5 (+2.8 to +16.2) **\*** |
| magistrate | 73 | 67.1% | 927 | 57.9% | +9.2 (-2.0 to +20.4) |
| psychologist | 67 | 50.7% | 933 | 59.2% | -8.4 (-20.8 to +4.0) |
| veteran | 73 | 63.0% | 927 | 58.3% | +4.8 (-6.8 to +16.3) |
| augur | 193 | 54.9% | 807 | 59.5% | -4.6 (-12.4 to +3.2) |
| archivist | 548 | 56.6% | 452 | 61.1% | -4.5 (-10.6 to +1.6) |
| clerk | 545 | 60.6% | 455 | 56.3% | +4.3 (-1.8 to +10.4) |
| confessor | 224 | 55.4% | 776 | 59.5% | -4.2 (-11.5 to +3.2) |
| seer | 170 | 61.8% | 830 | 58.0% | +3.8 (-4.2 to +11.9) |
| executor | 87 | 55.2% | 913 | 58.9% | -3.8 (-14.7 to +7.2) |
| nightwatch | 238 | 61.3% | 762 | 57.7% | +3.6 (-3.5 to +10.7) |
| martyr | 88 | 61.4% | 912 | 58.3% | +3.0 (-7.6 to +13.7) |
| monitor | 73 | 56.2% | 927 | 58.8% | -2.6 (-14.4 to +9.2) |
| medium | 188 | 60.6% | 812 | 58.1% | +2.5 (-5.3 to +10.3) |
| warden | 229 | 56.8% | 771 | 59.1% | -2.4 (-9.7 to +4.9) |
| surveyor | 508 | 59.6% | 492 | 57.5% | +2.1 (-4.0 to +8.2) |
| dowser | 286 | 59.4% | 714 | 58.3% | +1.2 (-5.6 to +7.9) |
| sexton | 74 | 59.5% | 926 | 58.5% | +0.9 (-10.7 to +12.6) |
| chronicler | 76 | 59.2% | 924 | 58.5% | +0.7 (-10.8 to +12.2) |
| lamplighter | 203 | 58.1% | 797 | 58.7% | -0.6 (-8.2 to +7.0) |
| rumormonger | 504 | 58.5% | 496 | 58.7% | -0.1 (-6.2 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 68.9% | 781 | 55.7% | +13.3 (+6.2 to +20.3) **\*** |
| poisoner | 325 | 53.2% | 675 | 61.2% | -8.0 (-14.5 to -1.4) **\*** |
| revenant | 221 | 54.8% | 779 | 59.7% | -4.9 (-12.4 to +2.5) |
| scion | 235 | 60.0% | 765 | 58.2% | +1.8 (-5.3 to +9.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 49.5% | 788 | 61.0% | -11.5 (-19.1 to -4.0) **\*** |
| lovers | 208 | 63.9% | 792 | 57.2% | +6.7 (-0.6 to +14.1) |
| muddler | 199 | 61.3% | 801 | 57.9% | +3.4 (-4.2 to +11.0) |
| sleepwalker | 186 | 60.8% | 814 | 58.1% | +2.6 (-5.1 to +10.4) |
| marked | 195 | 57.9% | 805 | 58.8% | -0.8 (-8.5 to +6.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 39.5% | 957 | 59.5% | -19.9 (-34.9 to -5.0) **\*** |
| 2 night-walkers | 636 | 60.4% | 364 | 55.5% | +4.9 (-1.5 to +11.2) |
| 3 night-walkers | 321 | 57.6% | 679 | 59.1% | -1.4 (-8.0 to +5.1) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 50.7% | 15.7% | 95.4% |
| clerk | 545 | 2.3 | 21.5% | 13.6% | 90.5% |
| surveyor | 508 | 2.3 | 22.0% | 13.2% | 92.9% |
| rumormonger | 504 | 2.3 | 20.4% | 15.1% | 93.1% |
| dowser | 286 | 1.8 | 51.7% | 10.1% | 86.4% |
| gravedigger | 283 | 2.1 | 42.0% | 13.8% | 86.2% |
| registrar | 270 | 1.9 | 35.2% | 7.0% | 80.4% |
| nightwatch | 238 | 2.0 | 35.7% | 16.8% | 81.9% |
| warden | 229 | 2.4 | 24.0% | 19.2% | 75.1% |
| confessor | 224 | 2.0 | 33.5% | 15.6% | 84.4% |
| lamplighter | 203 | 2.3 | 28.1% | 10.8% | 79.8% |
| augur | 193 | 2.3 | 30.1% | 17.1% | 73.6% |
| medium | 188 | 2.1 | 30.9% | 10.1% | 77.1% |
| seer | 170 | 1.9 | 44.7% | 11.2% | 79.4% |
| martyr | 88 | 2.3 | 17.0% | 11.4% | 85.2% |
| executor | 87 | 2.3 | 28.7% | 9.2% | 79.3% |
| chronicler | 76 | 2.3 | 21.1% | 15.8% | 86.8% |
| sexton | 74 | 2.5 | 16.2% | 17.6% | 70.3% |
| veteran | 73 | 3.0 | 11.0% | 16.4% | 82.2% |
| magistrate | 73 | 2.1 | 32.9% | 6.8% | 78.1% |
| monitor | 73 | 2.4 | 26.0% | 8.2% | 78.1% |
| psychologist | 67 | 1.9 | 35.8% | 10.4% | 85.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 146 | 0.0% | 52.1% |
| nightwatch | 139 | 0.0% | 61.2% |
| dowser | 138 | 0.0% | 60.1% |
| confessor | 135 | 0.0% | 65.2% |
| medium | 126 | 0.0% | 29.4% |
| lamplighter | 125 | 0.0% | 74.4% |
| gravedigger | 114 | 0.0% | 59.6% |
| surveyor | 113 | 0.0% | 47.8% |
| rumormonger | 109 | 0.0% | 48.6% |
| clerk | 105 | 0.0% | 57.1% |
| archivist | 100 | 0.0% | 64.0% |
| psychologist | 79 | 0.0% | 57.0% |
| chronicler | 77 | 0.0% | 61.0% |
| executor | 76 | 0.0% | 43.4% |
| magistrate | 75 | 0.0% | 46.7% |
| seer | 75 | 0.0% | 50.7% |
| augur | 73 | 0.0% | 58.9% |
| monitor | 63 | 0.0% | 41.3% |
| martyr | 18 | 0.0% | 33.3% |
| warden | 17 | 0.0% | 52.9% |
| veteran | 16 | 0.0% | 31.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 68.9% | 781 | 55.7% | +13.3 (+6.2 to +20.3) |
| demon + gravedigger | 283 | 49.8% | 717 | 62.1% | -12.2 (-19.1 to -5.4) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 58.6% | 604 | 48.5% | +10.1 (+3.8 to +16.4) **\*** |
| chronicler | 137 | 44.5% | 863 | 53.8% | -9.2 (-18.2 to -0.3) **\*** |
| martyr | 156 | 45.5% | 844 | 53.8% | -8.3 (-16.8 to +0.2) |
| gravedigger | 358 | 47.2% | 642 | 55.5% | -8.2 (-14.7 to -1.8) **\*** |
| clerk | 581 | 55.4% | 419 | 48.4% | +7.0 (+0.7 to +13.2) **\*** |
| monitor | 144 | 47.9% | 856 | 53.3% | -5.4 (-14.2 to +3.5) |
| rumormonger | 590 | 50.7% | 410 | 55.1% | -4.4 (-10.7 to +1.8) |
| seer | 225 | 55.6% | 775 | 51.6% | +3.9 (-3.4 to +11.3) |
| psychologist | 148 | 49.3% | 852 | 53.1% | -3.7 (-12.5 to +5.0) |
| confessor | 389 | 50.6% | 611 | 53.7% | -3.0 (-9.4 to +3.3) |
| registrar | 377 | 54.4% | 623 | 51.4% | +3.0 (-3.4 to +9.4) |
| lamplighter | 382 | 54.2% | 618 | 51.5% | +2.7 (-3.6 to +9.1) |
| sexton | 148 | 54.7% | 852 | 52.1% | +2.6 (-6.1 to +11.3) |
| surveyor | 588 | 53.6% | 412 | 51.0% | +2.6 (-3.7 to +8.9) |
| executor | 147 | 50.3% | 853 | 52.9% | -2.5 (-11.3 to +6.2) |
| medium | 384 | 53.6% | 616 | 51.8% | +1.9 (-4.5 to +8.2) |
| augur | 231 | 51.1% | 769 | 52.9% | -1.8 (-9.2 to +5.5) |
| magistrate | 135 | 51.1% | 865 | 52.7% | -1.6 (-10.7 to +7.5) |
| dowser | 372 | 53.5% | 628 | 51.9% | +1.6 (-4.8 to +8.0) |
| veteran | 172 | 51.7% | 828 | 52.7% | -0.9 (-9.1 to +7.3) |
| warden | 377 | 52.8% | 623 | 52.3% | +0.5 (-5.9 to +6.8) |
| archivist | 563 | 52.4% | 437 | 52.6% | -0.2 (-6.5 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 66.4% | 559 | 41.5% | +24.9 (+18.9 to +30.9) **\*** |
| scion | 467 | 44.8% | 533 | 59.3% | -14.5 (-20.7 to -8.4) **\*** |
| poisoner | 620 | 49.4% | 380 | 57.6% | -8.3 (-14.6 to -1.9) **\*** |
| revenant | 472 | 51.3% | 528 | 53.6% | -2.3 (-8.5 to +3.9) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 49.1% | 784 | 53.4% | -4.4 (-11.9 to +3.2) |
| muddler | 191 | 55.0% | 809 | 51.9% | +3.1 (-4.8 to +10.9) |
| lovers | 195 | 50.8% | 805 | 52.9% | -2.2 (-10.0 to +5.7) |
| sleepwalker | 207 | 54.1% | 793 | 52.1% | +2.0 (-5.6 to +9.7) |
| marked | 191 | 53.9% | 809 | 52.2% | +1.8 (-6.1 to +9.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 543 | 51.2% | 457 | 54.0% | -2.9 (-9.1 to +3.4) |
| 5 night-walkers | 91 | 54.9% | 909 | 52.3% | +2.7 (-8.0 to +13.4) |
| 4 night-walkers | 366 | 53.8% | 634 | 51.7% | +2.1 (-4.3 to +8.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 14.2% | 19.7% | 94.9% |
| surveyor | 588 | 3.3 | 12.6% | 19.2% | 95.6% |
| clerk | 581 | 3.2 | 14.6% | 15.7% | 94.7% |
| archivist | 563 | 2.0 | 55.8% | 11.0% | 94.3% |
| nightwatch | 396 | 2.4 | 30.6% | 19.2% | 87.6% |
| confessor | 389 | 2.6 | 21.1% | 28.0% | 90.0% |
| medium | 384 | 2.8 | 24.2% | 9.4% | 85.2% |
| lamplighter | 382 | 2.9 | 20.7% | 13.4% | 91.1% |
| warden | 377 | 3.3 | 11.1% | 26.5% | 85.7% |
| registrar | 377 | 2.7 | 26.5% | 7.2% | 83.8% |
| dowser | 372 | 2.0 | 49.2% | 12.4% | 86.8% |
| gravedigger | 358 | 2.6 | 32.1% | 12.0% | 91.6% |
| augur | 231 | 3.1 | 19.0% | 18.2% | 82.3% |
| seer | 225 | 2.5 | 32.4% | 10.2% | 87.6% |
| veteran | 172 | 4.0 | 5.8% | 26.7% | 87.8% |
| martyr | 156 | 3.5 | 13.5% | 17.3% | 87.8% |
| sexton | 148 | 3.3 | 10.1% | 28.4% | 73.6% |
| psychologist | 148 | 3.0 | 18.2% | 16.9% | 87.2% |
| executor | 147 | 3.1 | 20.4% | 10.9% | 87.1% |
| monitor | 144 | 3.2 | 20.1% | 6.2% | 81.9% |
| chronicler | 137 | 3.1 | 18.2% | 14.6% | 86.1% |
| magistrate | 135 | 2.5 | 37.8% | 7.4% | 86.7% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 208 | 0.0% | 42.3% |
| dowser | 206 | 0.0% | 66.5% |
| archivist | 198 | 0.0% | 52.5% |
| gravedigger | 194 | 0.0% | 53.6% |
| clerk | 190 | 0.0% | 57.9% |
| rumormonger | 183 | 0.0% | 51.4% |
| confessor | 183 | 0.0% | 68.9% |
| surveyor | 176 | 0.0% | 45.5% |
| medium | 168 | 0.0% | 23.8% |
| nightwatch | 166 | 0.0% | 62.0% |
| lamplighter | 165 | 0.0% | 69.1% |
| magistrate | 130 | 0.0% | 57.7% |
| augur | 119 | 0.0% | 63.0% |
| monitor | 109 | 0.0% | 29.4% |
| chronicler | 109 | 0.0% | 55.0% |
| psychologist | 108 | 0.0% | 40.7% |
| seer | 104 | 0.0% | 38.5% |
| executor | 98 | 0.0% | 42.9% |
| sexton | 34 | 0.0% | 47.1% |
| veteran | 31 | 0.0% | 25.8% |
| warden | 20 | 0.0% | 30.0% |
| martyr | 20 | 0.0% | 50.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 66.4% | 559 | 41.5% | +24.9 (+18.9 to +30.9) |
| archivist + breathstealer | 243 | 69.1% | 757 | 47.2% | +22.0 (+15.2 to +28.8) |
| poisoner + scion | 215 | 36.7% | 785 | 56.8% | -20.1 (-27.4 to -12.8) |
| breathstealer + surveyor | 261 | 67.0% | 739 | 47.4% | +19.7 (+12.9 to +26.4) |
| breathstealer + rumormonger | 264 | 66.7% | 736 | 47.4% | +19.2 (+12.5 to +26.0) |
| breathstealer + clerk | 253 | 66.4% | 747 | 47.8% | +18.6 (+11.8 to +25.4) |
| rumormonger + scion | 276 | 39.5% | 724 | 57.5% | -18.0 (-24.8 to -11.2) |
| demon + scion | 467 | 44.8% | 533 | 59.3% | -14.5 (-20.7 to -8.4) |
| clerk + nightwatch | 225 | 63.6% | 775 | 49.3% | +14.3 (+7.1 to +21.5) |
| gravedigger + rumormonger | 200 | 44.0% | 800 | 54.6% | -10.6 (-18.3 to -2.9) |
| gravedigger + poisoner | 221 | 44.3% | 779 | 54.8% | -10.5 (-17.9 to -3.0) |
| demon + nightwatch | 396 | 58.6% | 604 | 48.5% | +10.1 (+3.8 to +16.4) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 5 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 64.1 | 141.0 | 430.0 |
| 10 NPCs, bot insight 1.0 | 316.9 | 652.8 | 1614.7 |

Slowest seeds: 100289 (10 NPCs bot, 1615 s), 100991 (10 NPCs bot, 1491 s), 100664 (10 NPCs bot, 1261 s), 100370 (10 NPCs bot, 1254 s), 100927 (10 NPCs bot, 1197 s), 100421 (10 NPCs bot, 1189 s), 100484 (10 NPCs bot, 1173 s), 100095 (10 NPCs bot, 1124 s), 100053 (10 NPCs bot, 1111 s), 100867 (10 NPCs bot, 1101 s), 100650 (10 NPCs bot, 1097 s), 100305 (10 NPCs bot, 1053 s), 100993 (10 NPCs bot, 1035 s), 100441 (10 NPCs bot, 1031 s), 100088 (10 NPCs bot, 993 s), 100835 (10 NPCs bot, 980 s), 100953 (10 NPCs bot, 977 s), 100896 (10 NPCs bot, 962 s), 100925 (10 NPCs bot, 957 s), 100482 (10 NPCs bot, 951 s)

