# Balance sweep report

Records: 4000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `dc2418cfbd`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 59.3% (56.2%–62.3%) | 3.15 | 0.69 | 1.06 | 2.35 | 8.2% | 0.27 |
| 7 NPCs, passive | 1000 | 35.9% (33.0%–38.9%) | 3.50 | 0.91 | 0.75 | 2.41 | 3.3% | 0.25 |
| 10 NPCs, bot insight 1.0 | 1000 | 55.2% (52.1%–58.3%) | 4.29 | 1.12 | 1.58 | 2.51 | 8.0% | 0.47 |
| 10 NPCs, passive | 1000 | 39.0% (36.0%–42.1%) | 4.58 | 1.35 | 1.33 | 2.63 | 3.2% | 0.55 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 593 (59.3%)
- Only two townsfolk remain and the demon still walks among them.: 407 (40.7%)
- Demon evidence on the board: 98.7% of games; good win rate 58.9% of 987
- Demon evidence reachable: 80.5% of games; good win rate 53.5% of 805
- Neither: 0.7% of games; good win rate 100.0% of 7
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=1000)

- Only two townsfolk remain and the demon still walks among them.: 641 (64.1%)
- The demon's host was executed.: 359 (35.9%)
- Demon evidence on the board: 61.8% of games; good win rate 45.0% of 618
- Demon evidence reachable: 99.5% of games; good win rate 35.6% of 995
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 552 (55.2%)
- Only two townsfolk remain and the demon still walks among them.: 286 (28.6%)
- No good soul remains.: 162 (16.2%)
- Demon evidence on the board: 99.3% of games; good win rate 54.9% of 993
- Demon evidence reachable: 90.4% of games; good win rate 53.2% of 904
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=1000)

