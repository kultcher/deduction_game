# Balance sweep report

Records: 3000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `0743a76db8`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 58.5% (55.4%–61.5%) | 3.18 | 0.68 | 1.07 | 2.38 | 8.5% | 0.24 |
| 10 NPCs, bot insight 1.0 | 1000 | 53.1% (50.0%–56.2%) | 4.39 | 1.10 | 1.57 | 2.62 | 7.4% | 0.45 |
| 10 NPCs, passive | 1000 | 29.9% (27.1%–32.8%) | 4.72 | 1.52 | 1.11 | 2.72 | 2.6% | 0.60 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 585 (58.5%)
- Only two townsfolk remain and the demon still walks among them.: 414 (41.4%)
- Time ran out: the demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 98.9% of games; good win rate 58.0% of 989
- Demon evidence reachable: 78.8% of games; good win rate 53.8% of 788
- Neither: 0.8% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 531 (53.1%)
- Only two townsfolk remain and the demon still walks among them.: 305 (30.5%)
- No good soul remains.: 162 (16.2%)
- Time ran out: the demon survived 8 days.: 2 (0.2%)
- Demon evidence on the board: 99.5% of games; good win rate 52.9% of 995
- Demon evidence reachable: 90.0% of games; good win rate 50.9% of 900
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=1000)

