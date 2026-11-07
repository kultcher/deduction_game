# Balance sweep report

Records: 2849 games, 33 failed, 0 stuck (left out of the rates). Commit(s): `226d566700`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 58.6% (55.5%–61.6%) | 3.15 | 0.68 | 1.07 | 2.36 | 8.5% | 0.25 |
| 10 NPCs, bot insight 1.0 | 963 | 53.3% (50.1%–56.4%) | 4.28 | 1.12 | 1.56 | 2.58 | 7.4% | 0.48 |
| 10 NPCs, passive | 886 | 30.4% (27.4%–33.5%) | 4.70 | 1.51 | 1.11 | 2.71 | 2.8% | 0.61 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 586 (58.6%)
- Only two townsfolk remain and the demon still walks among them.: 414 (41.4%)
- Demon evidence on the board: 98.9% of games; good win rate 58.1% of 989
- Demon evidence reachable: 79.4% of games; good win rate 53.8% of 794
- Neither: 0.8% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=963)

- The demon's host was executed.: 513 (53.3%)
- Only two townsfolk remain and the demon still walks among them.: 298 (30.9%)
- No good soul remains.: 151 (15.7%)
- Time ran out: the demon survived 8 days.: 1 (0.1%)
- Demon evidence on the board: 99.5% of games; good win rate 53.0% of 958
- Demon evidence reachable: 89.3% of games; good win rate 51.6% of 860
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=886)