- The demon's host was executed.: 390 (39.0%)
- Only two townsfolk remain and the demon still walks among them.: 306 (30.6%)
- No good soul remains.: 301 (30.1%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 78.7% of games; good win rate 42.3% of 787
- Demon evidence reachable: 99.9% of games; good win rate 38.9% of 999
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| veteran | 73 | 65.8% | 927 | 58.8% | +7.0 (-4.4 to +18.3) |
| gravedigger | 283 | 54.8% | 717 | 61.1% | -6.3 (-13.1 to +0.5) |
| confessor | 224 | 54.9% | 776 | 60.6% | -5.7 (-13.0 to +1.7) |
| clerk | 545 | 61.7% | 455 | 56.5% | +5.2 (-0.9 to +11.3) |
| archivist | 548 | 57.1% | 452 | 61.9% | -4.8 (-10.9 to +1.3) |
| chronicler | 76 | 55.3% | 924 | 59.6% | -4.4 (-16.0 to +7.2) |
| martyr | 88 | 55.7% | 912 | 59.6% | -4.0 (-14.8 to +6.9) |
| warden | 229 | 62.0% | 771 | 58.5% | +3.5 (-3.7 to +10.7) |
| executor | 87 | 62.1% | 913 | 59.0% | +3.0 (-7.7 to +13.7) |
| nightwatch | 238 | 61.3% | 762 | 58.7% | +2.7 (-4.4 to +9.8) |
| dowser | 286 | 61.2% | 714 | 58.5% | +2.6 (-4.1 to +9.4) |
| magistrate | 73 | 61.6% | 927 | 59.1% | +2.5 (-9.1 to +14.1) |
| augur | 193 | 58.0% | 807 | 59.6% | -1.6 (-9.3 to +6.2) |
| sexton | 74 | 58.1% | 926 | 59.4% | -1.3 (-13.0 to +10.4) |
| lamplighter | 203 | 60.1% | 797 | 59.1% | +1.0 (-6.6 to +8.6) |
| registrar | 270 | 60.0% | 730 | 59.0% | +1.0 (-5.9 to +7.8) |
| rumormonger | 504 | 59.7% | 496 | 58.9% | +0.9 (-5.2 to +6.9) |
| seer | 170 | 60.0% | 830 | 59.2% | +0.8 (-7.2 to +8.9) |
| psychologist | 67 | 59.7% | 933 | 59.3% | +0.4 (-11.7 to +12.6) |
| monitor | 73 | 58.9% | 927 | 59.3% | -0.4 (-12.1 to +11.3) |
| medium | 188 | 59.0% | 812 | 59.4% | -0.3 (-8.1 to +7.5) |
| surveyor | 508 | 59.3% | 492 | 59.3% | -0.1 (-6.2 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 70.3% | 781 | 56.2% | +14.1 (+7.1 to +21.1) **\*** |
| revenant | 221 | 55.2% | 779 | 60.5% | -5.3 (-12.7 to +2.1) |
| poisoner | 325 | 56.0% | 675 | 60.9% | -4.9 (-11.4 to +1.6) |
| scion | 235 | 57.4% | 765 | 59.9% | -2.4 (-9.6 to +4.8) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 47.6% | 788 | 62.4% | -14.8 (-22.3 to -7.3) **\*** |
| muddler | 199 | 63.8% | 801 | 58.2% | +5.6 (-1.9 to +13.1) |
| sleepwalker | 186 | 63.4% | 814 | 58.4% | +5.1 (-2.6 to +12.8) |
| marked | 195 | 62.1% | 805 | 58.6% | +3.4 (-4.2 to +11.0) |
| lovers | 208 | 60.6% | 792 | 59.0% | +1.6 (-5.9 to +9.1) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 46.5% | 957 | 59.9% | -13.4 (-28.6 to +1.9) |
| 2 night-walkers | 636 | 59.7% | 364 | 58.5% | +1.2 (-5.1 to +7.6) |
| 3 night-walkers | 321 | 60.1% | 679 | 58.9% | +1.2 (-5.3 to +7.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.6 | 51.6% | 16.2% | 94.3% |
| clerk | 545 | 2.3 | 22.2% | 14.5% | 88.6% |
| surveyor | 508 | 2.3 | 22.8% | 12.0% | 92.9% |
| rumormonger | 504 | 2.2 | 25.2% | 14.5% | 91.9% |
| dowser | 286 | 1.8 | 50.7% | 9.4% | 83.6% |
| gravedigger | 283 | 2.1 | 40.3% | 15.9% | 86.2% |
| registrar | 270 | 2.2 | 35.6% | 7.0% | 79.3% |
| nightwatch | 238 | 2.0 | 40.8% | 15.5% | 82.8% |
| warden | 229 | 2.4 | 17.5% | 23.6% | 81.2% |
| confessor | 224 | 2.1 | 25.9% | 21.4% | 81.2% |
| lamplighter | 203 | 2.2 | 29.1% | 13.3% | 85.2% |
| augur | 193 | 2.2 | 30.6% | 12.4% | 76.7% |
| medium | 188 | 2.2 | 23.4% | 11.2% | 73.9% |
| seer | 170 | 1.9 | 44.7% | 11.2% | 86.5% |
| martyr | 88 | 2.4 | 18.2% | 6.8% | 86.4% |
| executor | 87 | 2.2 | 26.4% | 8.0% | 72.4% |
| chronicler | 76 | 2.5 | 21.1% | 13.2% | 81.6% |
| sexton | 74 | 2.4 | 16.2% | 23.0% | 66.2% |
| veteran | 73 | 2.9 | 8.2% | 15.1% | 84.9% |
| magistrate | 73 | 2.3 | 35.6% | 5.5% | 82.2% |
| monitor | 73 | 2.2 | 27.4% | 2.7% | 82.2% |
| psychologist | 67 | 2.4 | 20.9% | 9.0% | 83.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 147 | 0.0% | 53.1% |
| nightwatch | 145 | 0.0% | 64.1% |
| dowser | 137 | 0.0% | 66.4% |
| confessor | 133 | 0.0% | 65.4% |
| medium | 130 | 0.0% | 31.5% |
| lamplighter | 128 | 0.0% | 70.3% |
| gravedigger | 115 | 0.0% | 53.9% |
| surveyor | 113 | 0.0% | 52.2% |
| rumormonger | 108 | 0.0% | 44.4% |
| clerk | 104 | 0.0% | 51.0% |
| archivist | 99 | 0.0% | 63.6% |
| chronicler | 79 | 0.0% | 53.2% |
| magistrate | 78 | 0.0% | 65.4% |
| seer | 77 | 0.0% | 35.1% |
| psychologist | 77 | 0.0% | 54.5% |
| executor | 76 | 0.0% | 44.7% |
| augur | 67 | 0.0% | 58.2% |
| monitor | 63 | 0.0% | 41.3% |
| warden | 18 | 0.0% | 55.6% |
| martyr | 17 | 0.0% | 17.6% |
| veteran | 15 | 0.0% | 46.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 70.3% | 781 | 56.2% | +14.1 (+7.1 to +21.1) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 238 | 50.0% | 762 | 31.5% | +18.5 (+11.3 to +25.7) **\*** |
| martyr | 88 | 25.0% | 912 | 37.0% | -12.0 (-21.5 to -2.4) **\*** |
| medium | 188 | 27.7% | 812 | 37.8% | -10.1 (-17.4 to -2.9) **\*** |
| dowser | 286 | 42.0% | 714 | 33.5% | +8.5 (+1.8 to +15.2) **\*** |
| gravedigger | 283 | 30.7% | 717 | 37.9% | -7.2 (-13.6 to -0.8) **\*** |
| magistrate | 73 | 42.5% | 927 | 35.4% | +7.1 (-4.7 to +18.8) |
| executor | 87 | 29.9% | 913 | 36.5% | -6.6 (-16.7 to +3.5) |
| monitor | 73 | 30.1% | 927 | 36.4% | -6.2 (-17.2 to +4.8) |
| warden | 229 | 40.6% | 771 | 34.5% | +6.1 (-1.1 to +13.3) |
| augur | 193 | 31.6% | 807 | 36.9% | -5.3 (-12.7 to +2.0) |
| rumormonger | 504 | 34.1% | 496 | 37.7% | -3.6 (-9.5 to +2.4) |
| registrar | 270 | 33.3% | 730 | 36.8% | -3.5 (-10.1 to +3.1) |
| surveyor | 508 | 37.4% | 492 | 34.3% | +3.1 (-2.9 to +9.0) |
| sexton | 74 | 33.8% | 926 | 36.1% | -2.3 (-13.5 to +8.9) |
| veteran | 73 | 34.2% | 927 | 36.0% | -1.8 (-13.1 to +9.5) |
| archivist | 548 | 35.2% | 452 | 36.7% | -1.5 (-7.5 to +4.5) |
| confessor | 224 | 37.1% | 776 | 35.6% | +1.5 (-5.7 to +8.7) |
| chronicler | 76 | 36.8% | 924 | 35.8% | +1.0 (-10.3 to +12.3) |
| clerk | 545 | 36.3% | 455 | 35.4% | +0.9 (-5.0 to +6.9) |
| psychologist | 67 | 35.8% | 933 | 35.9% | -0.1 (-12.0 to +11.8) |
| lamplighter | 203 | 36.0% | 797 | 35.9% | +0.1 (-7.3 to +7.5) |
| seer | 170 | 35.9% | 830 | 35.9% | -0.0 (-7.9 to +7.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 50.7% | 781 | 31.8% | +18.9 (+11.5 to +26.3) **\*** |
| poisoner | 325 | 29.2% | 675 | 39.1% | -9.9 (-16.0 to -3.7) **\*** |
| revenant | 221 | 28.5% | 779 | 38.0% | -9.5 (-16.3 to -2.6) **\*** |
| scion | 235 | 38.3% | 765 | 35.2% | +3.1 (-3.9 to +10.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 24.1% | 788 | 39.1% | -15.0 (-21.7 to -8.3) **\*** |
| lovers | 208 | 40.9% | 792 | 34.6% | +6.3 (-1.2 to +13.7) |
| muddler | 199 | 39.2% | 801 | 35.1% | +4.1 (-3.4 to +11.7) |
| sleepwalker | 186 | 38.7% | 814 | 35.3% | +3.5 (-4.3 to +11.2) |
| marked | 195 | 37.4% | 805 | 35.5% | +1.9 (-5.6 to +9.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 39.5% | 957 | 35.7% | +3.8 (-11.1 to +18.7) |
| 2 night-walkers | 636 | 34.6% | 364 | 38.2% | -3.6 (-9.8 to +2.6) |
| 3 night-walkers | 321 | 38.0% | 679 | 34.9% | +3.1 (-3.3 to +9.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 60.2% | 19.9% | 94.5% |
| clerk | 545 | 2.6 | 23.7% | 22.9% | 91.2% |
| surveyor | 508 | 2.6 | 26.0% | 22.0% | 91.7% |
| rumormonger | 504 | 2.7 | 22.0% | 28.4% | 94.6% |
| dowser | 286 | 1.9 | 54.9% | 10.1% | 85.7% |
| gravedigger | 283 | 2.2 | 40.6% | 20.8% | 89.0% |
| registrar | 270 | 2.3 | 43.3% | 7.4% | 80.7% |
| nightwatch | 238 | 2.2 | 42.4% | 8.4% | 86.1% |
| warden | 229 | 2.6 | 22.3% | 15.7% | 81.2% |
| confessor | 224 | 2.4 | 32.6% | 13.8% | 84.8% |
| lamplighter | 203 | 2.6 | 23.6% | 12.3% | 86.2% |
| augur | 193 | 2.6 | 32.6% | 20.2% | 83.9% |
| medium | 188 | 2.3 | 36.7% | 14.9% | 80.9% |
| seer | 170 | 1.9 | 56.5% | 9.4% | 84.1% |
| martyr | 88 | 2.8 | 18.2% | 20.5% | 86.4% |
| executor | 87 | 2.6 | 35.6% | 17.2% | 83.9% |
| chronicler | 76 | 2.5 | 27.6% | 15.8% | 85.5% |
| sexton | 74 | 2.7 | 14.9% | 31.1% | 75.7% |
| magistrate | 73 | 2.4 | 28.8% | 12.3% | 89.0% |
| monitor | 73 | 2.4 | 37.0% | 4.1% | 79.5% |
| veteran | 73 | 3.2 | 9.6% | 30.1% | 91.8% |
| psychologist | 67 | 2.5 | 28.4% | 19.4% | 85.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 147 | 0.0% | 49.7% |
| nightwatch | 143 | 0.0% | 20.3% |
| dowser | 140 | 0.0% | 46.4% |
| confessor | 133 | 0.0% | 37.6% |
| medium | 132 | 0.0% | 26.5% |
| lamplighter | 131 | 0.0% | 35.1% |
| gravedigger | 120 | 0.0% | 43.3% |
| surveyor | 113 | 0.0% | 37.2% |
| rumormonger | 109 | 0.0% | 40.4% |
| clerk | 105 | 0.0% | 44.8% |
| archivist | 101 | 0.0% | 56.4% |
| executor | 78 | 0.0% | 32.1% |
| magistrate | 77 | 0.0% | 36.4% |
| psychologist | 77 | 0.0% | 50.6% |
| chronicler | 76 | 0.0% | 48.7% |
| seer | 76 | 0.0% | 27.6% |
| augur | 74 | 0.0% | 43.2% |
| monitor | 64 | 0.0% | 21.9% |
| warden | 18 | 0.0% | 22.2% |
| martyr | 17 | 0.0% | 5.9% |
| veteran | 15 | 0.0% | 6.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 50.7% | 781 | 31.8% | +18.9 (+11.5 to +26.3) |
| demon + nightwatch | 238 | 50.0% | 762 | 31.5% | +18.5 (+11.3 to +25.7) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 63.1% | 604 | 50.0% | +13.1 (+6.9 to +19.3) **\*** |
| martyr | 156 | 46.2% | 844 | 56.9% | -10.7 (-19.2 to -2.2) **\*** |
| chronicler | 137 | 46.0% | 863 | 56.7% | -10.7 (-19.7 to -1.7) **\*** |
| confessor | 389 | 49.1% | 611 | 59.1% | -10.0 (-16.3 to -3.7) **\*** |
| magistrate | 135 | 62.2% | 865 | 54.1% | +8.1 (-0.7 to +16.9) |
| registrar | 377 | 59.7% | 623 | 52.5% | +7.2 (+0.9 to +13.5) **\*** |
| executor | 147 | 49.7% | 853 | 56.2% | -6.5 (-15.2 to +2.2) |
| lamplighter | 382 | 58.4% | 618 | 53.2% | +5.1 (-1.2 to +11.5) |
| medium | 384 | 58.3% | 616 | 53.2% | +5.1 (-1.2 to +11.4) |
| augur | 231 | 51.5% | 769 | 56.3% | -4.8 (-12.1 to +2.5) |
| dowser | 372 | 58.1% | 628 | 53.5% | +4.6 (-1.8 to +10.9) |
| rumormonger | 590 | 53.6% | 410 | 57.6% | -4.0 (-10.3 to +2.3) |
| clerk | 581 | 56.8% | 419 | 53.0% | +3.8 (-2.4 to +10.1) |
| monitor | 144 | 52.1% | 856 | 55.7% | -3.6 (-12.5 to +5.2) |
| warden | 377 | 53.1% | 623 | 56.5% | -3.5 (-9.8 to +2.9) |
| archivist | 563 | 53.8% | 437 | 57.0% | -3.2 (-9.4 to +3.0) |
| seer | 225 | 53.3% | 775 | 55.7% | -2.4 (-9.8 to +5.0) |
| surveyor | 588 | 54.6% | 412 | 56.1% | -1.5 (-7.7 to +4.8) |
| gravedigger | 358 | 56.1% | 642 | 54.7% | +1.5 (-5.0 to +7.9) |
| psychologist | 148 | 54.1% | 852 | 55.4% | -1.3 (-10.0 to +7.4) |
| sexton | 148 | 56.1% | 852 | 55.0% | +1.0 (-7.6 to +9.7) |
| veteran | 172 | 55.2% | 828 | 55.2% | +0.0 (-8.1 to +8.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 63.9% | 559 | 48.3% | +15.6 (+9.5 to +21.7) **\*** |
| poisoner | 620 | 52.1% | 380 | 60.3% | -8.2 (-14.5 to -1.9) **\*** |
| scion | 467 | 51.4% | 533 | 58.5% | -7.1 (-13.3 to -1.0) **\*** |
| revenant | 472 | 54.9% | 528 | 55.5% | -0.6 (-6.8 to +5.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 45.4% | 784 | 57.9% | -12.5 (-20.0 to -5.1) **\*** |
| lovers | 195 | 62.6% | 805 | 53.4% | +9.1 (+1.5 to +16.8) **\*** |
| muddler | 191 | 58.6% | 809 | 54.4% | +4.3 (-3.5 to +12.0) |
| marked | 191 | 58.6% | 809 | 54.4% | +4.3 (-3.5 to +12.0) |
| sleepwalker | 207 | 52.2% | 793 | 56.0% | -3.8 (-11.4 to +3.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 366 | 57.1% | 634 | 54.1% | +3.0 (-3.4 to +9.4) |
| 3 night-walkers | 543 | 54.1% | 457 | 56.5% | -2.3 (-8.5 to +3.9) |
| 5 night-walkers | 91 | 53.8% | 909 | 55.3% | -1.5 (-12.2 to +9.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.3 | 12.7% | 19.0% | 95.6% |
| surveyor | 588 | 3.2 | 15.0% | 16.0% | 95.6% |
| clerk | 581 | 3.3 | 13.3% | 17.6% | 94.8% |
| archivist | 563 | 2.0 | 54.5% | 11.4% | 92.5% |
| nightwatch | 396 | 2.3 | 32.1% | 18.4% | 87.1% |
| confessor | 389 | 2.7 | 20.8% | 27.5% | 89.2% |
| medium | 384 | 2.8 | 20.3% | 10.9% | 84.1% |
| lamplighter | 382 | 2.8 | 20.4% | 13.6% | 90.6% |
| registrar | 377 | 2.7 | 26.8% | 9.0% | 84.1% |
| warden | 377 | 3.2 | 15.4% | 25.5% | 86.5% |
| dowser | 372 | 2.1 | 50.8% | 8.6% | 93.0% |
| gravedigger | 358 | 2.6 | 30.2% | 16.5% | 92.7% |
| augur | 231 | 2.9 | 23.8% | 15.2% | 82.7% |
| seer | 225 | 2.2 | 41.3% | 12.9% | 87.1% |
| veteran | 172 | 4.0 | 5.8% | 24.4% | 89.0% |
| martyr | 156 | 3.7 | 7.1% | 12.8% | 92.9% |
| sexton | 148 | 3.5 | 8.1% | 24.3% | 80.4% |
| psychologist | 148 | 2.9 | 20.9% | 16.9% | 85.8% |
| executor | 147 | 3.2 | 17.7% | 13.6% | 91.2% |
| monitor | 144 | 3.0 | 20.8% | 6.2% | 79.2% |
| chronicler | 137 | 3.1 | 13.9% | 13.9% | 89.1% |
| magistrate | 135 | 2.9 | 20.0% | 10.4% | 82.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 210 | 0.0% | 46.2% |
| archivist | 198 | 0.0% | 55.6% |
| dowser | 198 | 0.0% | 70.2% |
| gravedigger | 192 | 0.0% | 56.2% |
| clerk | 190 | 0.0% | 51.6% |
| confessor | 183 | 0.0% | 71.6% |
| rumormonger | 182 | 0.0% | 54.9% |
| surveyor | 176 | 0.0% | 40.9% |
| medium | 168 | 0.0% | 26.8% |
| lamplighter | 166 | 0.0% | 68.1% |
| nightwatch | 164 | 0.0% | 67.7% |
| magistrate | 127 | 0.0% | 59.8% |
| augur | 117 | 0.0% | 59.0% |
| chronicler | 108 | 0.0% | 52.8% |
| monitor | 108 | 0.0% | 37.0% |
| seer | 106 | 0.0% | 47.2% |
| psychologist | 106 | 0.0% | 46.2% |
| executor | 92 | 0.0% | 40.2% |
| sexton | 32 | 0.0% | 46.9% |
| veteran | 30 | 0.0% | 26.7% |
| martyr | 21 | 0.0% | 42.9% |
| warden | 19 | 0.0% | 52.6% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 63.9% | 559 | 48.3% | +15.6 (+9.5 to +21.7) |
| poisoner + scion | 215 | 43.3% | 785 | 58.5% | -15.2 (-22.7 to -7.7) |
| archivist + breathstealer | 243 | 65.8% | 757 | 51.8% | +14.1 (+7.1 to +21.0) |
| confessor + poisoner | 220 | 44.5% | 780 | 58.2% | -13.7 (-21.1 to -6.2) |
| demon + nightwatch | 396 | 63.1% | 604 | 50.0% | +13.1 (+6.9 to +19.3) |
| breathstealer + clerk | 253 | 64.4% | 747 | 52.1% | +12.4 (+5.5 to +19.3) |
| rumormonger + scion | 276 | 46.7% | 724 | 58.4% | -11.7 (-18.6 to -4.8) |
| nightwatch + rumormonger | 227 | 63.9% | 773 | 52.7% | +11.2 (+4.1 to +18.4) |
| nightwatch + poisoner | 211 | 63.5% | 789 | 53.0% | +10.5 (+3.2 to +17.9) |
| confessor + rumormonger | 221 | 47.1% | 779 | 57.5% | -10.5 (-17.9 to -3.0) |
| clerk + nightwatch | 225 | 63.1% | 775 | 52.9% | +10.2 (+3.0 to +17.4) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 49.5% | 604 | 32.1% | +17.4 (+11.2 to +23.5) **\*** |
| martyr | 156 | 29.5% | 844 | 40.8% | -11.3 (-19.2 to -3.4) **\*** |
| veteran | 172 | 30.2% | 828 | 40.8% | -10.6 (-18.2 to -3.0) **\*** |
| dowser | 372 | 44.4% | 628 | 35.8% | +8.5 (+2.2 to +14.8) **\*** |
| augur | 231 | 32.5% | 769 | 41.0% | -8.5 (-15.5 to -1.5) **\*** |
| psychologist | 148 | 45.3% | 852 | 37.9% | +7.4 (-1.3 to +16.0) |
| medium | 384 | 34.9% | 616 | 41.6% | -6.7 (-12.8 to -0.5) **\*** |
| magistrate | 135 | 33.3% | 865 | 39.9% | -6.6 (-15.1 to +2.0) |
| executor | 147 | 34.0% | 853 | 39.9% | -5.8 (-14.2 to +2.5) |
| chronicler | 137 | 34.3% | 863 | 39.7% | -5.4 (-14.0 to +3.2) |
| seer | 225 | 42.7% | 775 | 37.9% | +4.7 (-2.6 to +12.0) |
| rumormonger | 590 | 37.1% | 410 | 41.7% | -4.6 (-10.8 to +1.6) |
| sexton | 148 | 42.6% | 852 | 38.4% | +4.2 (-4.4 to +12.8) |
| lamplighter | 382 | 41.1% | 618 | 37.7% | +3.4 (-2.8 to +9.6) |
| surveyor | 588 | 40.0% | 412 | 37.6% | +2.3 (-3.8 to +8.5) |
| archivist | 563 | 40.0% | 437 | 37.8% | +2.2 (-3.9 to +8.3) |
| clerk | 581 | 38.4% | 419 | 39.9% | -1.5 (-7.6 to +4.7) |
| gravedigger | 358 | 38.3% | 642 | 39.4% | -1.1 (-7.4 to +5.2) |
| monitor | 144 | 38.2% | 856 | 39.1% | -0.9 (-9.5 to +7.6) |
| confessor | 389 | 38.6% | 611 | 39.3% | -0.7 (-6.9 to +5.5) |
| registrar | 377 | 38.7% | 623 | 39.2% | -0.4 (-6.7 to +5.8) |
| warden | 377 | 39.0% | 623 | 39.0% | -0.0 (-6.3 to +6.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 50.8% | 559 | 29.7% | +21.1 (+15.1 to +27.1) **\*** |
| poisoner | 620 | 34.8% | 380 | 45.8% | -11.0 (-17.2 to -4.7) **\*** |
| scion | 467 | 35.8% | 533 | 41.8% | -6.1 (-12.1 to -0.0) **\*** |
| revenant | 472 | 36.7% | 528 | 41.1% | -4.4 (-10.5 to +1.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 30.1% | 784 | 41.5% | -11.4 (-18.4 to -4.3) **\*** |
| muddler | 191 | 44.5% | 809 | 37.7% | +6.8 (-1.0 to +14.6) |
| lovers | 195 | 44.1% | 805 | 37.8% | +6.3 (-1.4 to +14.1) |
| sleepwalker | 207 | 37.2% | 793 | 39.5% | -2.3 (-9.7 to +5.1) |
| marked | 191 | 40.3% | 809 | 38.7% | +1.6 (-6.1 to +9.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 42.9% | 909 | 38.6% | +4.2 (-6.4 to +14.9) |
| 3 night-walkers | 543 | 38.5% | 457 | 39.6% | -1.1 (-7.2 to +5.0) |
| 4 night-walkers | 366 | 38.8% | 634 | 39.1% | -0.3 (-6.6 to +6.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.5 | 15.8% | 22.5% | 94.1% |
| surveyor | 588 | 3.3 | 17.0% | 22.6% | 94.4% |
| clerk | 581 | 3.4 | 14.6% | 24.6% | 95.2% |
| archivist | 563 | 2.2 | 50.3% | 15.8% | 95.0% |
| nightwatch | 396 | 2.6 | 32.1% | 21.7% | 91.4% |
| confessor | 389 | 2.7 | 27.5% | 19.8% | 92.8% |
| medium | 384 | 3.1 | 20.1% | 14.8% | 89.6% |
| lamplighter | 382 | 3.1 | 19.4% | 21.2% | 93.2% |
| warden | 377 | 3.4 | 17.0% | 27.3% | 88.3% |
| registrar | 377 | 2.8 | 31.0% | 10.6% | 90.2% |
| dowser | 372 | 2.2 | 54.0% | 8.1% | 93.0% |
| gravedigger | 358 | 2.5 | 34.4% | 14.2% | 88.8% |
| augur | 231 | 3.1 | 25.1% | 20.8% | 90.0% |
| seer | 225 | 2.3 | 43.6% | 12.4% | 88.0% |
| veteran | 172 | 4.3 | 3.5% | 41.3% | 95.3% |
| martyr | 156 | 4.0 | 9.0% | 21.8% | 92.9% |
| sexton | 148 | 3.7 | 5.4% | 28.4% | 83.1% |
| psychologist | 148 | 3.1 | 16.2% | 16.9% | 86.5% |
| executor | 147 | 3.3 | 17.0% | 17.7% | 88.4% |
| monitor | 144 | 3.3 | 18.1% | 6.2% | 92.4% |
| chronicler | 137 | 3.0 | 21.9% | 15.3% | 91.2% |
| magistrate | 135 | 2.6 | 30.4% | 11.1% | 88.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 214 | 0.0% | 45.3% |
| dowser | 203 | 0.0% | 52.7% |
| archivist | 198 | 0.0% | 50.5% |
| gravedigger | 198 | 0.0% | 57.1% |
| clerk | 190 | 0.0% | 45.8% |
| rumormonger | 183 | 0.0% | 41.5% |
| confessor | 181 | 0.0% | 50.3% |
| surveyor | 175 | 0.0% | 46.9% |
| lamplighter | 167 | 0.0% | 44.9% |
| medium | 167 | 0.0% | 30.5% |
| nightwatch | 167 | 0.0% | 40.7% |
| magistrate | 128 | 0.0% | 46.9% |
| augur | 121 | 0.0% | 43.0% |
| psychologist | 110 | 0.0% | 45.5% |
| chronicler | 109 | 0.0% | 44.0% |
| monitor | 108 | 0.0% | 22.2% |
| seer | 107 | 0.0% | 38.3% |
| executor | 98 | 0.0% | 40.8% |
| veteran | 32 | 0.0% | 34.4% |
| sexton | 32 | 0.0% | 50.0% |
| martyr | 20 | 0.0% | 35.0% |
| warden | 19 | 0.0% | 42.1% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 50.8% | 559 | 29.7% | +21.1 (+15.1 to +27.1) |
| breathstealer + clerk | 253 | 52.6% | 747 | 34.4% | +18.2 (+11.1 to +25.2) |
| archivist + breathstealer | 243 | 52.3% | 757 | 34.7% | +17.5 (+10.4 to +24.7) |
| demon + nightwatch | 396 | 49.5% | 604 | 32.1% | +17.4 (+11.2 to +23.5) |
| breathstealer + surveyor | 261 | 51.0% | 739 | 34.8% | +16.2 (+9.2 to +23.2) |
| nightwatch + surveyor | 234 | 51.3% | 766 | 35.2% | +16.0 (+8.8 to +23.3) |
| archivist + nightwatch | 225 | 51.1% | 775 | 35.5% | +15.6 (+8.3 to +23.0) |
| poisoner + scion | 215 | 27.9% | 785 | 42.0% | -14.1 (-21.1 to -7.2) |
| poisoner + revenant | 214 | 28.0% | 786 | 42.0% | -13.9 (-20.9 to -7.0) |
| nightwatch + rumormonger | 227 | 48.5% | 773 | 36.2% | +12.2 (+4.9 to +19.6) |
| breathstealer + rumormonger | 264 | 47.7% | 736 | 35.9% | +11.9 (+4.9 to +18.8) |
| clerk + nightwatch | 225 | 47.6% | 775 | 36.5% | +11.0 (+3.7 to +18.4) |
| demon + poisoner | 620 | 34.8% | 380 | 45.8% | -11.0 (-17.2 to -4.7) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 1000 | 338 (33.8%) | 104 (10.4%) | 255 | 303 |
| 10 | 10 NPCs, bot insight 1.0 | 1000 | 294 (29.4%) | 132 (13.2%) | 258 | 316 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 10 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 50.0 | 119.8 | 348.2 |
| 7 NPCs, passive | 5.0 | 7.8 | 18.7 |
| 10 NPCs, bot insight 1.0 | 286.1 | 540.7 | 1228.3 |
| 10 NPCs, passive | 31.9 | 59.2 | 175.2 |

Slowest seeds: 100234 (10 NPCs bot, 1228 s), 100217 (10 NPCs bot, 1225 s), 100316 (10 NPCs bot, 1071 s), 100688 (10 NPCs bot, 998 s), 100258 (10 NPCs bot, 997 s), 100868 (10 NPCs bot, 994 s), 100286 (10 NPCs bot, 956 s), 100313 (10 NPCs bot, 949 s), 100654 (10 NPCs bot, 926 s), 100684 (10 NPCs bot, 906 s), 100502 (10 NPCs bot, 887 s), 100911 (10 NPCs bot, 881 s), 100588 (10 NPCs bot, 865 s), 100272 (10 NPCs bot, 849 s), 100650 (10 NPCs bot, 816 s), 100546 (10 NPCs bot, 804 s), 100644 (10 NPCs bot, 797 s), 100591 (10 NPCs bot, 796 s), 100549 (10 NPCs bot, 792 s), 100640 (10 NPCs bot, 789 s)