- No good soul remains.: 401 (40.1%)
- The demon's host was executed.: 299 (29.9%)
- Only two townsfolk remain and the demon still walks among them.: 295 (29.5%)
- Time ran out: the demon survived 8 days.: 5 (0.5%)
- Demon evidence on the board: 79.5% of games; good win rate 32.1% of 795
- Demon evidence reachable: 100.0% of games; good win rate 29.9% of 1000
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| veteran | 73 | 67.1% | 927 | 57.8% | +9.3 (-1.9 to +20.5) |
| magistrate | 73 | 65.8% | 927 | 57.9% | +7.8 (-3.5 to +19.2) |
| registrar | 270 | 64.1% | 730 | 56.4% | +7.6 (+0.9 to +14.4) **\*** |
| gravedigger | 283 | 53.4% | 717 | 60.5% | -7.2 (-14.0 to -0.3) **\*** |
| martyr | 88 | 64.8% | 912 | 57.9% | +6.9 (-3.6 to +17.4) |
| psychologist | 67 | 52.2% | 933 | 58.9% | -6.7 (-19.1 to +5.7) |
| clerk | 545 | 61.3% | 455 | 55.2% | +6.1 (-0.0 to +12.3) |
| archivist | 548 | 56.0% | 452 | 61.5% | -5.5 (-11.6 to +0.6) |
| augur | 193 | 55.4% | 807 | 59.2% | -3.8 (-11.6 to +4.0) |
| confessor | 224 | 55.8% | 776 | 59.3% | -3.5 (-10.8 to +3.9) |
| warden | 229 | 55.9% | 771 | 59.3% | -3.4 (-10.7 to +3.9) |
| medium | 188 | 61.2% | 812 | 57.9% | +3.3 (-4.5 to +11.0) |
| rumormonger | 504 | 57.1% | 496 | 59.9% | -2.7 (-8.8 to +3.4) |
| surveyor | 508 | 59.6% | 492 | 57.3% | +2.3 (-3.8 to +8.4) |
| seer | 170 | 60.0% | 830 | 58.2% | +1.8 (-6.3 to +9.9) |
| lamplighter | 203 | 57.1% | 797 | 58.8% | -1.7 (-9.3 to +5.9) |
| executor | 87 | 57.5% | 913 | 58.6% | -1.1 (-12.0 to +9.7) |
| sexton | 74 | 59.5% | 926 | 58.4% | +1.0 (-10.6 to +12.7) |
| nightwatch | 238 | 58.0% | 762 | 58.7% | -0.7 (-7.9 to +6.5) |
| chronicler | 76 | 57.9% | 924 | 58.5% | -0.7 (-12.2 to +10.9) |
| monitor | 73 | 58.9% | 927 | 58.5% | +0.4 (-11.3 to +12.2) |
| dowser | 286 | 58.7% | 714 | 58.4% | +0.3 (-6.4 to +7.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 69.9% | 781 | 55.3% | +14.5 (+7.5 to +21.6) **\*** |
| poisoner | 325 | 53.2% | 675 | 61.0% | -7.8 (-14.4 to -1.3) **\*** |
| revenant | 221 | 56.1% | 779 | 59.2% | -3.1 (-10.5 to +4.3) |
| scion | 235 | 57.4% | 765 | 58.8% | -1.4 (-8.6 to +5.8) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 50.0% | 788 | 60.8% | -10.8 (-18.3 to -3.2) **\*** |
| muddler | 199 | 63.8% | 801 | 57.2% | +6.6 (-0.9 to +14.1) |
| lovers | 208 | 61.5% | 792 | 57.7% | +3.8 (-3.6 to +11.3) |
| sleepwalker | 186 | 60.2% | 814 | 58.1% | +2.1 (-5.7 to +9.9) |
| marked | 195 | 57.4% | 805 | 58.8% | -1.3 (-9.1 to +6.4) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 39.5% | 957 | 59.4% | -19.8 (-34.8 to -4.9) **\*** |
| 2 night-walkers | 636 | 61.6% | 364 | 53.0% | +8.6 (+2.2 to +15.0) **\*** |
| 3 night-walkers | 321 | 54.8% | 679 | 60.2% | -5.4 (-12.0 to +1.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 51.5% | 16.2% | 95.4% |
| clerk | 545 | 2.3 | 21.1% | 13.2% | 90.5% |
| surveyor | 508 | 2.3 | 22.0% | 13.2% | 92.5% |
| rumormonger | 504 | 2.3 | 21.6% | 14.9% | 93.1% |
| dowser | 286 | 1.8 | 52.4% | 9.8% | 86.0% |
| gravedigger | 283 | 2.0 | 42.0% | 14.8% | 86.2% |
| registrar | 270 | 2.0 | 35.2% | 7.8% | 80.0% |
| nightwatch | 238 | 2.1 | 35.3% | 15.5% | 82.8% |
| warden | 229 | 2.3 | 24.0% | 18.8% | 76.4% |
| confessor | 224 | 2.1 | 33.0% | 16.5% | 84.8% |
| lamplighter | 203 | 2.3 | 28.6% | 11.3% | 80.3% |
| augur | 193 | 2.2 | 29.0% | 15.0% | 75.6% |
| medium | 188 | 2.2 | 29.8% | 8.5% | 76.6% |
| seer | 170 | 2.0 | 44.7% | 9.4% | 81.2% |
| martyr | 88 | 2.3 | 15.9% | 13.6% | 85.2% |
| executor | 87 | 2.3 | 28.7% | 8.0% | 78.2% |
| chronicler | 76 | 2.3 | 23.7% | 15.8% | 86.8% |
| sexton | 74 | 2.5 | 16.2% | 18.9% | 68.9% |
| veteran | 73 | 3.0 | 11.0% | 17.8% | 82.2% |
| magistrate | 73 | 2.1 | 31.5% | 11.0% | 79.5% |
| monitor | 73 | 2.3 | 30.1% | 5.5% | 76.7% |
| psychologist | 67 | 2.1 | 29.9% | 14.9% | 88.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 148 | 0.0% | 52.0% |
| dowser | 138 | 0.0% | 63.8% |
| nightwatch | 138 | 0.0% | 58.0% |
| confessor | 135 | 0.0% | 63.7% |
| medium | 126 | 0.0% | 30.2% |
| lamplighter | 125 | 0.0% | 75.2% |
| gravedigger | 114 | 0.0% | 57.0% |
| surveyor | 113 | 0.0% | 46.0% |
| rumormonger | 109 | 0.0% | 51.4% |
| clerk | 105 | 0.0% | 60.0% |
| archivist | 100 | 0.0% | 62.0% |
| psychologist | 79 | 0.0% | 59.5% |
| chronicler | 77 | 0.0% | 57.1% |
| magistrate | 76 | 0.0% | 46.1% |
| executor | 76 | 0.0% | 47.4% |
| seer | 75 | 0.0% | 54.7% |
| augur | 73 | 0.0% | 57.5% |
| monitor | 62 | 0.0% | 40.3% |
| martyr | 18 | 0.0% | 38.9% |
| warden | 17 | 0.0% | 47.1% |
| veteran | 16 | 0.0% | 31.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 69.9% | 781 | 55.3% | +14.5 (+7.5 to +21.6) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| executor | 147 | 42.9% | 853 | 54.9% | -12.0 (-20.7 to -3.3) **\*** |
| magistrate | 135 | 60.0% | 865 | 52.0% | +8.0 (-0.9 to +16.9) |
| martyr | 156 | 46.8% | 844 | 54.3% | -7.5 (-16.0 to +1.1) |
| chronicler | 137 | 46.7% | 863 | 54.1% | -7.4 (-16.4 to +1.6) |
| gravedigger | 358 | 49.2% | 642 | 55.3% | -6.1 (-12.6 to +0.3) |
| sexton | 148 | 48.0% | 852 | 54.0% | -6.0 (-14.7 to +2.7) |
| nightwatch | 396 | 56.3% | 604 | 51.0% | +5.3 (-1.0 to +11.6) |
| surveyor | 588 | 55.3% | 412 | 50.0% | +5.3 (-1.0 to +11.6) |
| dowser | 372 | 55.9% | 628 | 51.4% | +4.5 (-1.9 to +10.9) |
| psychologist | 148 | 56.8% | 852 | 52.5% | +4.3 (-4.4 to +12.9) |
| veteran | 172 | 56.4% | 828 | 52.4% | +4.0 (-4.2 to +12.1) |
| seer | 225 | 56.0% | 775 | 52.3% | +3.7 (-3.6 to +11.1) |
| clerk | 581 | 54.6% | 419 | 51.1% | +3.5 (-2.8 to +9.8) |
| rumormonger | 590 | 51.7% | 410 | 55.1% | -3.4 (-9.7 to +2.9) |
| augur | 231 | 55.4% | 769 | 52.4% | +3.0 (-4.3 to +10.3) |
| registrar | 377 | 51.5% | 623 | 54.1% | -2.6 (-9.0 to +3.8) |
| monitor | 144 | 51.4% | 856 | 53.4% | -2.0 (-10.8 to +6.8) |
| lamplighter | 382 | 52.1% | 618 | 53.7% | -1.6 (-8.0 to +4.7) |
| confessor | 389 | 52.2% | 611 | 53.7% | -1.5 (-7.8 to +4.8) |
| medium | 384 | 53.6% | 616 | 52.8% | +0.9 (-5.5 to +7.2) |
| warden | 377 | 53.6% | 623 | 52.8% | +0.8 (-5.6 to +7.2) |
| archivist | 563 | 52.9% | 437 | 53.3% | -0.4 (-6.6 to +5.8) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 66.2% | 559 | 42.8% | +23.5 (+17.4 to +29.5) **\*** |
| scion | 467 | 46.0% | 533 | 59.3% | -13.2 (-19.4 to -7.1) **\*** |
| poisoner | 620 | 49.0% | 380 | 59.7% | -10.7 (-17.0 to -4.4) **\*** |
| revenant | 472 | 53.2% | 528 | 53.0% | +0.1 (-6.0 to +6.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 47.2% | 784 | 54.7% | -7.5 (-15.0 to +0.0) |
| sleepwalker | 207 | 58.0% | 793 | 51.8% | +6.1 (-1.4 to +13.7) |
| muddler | 191 | 57.6% | 809 | 52.0% | +5.6 (-2.3 to +13.4) |
| lovers | 195 | 49.7% | 805 | 53.9% | -4.2 (-12.0 to +3.6) |
| marked | 191 | 53.4% | 809 | 53.0% | +0.4 (-7.5 to +8.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 46.2% | 909 | 53.8% | -7.6 (-18.4 to +3.1) |
| 3 night-walkers | 543 | 54.9% | 457 | 51.0% | +3.9 (-2.3 to +10.1) |
| 4 night-walkers | 366 | 52.2% | 634 | 53.6% | -1.4 (-7.9 to +5.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 14.2% | 18.5% | 95.1% |
| surveyor | 588 | 3.2 | 12.9% | 19.7% | 95.6% |
| clerk | 581 | 3.3 | 13.9% | 15.0% | 95.0% |
| archivist | 563 | 2.0 | 55.6% | 10.3% | 94.5% |
| nightwatch | 396 | 2.4 | 30.8% | 17.7% | 87.6% |
| confessor | 389 | 2.7 | 21.6% | 25.7% | 90.5% |
| medium | 384 | 2.8 | 23.2% | 8.9% | 85.9% |
| lamplighter | 382 | 3.1 | 21.2% | 12.3% | 90.8% |
| warden | 377 | 3.3 | 10.9% | 24.7% | 85.9% |
| registrar | 377 | 2.8 | 26.3% | 8.0% | 84.9% |
| dowser | 372 | 2.0 | 49.7% | 11.8% | 86.6% |
| gravedigger | 358 | 2.6 | 32.7% | 14.2% | 91.3% |
| augur | 231 | 3.1 | 18.6% | 18.2% | 83.1% |
| seer | 225 | 2.4 | 33.8% | 9.8% | 87.1% |
| veteran | 172 | 4.0 | 5.2% | 27.3% | 88.4% |
| martyr | 156 | 3.3 | 14.7% | 14.1% | 86.5% |
| sexton | 148 | 3.4 | 10.8% | 31.1% | 73.6% |
| psychologist | 148 | 2.9 | 18.9% | 14.9% | 87.8% |
| executor | 147 | 3.2 | 18.4% | 12.9% | 88.4% |
| monitor | 144 | 3.3 | 19.4% | 4.9% | 84.7% |
| chronicler | 137 | 3.0 | 19.7% | 12.4% | 86.9% |
| magistrate | 135 | 2.5 | 37.8% | 7.4% | 87.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 207 | 0.0% | 49.3% |
| dowser | 206 | 0.0% | 67.5% |
| archivist | 198 | 0.0% | 52.0% |
| gravedigger | 194 | 0.0% | 55.7% |
| clerk | 190 | 0.0% | 56.3% |
| confessor | 184 | 0.0% | 67.9% |
| rumormonger | 183 | 0.0% | 53.6% |
| surveyor | 176 | 0.0% | 48.9% |
| medium | 168 | 0.0% | 22.6% |
| nightwatch | 166 | 0.0% | 60.8% |
| lamplighter | 166 | 0.0% | 69.9% |
| magistrate | 131 | 0.0% | 58.0% |
| augur | 119 | 0.0% | 56.3% |
| monitor | 109 | 0.0% | 29.4% |
| chronicler | 109 | 0.0% | 57.8% |
| psychologist | 108 | 0.0% | 45.4% |
| seer | 104 | 0.0% | 37.5% |
| executor | 98 | 0.0% | 37.8% |
| sexton | 35 | 0.0% | 48.6% |
| veteran | 31 | 0.0% | 35.5% |
| warden | 21 | 0.0% | 28.6% |
| martyr | 20 | 0.0% | 35.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 66.2% | 559 | 42.8% | +23.5 (+17.4 to +29.5) |
| poisoner + scion | 215 | 36.3% | 785 | 57.7% | -21.4 (-28.7 to -14.1) |
| breathstealer + clerk | 253 | 68.8% | 747 | 47.8% | +21.0 (+14.2 to +27.7) |
| breathstealer + rumormonger | 264 | 66.7% | 736 | 48.2% | +18.4 (+11.7 to +25.2) |
| breathstealer + surveyor | 261 | 66.7% | 739 | 48.3% | +18.4 (+11.6 to +25.1) |
| archivist + breathstealer | 243 | 65.8% | 757 | 49.0% | +16.8 (+9.9 to +23.8) |
| rumormonger + scion | 276 | 42.4% | 724 | 57.2% | -14.8 (-21.6 to -7.9) |
| demon + scion | 467 | 46.0% | 533 | 59.3% | -13.2 (-19.4 to -7.1) |
| demon + poisoner | 620 | 49.0% | 380 | 59.7% | -10.7 (-17.0 to -4.4) |
| lamplighter + poisoner | 207 | 44.9% | 793 | 55.2% | -10.3 (-17.9 to -2.7) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 37.6% | 604 | 24.8% | +12.8 (+6.9 to +18.7) **\*** |
| executor | 147 | 21.8% | 853 | 31.3% | -9.5 (-16.9 to -2.2) **\*** |
| seer | 225 | 36.0% | 775 | 28.1% | +7.9 (+0.8 to +14.9) **\*** |
| confessor | 389 | 25.2% | 611 | 32.9% | -7.7 (-13.4 to -2.0) **\*** |
| clerk | 581 | 33.0% | 419 | 25.5% | +7.5 (+1.8 to +13.2) **\*** |
| augur | 231 | 24.2% | 769 | 31.6% | -7.4 (-13.8 to -0.9) **\*** |
| martyr | 156 | 24.4% | 844 | 30.9% | -6.6 (-14.0 to +0.9) |
| monitor | 144 | 24.3% | 856 | 30.8% | -6.5 (-14.2 to +1.1) |
| rumormonger | 590 | 27.3% | 410 | 33.7% | -6.4 (-12.2 to -0.6) **\*** |
| sexton | 148 | 35.1% | 852 | 29.0% | +6.1 (-2.1 to +14.4) |
| veteran | 172 | 25.0% | 828 | 30.9% | -5.9 (-13.1 to +1.3) |
| dowser | 372 | 33.6% | 628 | 27.7% | +5.9 (-0.0 to +11.8) |
| psychologist | 148 | 26.4% | 852 | 30.5% | -4.2 (-11.9 to +3.6) |
| registrar | 377 | 27.9% | 623 | 31.1% | -3.3 (-9.1 to +2.5) |
| chronicler | 137 | 27.7% | 863 | 30.2% | -2.5 (-10.6 to +5.6) |
| magistrate | 135 | 31.9% | 865 | 29.6% | +2.3 (-6.2 to +10.7) |
| warden | 377 | 31.3% | 623 | 29.1% | +2.2 (-3.6 to +8.1) |
| medium | 384 | 30.7% | 616 | 29.4% | +1.3 (-4.5 to +7.2) |
| surveyor | 588 | 30.3% | 412 | 29.4% | +0.9 (-4.9 to +6.7) |
| gravedigger | 358 | 30.4% | 642 | 29.6% | +0.9 (-5.1 to +6.8) |
| archivist | 563 | 30.0% | 437 | 29.7% | +0.3 (-5.4 to +6.0) |
| lamplighter | 382 | 29.8% | 618 | 29.9% | -0.1 (-5.9 to +5.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 39.7% | 559 | 22.2% | +17.5 (+11.8 to +23.2) **\*** |
| poisoner | 620 | 25.8% | 380 | 36.6% | -10.8 (-16.7 to -4.8) **\*** |
| scion | 467 | 26.1% | 533 | 33.2% | -7.1 (-12.7 to -1.4) **\*** |
| revenant | 472 | 29.9% | 528 | 29.9% | -0.1 (-5.7 to +5.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 27.3% | 784 | 30.6% | -3.3 (-10.1 to +3.5) |
| marked | 191 | 32.5% | 809 | 29.3% | +3.2 (-4.2 to +10.5) |
| muddler | 191 | 32.5% | 809 | 29.3% | +3.2 (-4.2 to +10.5) |
| lovers | 195 | 28.2% | 805 | 30.3% | -2.1 (-9.2 to +5.0) |
| sleepwalker | 207 | 29.5% | 793 | 30.0% | -0.5 (-7.5 to +6.4) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 26.4% | 909 | 30.3% | -3.9 (-13.4 to +5.7) |
| 4 night-walkers | 366 | 30.3% | 634 | 29.7% | +0.7 (-5.2 to +6.6) |
| 3 night-walkers | 543 | 30.2% | 457 | 29.5% | +0.7 (-5.0 to +6.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.7 | 13.1% | 29.3% | 96.4% |
| surveyor | 588 | 3.6 | 15.6% | 25.5% | 96.8% |
| clerk | 581 | 3.7 | 10.2% | 28.9% | 96.2% |
| archivist | 563 | 2.1 | 55.4% | 15.5% | 96.1% |
| nightwatch | 396 | 2.4 | 40.7% | 15.7% | 90.7% |
| confessor | 389 | 2.8 | 28.3% | 27.2% | 91.5% |
| medium | 384 | 3.0 | 19.8% | 15.4% | 91.4% |
| lamplighter | 382 | 2.9 | 26.4% | 24.1% | 89.5% |
| warden | 377 | 3.3 | 15.4% | 32.6% | 89.7% |
| registrar | 377 | 2.9 | 31.6% | 10.3% | 87.0% |
| dowser | 372 | 2.2 | 54.0% | 10.8% | 92.5% |
| gravedigger | 358 | 2.7 | 32.1% | 15.9% | 92.5% |
| augur | 231 | 3.1 | 25.1% | 16.0% | 89.6% |
| seer | 225 | 2.4 | 36.4% | 14.7% | 92.4% |
| veteran | 172 | 4.2 | 1.7% | 37.8% | 94.8% |
| martyr | 156 | 4.1 | 8.3% | 26.3% | 92.3% |
| psychologist | 148 | 3.2 | 22.3% | 25.7% | 85.8% |
| sexton | 148 | 3.6 | 9.5% | 32.4% | 83.1% |
| executor | 147 | 3.4 | 21.1% | 19.7% | 90.5% |
| monitor | 144 | 3.6 | 14.6% | 13.9% | 83.3% |
| chronicler | 137 | 3.2 | 16.1% | 19.0% | 90.5% |
| magistrate | 135 | 2.7 | 29.6% | 13.3% | 91.9% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 214 | 0.0% | 30.8% |
| dowser | 206 | 0.0% | 46.1% |
| archivist | 198 | 0.0% | 40.4% |
| gravedigger | 195 | 0.0% | 48.7% |
| clerk | 190 | 0.0% | 34.7% |
| confessor | 184 | 0.0% | 42.9% |
| rumormonger | 183 | 0.0% | 39.9% |
| surveyor | 175 | 0.0% | 41.7% |
| lamplighter | 171 | 0.0% | 46.8% |
| medium | 168 | 0.0% | 26.8% |
| nightwatch | 167 | 0.0% | 35.9% |
| magistrate | 130 | 0.0% | 34.6% |
| augur | 123 | 0.0% | 39.0% |
| chronicler | 112 | 0.0% | 33.0% |
| psychologist | 111 | 0.0% | 32.4% |
| monitor | 109 | 0.0% | 9.2% |
| seer | 105 | 0.0% | 35.2% |
| executor | 100 | 0.0% | 27.0% |
| sexton | 33 | 0.0% | 48.5% |
| veteran | 30 | 0.0% | 23.3% |
| martyr | 21 | 0.0% | 19.0% |
| warden | 20 | 0.0% | 50.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + clerk | 253 | 43.5% | 747 | 25.3% | +18.2 (+11.3 to +25.0) |
| breathstealer + demon | 441 | 39.7% | 559 | 22.2% | +17.5 (+11.8 to +23.2) |
| poisoner + scion | 215 | 17.2% | 785 | 33.4% | -16.2 (-22.2 to -10.1) |
| clerk + nightwatch | 225 | 42.2% | 775 | 26.3% | +15.9 (+8.7 to +23.1) |
| breathstealer + surveyor | 261 | 41.0% | 739 | 26.0% | +15.0 (+8.3 to +21.8) |
| archivist + breathstealer | 243 | 40.3% | 757 | 26.6% | +13.8 (+6.9 to +20.7) |
| demon + nightwatch | 396 | 37.6% | 604 | 24.8% | +12.8 (+6.9 to +18.7) |
| confessor + poisoner | 220 | 21.4% | 780 | 32.3% | -10.9 (-17.3 to -4.6) |
| demon + poisoner | 620 | 25.8% | 380 | 36.6% | -10.8 (-16.7 to -4.8) |
| breathstealer + rumormonger | 264 | 37.5% | 736 | 27.2% | +10.3 (+3.7 to +17.0) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 10 | 10 NPCs, bot insight 1.0 | 1000 | 324 (32.4%) | 92 (9.2%) | 207 | 377 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 7 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 55.2 | 131.3 | 405.3 |
| 10 NPCs, bot insight 1.0 | 295.4 | 598.6 | 1531.3 |
| 10 NPCs, passive | 23.7 | 43.3 | 123.4 |

Slowest seeds: 100684 (10 NPCs bot, 1531 s), 100619 (10 NPCs bot, 1441 s), 100258 (10 NPCs bot, 1218 s), 100664 (10 NPCs bot, 1192 s), 100426 (10 NPCs bot, 1148 s), 100217 (10 NPCs bot, 1148 s), 100839 (10 NPCs bot, 1144 s), 100688 (10 NPCs bot, 1077 s), 100421 (10 NPCs bot, 1065 s), 100305 (10 NPCs bot, 1035 s), 100646 (10 NPCs bot, 969 s), 100993 (10 NPCs bot, 961 s), 100298 (10 NPCs bot, 912 s), 100308 (10 NPCs bot, 903 s), 100322 (10 NPCs bot, 903 s), 100237 (10 NPCs bot, 903 s), 100791 (10 NPCs bot, 900 s), 100695 (10 NPCs bot, 877 s), 100547 (10 NPCs bot, 860 s), 100693 (10 NPCs bot, 855 s)