- No good soul remains.: 351 (39.6%)
- The demon's host was executed.: 269 (30.4%)
- Only two townsfolk remain and the demon still walks among them.: 263 (29.7%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 79.8% of games; good win rate 32.7% of 707
- Demon evidence reachable: 100.0% of games; good win rate 30.4% of 886
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 283 | 49.8% | 717 | 62.1% | -12.2 (-19.1 to -5.4) **\*** |
| magistrate | 73 | 68.5% | 927 | 57.8% | +10.7 (-0.4 to +21.8) |
| registrar | 270 | 65.2% | 730 | 56.2% | +9.0 (+2.3 to +15.7) **\*** |
| psychologist | 67 | 50.7% | 933 | 59.2% | -8.4 (-20.8 to +4.0) |
| archivist | 548 | 56.4% | 452 | 61.3% | -4.9 (-11.0 to +1.2) |
| veteran | 73 | 63.0% | 927 | 58.3% | +4.8 (-6.8 to +16.3) |
| confessor | 224 | 54.9% | 776 | 59.7% | -4.8 (-12.1 to +2.6) |
| clerk | 545 | 60.6% | 455 | 56.3% | +4.3 (-1.8 to +10.4) |
| augur | 193 | 55.4% | 807 | 59.4% | -3.9 (-11.7 to +3.9) |
| seer | 170 | 61.8% | 830 | 58.0% | +3.8 (-4.2 to +11.9) |
| executor | 87 | 55.2% | 913 | 58.9% | -3.8 (-14.7 to +7.2) |
| nightwatch | 238 | 61.3% | 762 | 57.7% | +3.6 (-3.5 to +10.7) |
| martyr | 88 | 61.4% | 912 | 58.3% | +3.0 (-7.6 to +13.7) |
| monitor | 73 | 56.2% | 927 | 58.8% | -2.6 (-14.4 to +9.2) |
| surveyor | 508 | 59.8% | 492 | 57.3% | +2.5 (-3.6 to +8.6) |
| medium | 188 | 60.6% | 812 | 58.1% | +2.5 (-5.3 to +10.3) |
| warden | 229 | 57.2% | 771 | 59.0% | -1.8 (-9.1 to +5.5) |
| dowser | 286 | 59.4% | 714 | 58.3% | +1.2 (-5.6 to +7.9) |
| sexton | 74 | 59.5% | 926 | 58.5% | +0.9 (-10.7 to +12.6) |
| chronicler | 76 | 59.2% | 924 | 58.5% | +0.7 (-10.8 to +12.2) |
| lamplighter | 203 | 58.1% | 797 | 58.7% | -0.6 (-8.2 to +7.0) |
| rumormonger | 504 | 58.3% | 496 | 58.9% | -0.5 (-6.6 to +5.6) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 68.9% | 781 | 55.7% | +13.3 (+6.2 to +20.3) **\*** |
| poisoner | 325 | 53.2% | 675 | 61.2% | -8.0 (-14.5 to -1.4) **\*** |
| revenant | 221 | 54.3% | 779 | 59.8% | -5.5 (-12.9 to +1.9) |
| scion | 235 | 60.4% | 765 | 58.0% | +2.4 (-4.8 to +9.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 49.5% | 788 | 61.0% | -11.5 (-19.1 to -4.0) **\*** |
| lovers | 208 | 63.5% | 792 | 57.3% | +6.1 (-1.3 to +13.5) |
| muddler | 199 | 61.8% | 801 | 57.8% | +4.0 (-3.6 to +11.6) |
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
| clerk | 545 | 2.3 | 21.7% | 13.8% | 90.3% |
| surveyor | 508 | 2.3 | 21.9% | 13.0% | 92.9% |
| rumormonger | 504 | 2.3 | 20.4% | 15.3% | 93.1% |
| dowser | 286 | 1.8 | 51.7% | 10.1% | 86.4% |
| gravedigger | 283 | 2.1 | 42.0% | 13.8% | 86.2% |
| registrar | 270 | 1.9 | 35.2% | 7.0% | 80.4% |
| nightwatch | 238 | 2.0 | 35.7% | 16.8% | 81.9% |
| warden | 229 | 2.4 | 23.6% | 19.7% | 75.5% |
| confessor | 224 | 2.0 | 33.9% | 15.6% | 84.4% |
| lamplighter | 203 | 2.3 | 28.1% | 10.8% | 79.8% |
| augur | 193 | 2.3 | 30.1% | 16.6% | 73.6% |
| medium | 188 | 2.1 | 30.9% | 10.1% | 77.1% |
| seer | 170 | 1.9 | 44.7% | 11.2% | 79.4% |
| martyr | 88 | 2.2 | 17.0% | 11.4% | 85.2% |
| executor | 87 | 2.3 | 28.7% | 9.2% | 79.3% |
| chronicler | 76 | 2.3 | 21.1% | 15.8% | 86.8% |
| sexton | 74 | 2.5 | 16.2% | 17.6% | 70.3% |
| veteran | 73 | 3.0 | 11.0% | 16.4% | 82.2% |
| magistrate | 73 | 2.1 | 32.9% | 6.8% | 78.1% |
| monitor | 73 | 2.4 | 26.0% | 8.2% | 78.1% |
| psychologist | 67 | 1.9 | 34.3% | 10.4% | 86.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 146 | 0.0% | 52.1% |
| nightwatch | 139 | 0.0% | 61.9% |
| dowser | 138 | 0.0% | 60.1% |
| confessor | 135 | 0.0% | 64.4% |
| medium | 126 | 0.0% | 29.4% |
| lamplighter | 125 | 0.0% | 74.4% |
| gravedigger | 114 | 0.0% | 59.6% |
| surveyor | 113 | 0.0% | 46.9% |
| rumormonger | 109 | 0.0% | 48.6% |
| clerk | 105 | 0.0% | 57.1% |
| archivist | 100 | 0.0% | 65.0% |
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
| nightwatch | 381 | 59.6% | 582 | 49.1% | +10.4 (+4.1 to +16.8) **\*** |
| martyr | 153 | 45.1% | 810 | 54.8% | -9.7 (-18.3 to -1.1) **\*** |
| chronicler | 132 | 45.5% | 831 | 54.5% | -9.1 (-18.2 to +0.1) |
| gravedigger | 345 | 47.5% | 618 | 56.5% | -8.9 (-15.5 to -2.4) **\*** |
| clerk | 562 | 55.9% | 401 | 49.6% | +6.2 (-0.1 to +12.6) |
| monitor | 141 | 48.2% | 822 | 54.1% | -5.9 (-14.8 to +3.0) |
| rumormonger | 570 | 51.2% | 393 | 56.2% | -5.0 (-11.4 to +1.4) |
| seer | 216 | 56.9% | 747 | 52.2% | +4.7 (-2.8 to +12.2) |
| psychologist | 144 | 49.3% | 819 | 54.0% | -4.7 (-13.5 to +4.2) |
| sexton | 141 | 56.7% | 822 | 52.7% | +4.1 (-4.8 to +12.9) |
| registrar | 362 | 55.5% | 601 | 51.9% | +3.6 (-2.9 to +10.1) |
| surveyor | 567 | 54.5% | 396 | 51.5% | +3.0 (-3.4 to +9.4) |
| medium | 373 | 54.7% | 590 | 52.4% | +2.3 (-4.1 to +8.8) |
| augur | 223 | 51.6% | 740 | 53.8% | -2.2 (-9.7 to +5.3) |
| lamplighter | 368 | 54.6% | 595 | 52.4% | +2.2 (-4.3 to +8.7) |
| veteran | 167 | 51.5% | 796 | 53.6% | -2.1 (-10.5 to +6.2) |
| executor | 141 | 51.8% | 822 | 53.5% | -1.8 (-10.7 to +7.2) |
| dowser | 359 | 54.3% | 604 | 52.6% | +1.7 (-4.8 to +8.2) |
| confessor | 375 | 52.3% | 588 | 53.9% | -1.6 (-8.1 to +4.8) |
| magistrate | 126 | 52.4% | 837 | 53.4% | -1.0 (-10.4 to +8.3) |
| warden | 355 | 53.5% | 608 | 53.1% | +0.4 (-6.1 to +6.9) |
| archivist | 540 | 53.1% | 423 | 53.4% | -0.3 (-6.6 to +6.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 429 | 67.1% | 534 | 42.1% | +25.0 (+18.9 to +31.1) **\*** |
| scion | 443 | 45.8% | 520 | 59.6% | -13.8 (-20.1 to -7.5) **\*** |
| poisoner | 601 | 49.6% | 362 | 59.4% | -9.8 (-16.3 to -3.4) **\*** |
| revenant | 453 | 52.3% | 510 | 54.1% | -1.8 (-8.1 to +4.5) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 209 | 49.3% | 754 | 54.4% | -5.1 (-12.7 to +2.6) |
| marked | 181 | 55.8% | 782 | 52.7% | +3.1 (-4.9 to +11.2) |
| lovers | 185 | 50.8% | 778 | 53.9% | -3.0 (-11.1 to +5.0) |
| sleepwalker | 204 | 55.4% | 759 | 52.7% | +2.7 (-5.0 to +10.4) |
| muddler | 184 | 55.4% | 779 | 52.8% | +2.7 (-5.3 to +10.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 525 | 51.8% | 438 | 55.0% | -3.2 (-9.5 to +3.1) |
| 4 night-walkers | 349 | 55.0% | 614 | 52.3% | +2.7 (-3.8 to +9.3) |
| 5 night-walkers | 89 | 55.1% | 874 | 53.1% | +2.0 (-8.9 to +12.8) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 570 | 3.3 | 14.2% | 19.8% | 94.9% |
| surveyor | 567 | 3.3 | 12.9% | 18.9% | 95.4% |
| clerk | 562 | 3.2 | 14.4% | 16.0% | 94.3% |
| archivist | 540 | 2.0 | 56.7% | 10.9% | 94.4% |
| nightwatch | 381 | 2.4 | 30.4% | 18.6% | 87.7% |
| confessor | 375 | 2.5 | 21.6% | 27.7% | 89.3% |
| medium | 373 | 2.7 | 24.9% | 9.7% | 85.0% |
| lamplighter | 368 | 2.9 | 21.5% | 13.0% | 90.8% |
| registrar | 362 | 2.7 | 25.7% | 7.2% | 83.1% |
| dowser | 359 | 2.0 | 48.7% | 12.8% | 86.4% |
| warden | 355 | 3.2 | 11.5% | 26.5% | 84.8% |
| gravedigger | 345 | 2.6 | 31.3% | 12.2% | 91.6% |
| augur | 223 | 3.1 | 18.8% | 20.2% | 81.6% |
| seer | 216 | 2.4 | 32.9% | 9.7% | 87.0% |
| veteran | 167 | 4.0 | 6.0% | 25.7% | 87.4% |
| martyr | 153 | 3.5 | 13.1% | 16.3% | 87.6% |
| psychologist | 144 | 3.0 | 18.1% | 16.7% | 86.8% |
| sexton | 141 | 3.2 | 10.6% | 25.5% | 72.3% |
| monitor | 141 | 3.2 | 19.9% | 6.4% | 82.3% |
| executor | 141 | 3.1 | 20.6% | 10.6% | 85.8% |
| chronicler | 132 | 3.1 | 17.4% | 13.6% | 85.6% |
| magistrate | 126 | 2.4 | 38.1% | 7.1% | 85.7% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 198 | 0.0% | 65.2% |
| registrar | 195 | 0.0% | 43.1% |
| archivist | 193 | 0.0% | 52.3% |
| gravedigger | 189 | 0.0% | 53.4% |
| clerk | 184 | 0.0% | 58.7% |
| rumormonger | 175 | 0.0% | 52.0% |
| confessor | 172 | 0.0% | 69.2% |
| surveyor | 171 | 0.0% | 46.8% |
| medium | 162 | 0.0% | 22.8% |
| nightwatch | 159 | 0.0% | 62.9% |
| lamplighter | 155 | 0.0% | 69.7% |
| magistrate | 124 | 0.0% | 58.1% |
| augur | 113 | 0.0% | 61.9% |
| chronicler | 107 | 0.0% | 57.0% |
| monitor | 106 | 0.0% | 29.2% |
| psychologist | 104 | 0.0% | 40.4% |
| seer | 102 | 0.0% | 39.2% |
| executor | 95 | 0.0% | 43.2% |
| sexton | 34 | 0.0% | 47.1% |
| veteran | 30 | 0.0% | 26.7% |
| warden | 20 | 0.0% | 30.0% |
| martyr | 20 | 0.0% | 50.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 429 | 67.1% | 534 | 42.1% | +25.0 (+18.9 to +31.1) |
| archivist + breathstealer | 235 | 70.2% | 728 | 47.8% | +22.4 (+15.5 to +29.3) |
| poisoner + scion | 206 | 36.4% | 757 | 57.9% | -21.5 (-28.9 to -14.0) |
| breathstealer + surveyor | 254 | 68.1% | 709 | 48.0% | +20.2 (+13.3 to +27.0) |
| breathstealer + rumormonger | 259 | 66.8% | 704 | 48.3% | +18.5 (+11.7 to +25.3) |
| breathstealer + clerk | 248 | 66.9% | 715 | 48.5% | +18.4 (+11.5 to +25.3) |
| rumormonger + scion | 262 | 40.5% | 701 | 58.1% | -17.6 (-24.6 to -10.6) |
| demon + scion | 443 | 45.8% | 520 | 59.6% | -13.8 (-20.1 to -7.5) |
| clerk + nightwatch | 222 | 63.5% | 741 | 50.2% | +13.3 (+6.0 to +20.6) |
| gravedigger + poisoner | 215 | 44.2% | 748 | 55.9% | -11.7 (-19.2 to -4.2) |
| demon + nightwatch | 381 | 59.6% | 582 | 49.1% | +10.4 (+4.1 to +16.8) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 356 | 39.3% | 530 | 24.3% | +15.0 (+8.7 to +21.2) **\*** |
| executor | 132 | 19.7% | 754 | 32.2% | -12.5 (-20.1 to -5.0) **\*** |
| martyr | 141 | 22.0% | 745 | 31.9% | -10.0 (-17.6 to -2.3) **\*** |
| sexton | 132 | 37.1% | 754 | 29.2% | +7.9 (-0.9 to +16.8) |
| confessor | 347 | 25.6% | 539 | 33.4% | -7.7 (-13.8 to -1.7) **\*** |
| clerk | 509 | 33.6% | 377 | 26.0% | +7.6 (+1.6 to +13.6) **\*** |
| dowser | 331 | 34.7% | 555 | 27.7% | +7.0 (+0.7 to +13.3) **\*** |
| augur | 207 | 25.6% | 679 | 31.8% | -6.2 (-13.1 to +0.7) |
| psychologist | 129 | 25.6% | 757 | 31.2% | -5.6 (-13.8 to +2.6) |
| magistrate | 114 | 35.1% | 772 | 29.7% | +5.4 (-3.9 to +14.8) |
| monitor | 124 | 25.8% | 762 | 31.1% | -5.3 (-13.7 to +3.1) |
| rumormonger | 521 | 28.6% | 365 | 32.9% | -4.3 (-10.5 to +1.9) |
| veteran | 152 | 27.0% | 734 | 31.1% | -4.1 (-11.9 to +3.7) |
| chronicler | 121 | 27.3% | 765 | 30.8% | -3.6 (-12.2 to +5.0) |
| registrar | 339 | 28.3% | 547 | 31.6% | -3.3 (-9.5 to +2.9) |
| seer | 205 | 32.7% | 681 | 29.7% | +3.0 (-4.3 to +10.3) |
| warden | 329 | 31.9% | 557 | 29.4% | +2.5 (-3.8 to +8.8) |
| gravedigger | 313 | 31.6% | 573 | 29.7% | +2.0 (-4.4 to +8.3) |
| surveyor | 520 | 29.8% | 366 | 31.1% | -1.3 (-7.5 to +4.8) |
| medium | 336 | 31.0% | 550 | 30.0% | +1.0 (-5.3 to +7.2) |
| lamplighter | 341 | 29.9% | 545 | 30.6% | -0.7 (-6.9 to +5.5) |
| archivist | 503 | 30.4% | 383 | 30.3% | +0.1 (-6.0 to +6.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 389 | 39.1% | 497 | 23.5% | +15.5 (+9.4 to +21.7) **\*** |
| poisoner | 548 | 26.1% | 338 | 37.3% | -11.2 (-17.5 to -4.9) **\*** |
| scion | 412 | 27.2% | 474 | 33.1% | -5.9 (-12.0 to +0.1) |
| revenant | 423 | 31.0% | 463 | 29.8% | +1.2 (-4.9 to +7.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 171 | 33.9% | 715 | 29.5% | +4.4 (-3.4 to +12.3) |
| muddler | 169 | 33.7% | 717 | 29.6% | +4.2 (-3.7 to +12.0) |
| sleepwalker | 183 | 27.3% | 703 | 31.2% | -3.8 (-11.1 to +3.5) |
| lovers | 172 | 28.5% | 714 | 30.8% | -2.3 (-9.9 to +5.2) |
| delusional | 191 | 28.8% | 695 | 30.8% | -2.0 (-9.3 to +5.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 80 | 26.2% | 806 | 30.8% | -4.5 (-14.7 to +5.6) |
| 4 night-walkers | 325 | 31.7% | 561 | 29.6% | +2.1 (-4.2 to +8.4) |
| 3 night-walkers | 481 | 30.1% | 405 | 30.6% | -0.5 (-6.6 to +5.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 521 | 3.7 | 12.7% | 29.9% | 96.9% |
| surveyor | 520 | 3.6 | 16.3% | 25.8% | 96.7% |
| clerk | 509 | 3.7 | 10.8% | 27.3% | 95.7% |
| archivist | 503 | 2.1 | 55.9% | 15.1% | 95.8% |
| nightwatch | 356 | 2.4 | 41.0% | 15.2% | 89.9% |
| confessor | 347 | 2.8 | 27.4% | 28.8% | 91.9% |
| lamplighter | 341 | 2.9 | 26.4% | 22.9% | 90.0% |
| registrar | 339 | 3.0 | 30.4% | 9.7% | 87.0% |
| medium | 336 | 3.1 | 18.8% | 14.9% | 92.0% |
| dowser | 331 | 2.2 | 54.7% | 11.5% | 92.4% |
| warden | 329 | 3.4 | 14.0% | 33.7% | 90.0% |
| gravedigger | 313 | 2.6 | 32.9% | 15.7% | 92.7% |
| augur | 207 | 3.1 | 24.6% | 17.4% | 87.9% |
| seer | 205 | 2.4 | 37.6% | 15.1% | 91.2% |
| veteran | 152 | 4.2 | 2.0% | 35.5% | 94.1% |
| martyr | 141 | 4.0 | 8.5% | 26.2% | 92.2% |
| sexton | 132 | 3.7 | 7.6% | 31.1% | 83.3% |
| executor | 132 | 3.4 | 22.7% | 19.7% | 90.2% |
| psychologist | 129 | 3.2 | 21.7% | 24.0% | 86.0% |
| monitor | 124 | 3.6 | 13.7% | 14.5% | 86.3% |
| chronicler | 121 | 3.1 | 17.4% | 20.7% | 90.1% |
| magistrate | 114 | 2.7 | 29.8% | 9.6% | 93.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 186 | 0.0% | 30.1% |
| dowser | 178 | 0.0% | 43.8% |
| archivist | 176 | 0.0% | 39.8% |
| gravedigger | 176 | 0.0% | 48.3% |
| clerk | 167 | 0.0% | 35.9% |
| confessor | 164 | 0.0% | 44.5% |
| rumormonger | 160 | 0.0% | 38.8% |
| surveyor | 160 | 0.0% | 40.6% |
| medium | 152 | 0.0% | 26.3% |
| lamplighter | 151 | 0.0% | 45.0% |
| nightwatch | 142 | 0.0% | 35.2% |
| magistrate | 118 | 0.0% | 38.1% |
| augur | 105 | 0.0% | 40.0% |
| monitor | 101 | 0.0% | 8.9% |
| chronicler | 100 | 0.0% | 36.0% |
| psychologist | 97 | 0.0% | 34.0% |
| seer | 94 | 0.0% | 38.3% |
| executor | 89 | 0.0% | 29.2% |
| sexton | 28 | 0.0% | 50.0% |
| veteran | 26 | 0.0% | 26.9% |
| martyr | 20 | 0.0% | 20.0% |
| warden | 18 | 0.0% | 44.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| clerk + nightwatch | 203 | 44.3% | 683 | 26.2% | +18.1 (+10.5 to +25.7) |
| breathstealer + clerk | 217 | 43.3% | 669 | 26.2% | +17.2 (+9.8 to +24.5) |
| breathstealer + demon | 389 | 39.1% | 497 | 23.5% | +15.5 (+9.4 to +21.7) |
| demon + nightwatch | 356 | 39.3% | 530 | 24.3% | +15.0 (+8.7 to +21.2) |
| breathstealer + surveyor | 228 | 39.9% | 658 | 27.1% | +12.9 (+5.7 to +20.1) |
| archivist + breathstealer | 220 | 40.0% | 666 | 27.2% | +12.8 (+5.5 to +20.1) |
| demon + poisoner | 548 | 26.1% | 338 | 37.3% | -11.2 (-17.5 to -4.9) |
| archivist + nightwatch | 203 | 38.9% | 683 | 27.8% | +11.1 (+3.6 to +18.6) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 10 | 10 NPCs, bot insight 1.0 | 861 | 272 (31.6%) | 78 (9.1%) | 185 | 326 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: 10 NPCs, bot insight 1.0: 4 (first 100607, 100608, 100670, 100671); 10 NPCs, passive: 114 (first 100124, 100249, 100497, 100498, 100499, 100591, 100592, 100593, 100594, 100595)
- Failed games (crash or timeout): 33 — seeds 100217 (timeout), 100128 (timeout), 100906 (timeout), 100053 (timeout), 100027 (timeout), 100531 (timeout), 100289 (timeout), 100305 (timeout), 100835 (timeout), 100783 (timeout), 100651 (timeout), 100654 (timeout), 100657 (timeout), 100661 (timeout), 100643 (timeout), 100650 (timeout), 100619 (timeout), 100593 (timeout), 100595 (timeout), 100597 (timeout), 100378 (timeout), 100370 (timeout), 100953 (timeout), 100964 (timeout), 100986 (timeout), 100991 (timeout), 100993 (timeout), 100927 (timeout), 100938 (timeout), 100684 (timeout)
- Games with engine errors: 3
  - Most common lines:
    - 33× `exit -9`
    - 6× `SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedFloat64Array')`
    - 1× `SCRIPT ERROR: Out of bounds get index '2628' (on base: 'PackedInt64Array')`
    - 1× `SCRIPT ERROR: Out of bounds get index '2460' (on base: 'PackedInt64Array')`
    - 1× `SCRIPT ERROR: Out of bounds get index '2376' (on base: 'PackedInt64Array')`
- Shared-model fallbacks: 6 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 76.7 | 166.9 | 494.0 |
| 10 NPCs, bot insight 1.0 | 504.2 | 1096.2 | 1795.3 |
| 10 NPCs, passive | 139.6 | 346.5 | 1568.6 |

Slowest seeds: 100095 (10 NPCs bot, 1795 s), 100988 (10 NPCs bot, 1792 s), 100896 (10 NPCs bot, 1791 s), 100925 (10 NPCs bot, 1787 s), 100527 (10 NPCs bot, 1779 s), 100663 (10 NPCs bot, 1773 s), 100824 (10 NPCs bot, 1752 s), 100889 (10 NPCs bot, 1738 s), 100664 (10 NPCs bot, 1714 s), 100688 (10 NPCs bot, 1714 s), 100894 (10 NPCs bot, 1710 s), 100170 (10 NPCs bot, 1684 s), 100695 (10 NPCs bot, 1680 s), 100850 (10 NPCs bot, 1647 s), 100316 (10 NPCs bot, 1643 s), 100482 (10 NPCs bot, 1620 s), 100766 (10 NPCs bot, 1602 s), 100603 (10 NPCs bot, 1599 s), 100601 (10 NPCs bot, 1586 s), 100012 (10 NPCs passive, 1569 s)

