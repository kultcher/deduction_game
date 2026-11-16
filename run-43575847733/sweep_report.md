# Balance sweep report

Records: 3999 games, 1 failed, 0 stuck (left out of the rates). Commit(s): `b4e382e54e`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 65.3% (62.3%–68.2%) | 3.03 | 0.64 | 1.21 | 2.23 | 11.4% | 0.26 |
| 7 NPCs, passive | 1000 | 42.2% (39.2%–45.3%) | 3.44 | 0.82 | 0.88 | 2.42 | 3.9% | 0.23 |
| 10 NPCs, bot insight 1.0 | 999 | 63.0% (59.9%–65.9%) | 4.16 | 0.98 | 1.75 | 2.42 | 9.6% | 0.45 |
| 10 NPCs, passive | 1000 | 39.5% (36.5%–42.6%) | 4.58 | 1.32 | 1.41 | 2.57 | 4.0% | 0.53 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.88 | 21.2% | 28.3% | 2.01 | 15.4% | 14.2% | 13.4% |
| 7 NPCs, passive | 6.29 | 17.8% | 39.2% | 2.89 | 25.9% | 24.6% | 23.0% |
| 10 NPCs, bot insight 1.0 | 9.01 | 14.1% | 26.8% | 3.87 | 14.5% | 13.7% | 12.7% |
| 10 NPCs, passive | 10.74 | 10.8% | 32.1% | 5.07 | 25.8% | 25.2% | 21.8% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 653 (65.3%)
- Only two townsfolk remain and the demon still walks among them.: 347 (34.7%)
- Demon evidence on the board: 97.7% of games; good win rate 64.9% of 977
- Demon evidence reachable: 79.3% of games; good win rate 61.8% of 793
- Neither: 1.4% of games; good win rate 100.0% of 14
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=1000)

- Only two townsfolk remain and the demon still walks among them.: 577 (57.7%)
- The demon's host was executed.: 422 (42.2%)
- Time ran out: the demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 62.7% of games; good win rate 50.7% of 627
- Demon evidence reachable: 99.8% of games; good win rate 42.1% of 998
- Neither: 0.2% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=999)

- The demon's host was executed.: 629 (63.0%)
- Only two townsfolk remain and the demon still walks among them.: 246 (24.6%)
- No good soul remains.: 121 (12.1%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 99.2% of games; good win rate 62.7% of 991
- Demon evidence reachable: 88.0% of games; good win rate 60.2% of 879
- Neither: 0.6% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=1000)

- The demon's host was executed.: 395 (39.5%)
- Only two townsfolk remain and the demon still walks among them.: 310 (31.0%)
- No good soul remains.: 292 (29.2%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 76.8% of games; good win rate 42.7% of 768
- Demon evidence reachable: 100.0% of games; good win rate 39.5% of 1000
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| dowser | 286 | 73.4% | 714 | 62.0% | +11.4 (+5.1 to +17.6) **\*** |
| sexton | 74 | 55.4% | 926 | 66.1% | -10.7 (-22.4 to +1.0) |
| confessor | 224 | 58.0% | 776 | 67.4% | -9.4 (-16.6 to -2.1) **\*** |
| veteran | 73 | 74.0% | 927 | 64.6% | +9.4 (-1.2 to +19.9) |
| warden | 229 | 72.1% | 771 | 63.3% | +8.8 (+2.0 to +15.5) **\*** |
| nightwatch | 238 | 71.8% | 762 | 63.3% | +8.6 (+1.9 to +15.3) **\*** |
| martyr | 88 | 59.1% | 912 | 65.9% | -6.8 (-17.5 to +3.9) |
| gravedigger | 283 | 60.4% | 717 | 67.2% | -6.8 (-13.5 to -0.1) **\*** |
| surveyor | 508 | 68.3% | 492 | 62.2% | +6.1 (+0.2 to +12.0) **\*** |
| executor | 87 | 59.8% | 913 | 65.8% | -6.1 (-16.8 to +4.7) |
| monitor | 73 | 60.3% | 927 | 65.7% | -5.4 (-17.1 to +6.2) |
| psychologist | 67 | 70.1% | 933 | 65.0% | +5.2 (-6.2 to +16.6) |
| rumormonger | 504 | 62.9% | 496 | 67.7% | -4.8 (-10.7 to +1.0) |
| archivist | 548 | 63.3% | 452 | 67.7% | -4.4 (-10.3 to +1.5) |
| augur | 193 | 62.7% | 807 | 65.9% | -3.2 (-10.8 to +4.3) |
| lamplighter | 203 | 63.1% | 797 | 65.9% | -2.8 (-10.2 to +4.6) |
| chronicler | 76 | 63.2% | 924 | 65.5% | -2.3 (-13.6 to +9.0) |
| seer | 170 | 67.1% | 830 | 64.9% | +2.1 (-5.7 to +9.9) |
| clerk | 545 | 66.2% | 455 | 64.2% | +2.1 (-3.9 to +8.0) |
| medium | 188 | 64.4% | 812 | 65.5% | -1.2 (-8.7 to +6.4) |
| magistrate | 73 | 64.4% | 927 | 65.4% | -1.0 (-12.4 to +10.4) |
| registrar | 270 | 65.6% | 730 | 65.2% | +0.4 (-6.3 to +7.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 78.1% | 781 | 61.7% | +16.4 (+9.9 to +22.8) **\*** |
| revenant | 221 | 57.9% | 779 | 67.4% | -9.5 (-16.8 to -2.2) **\*** |
| poisoner | 325 | 60.6% | 675 | 67.6% | -6.9 (-13.3 to -0.6) **\*** |
| scion | 235 | 66.8% | 765 | 64.8% | +2.0 (-4.9 to +8.9) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 59.4% | 788 | 66.9% | -7.4 (-14.8 to -0.1) **\*** |
| lovers | 208 | 67.8% | 792 | 64.6% | +3.1 (-4.0 to +10.3) |
| muddler | 199 | 67.3% | 801 | 64.8% | +2.5 (-4.8 to +9.9) |
| marked | 195 | 67.2% | 805 | 64.8% | +2.3 (-5.0 to +9.7) |
| sleepwalker | 186 | 65.1% | 814 | 65.4% | -0.3 (-7.9 to +7.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 321 | 62.0% | 679 | 66.9% | -4.9 (-11.3 to +1.5) |
| 4 night-walkers | 43 | 69.8% | 957 | 65.1% | +4.7 (-9.4 to +18.7) |
| 2 night-walkers | 636 | 66.7% | 364 | 62.9% | +3.8 (-2.4 to +9.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.5 | 53.8% | 15.5% | 94.9% |
| clerk | 545 | 2.1 | 20.7% | 11.9% | 91.4% |
| surveyor | 508 | 2.1 | 23.8% | 9.8% | 92.5% |
| rumormonger | 504 | 2.1 | 21.6% | 13.1% | 91.3% |
| dowser | 286 | 1.8 | 46.5% | 7.0% | 86.4% |
| gravedigger | 283 | 2.0 | 40.6% | 12.0% | 84.5% |
| registrar | 270 | 2.0 | 40.4% | 5.9% | 74.4% |
| nightwatch | 238 | 1.9 | 34.0% | 14.7% | 83.2% |
| warden | 229 | 2.1 | 22.3% | 20.5% | 77.7% |
| confessor | 224 | 2.0 | 26.3% | 25.9% | 84.4% |
| lamplighter | 203 | 2.1 | 21.2% | 14.3% | 85.7% |
| augur | 193 | 2.1 | 28.0% | 13.5% | 79.3% |
| medium | 188 | 2.1 | 31.4% | 8.5% | 73.9% |
| seer | 170 | 1.9 | 48.8% | 8.2% | 84.7% |
| martyr | 88 | 2.4 | 17.0% | 13.6% | 87.5% |
| executor | 87 | 2.3 | 27.6% | 6.9% | 78.2% |
| chronicler | 76 | 2.1 | 31.6% | 15.8% | 73.7% |
| sexton | 74 | 2.3 | 16.2% | 10.8% | 68.9% |
| veteran | 73 | 2.8 | 4.1% | 12.3% | 83.6% |
| magistrate | 73 | 2.0 | 28.8% | 5.5% | 86.3% |
| monitor | 73 | 2.1 | 32.9% | 9.6% | 80.8% |
| psychologist | 67 | 2.2 | 19.4% | 20.9% | 77.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 147 | 0.0% | 56.5% |
| nightwatch | 142 | 0.0% | 62.7% |
| dowser | 139 | 0.0% | 62.6% |
| confessor | 133 | 0.0% | 68.4% |
| lamplighter | 131 | 0.0% | 77.1% |
| medium | 126 | 0.0% | 55.6% |
| gravedigger | 116 | 0.0% | 62.1% |
| surveyor | 113 | 0.0% | 62.8% |
| rumormonger | 109 | 0.0% | 65.1% |
| clerk | 104 | 0.0% | 58.7% |
| archivist | 99 | 0.0% | 73.7% |
| magistrate | 80 | 0.0% | 61.3% |
| seer | 79 | 0.0% | 48.1% |
| chronicler | 78 | 0.0% | 52.6% |
| psychologist | 78 | 0.0% | 65.4% |
| executor | 77 | 0.0% | 46.8% |
| augur | 72 | 0.0% | 58.3% |
| monitor | 64 | 0.0% | 43.8% |
| martyr | 18 | 0.0% | 50.0% |
| warden | 18 | 0.0% | 61.1% |
| veteran | 16 | 0.0% | 31.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 78.1% | 781 | 61.7% | +16.4 (+9.9 to +22.8) |
| demon + dowser | 286 | 73.4% | 714 | 62.0% | +11.4 (+5.1 to +17.6) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 238 | 53.8% | 762 | 38.6% | +15.2 (+8.0 to +22.4) **\*** |
| sexton | 74 | 28.4% | 926 | 43.3% | -14.9 (-25.7 to -4.2) **\*** |
| gravedigger | 283 | 32.2% | 717 | 46.2% | -14.0 (-20.6 to -7.5) **\*** |
| psychologist | 67 | 31.3% | 933 | 43.0% | -11.6 (-23.2 to -0.1) **\*** |
| registrar | 270 | 49.6% | 730 | 39.5% | +10.2 (+3.2 to +17.1) **\*** |
| dowser | 286 | 49.0% | 714 | 39.5% | +9.5 (+2.6 to +16.3) **\*** |
| medium | 188 | 34.6% | 812 | 44.0% | -9.4 (-17.0 to -1.8) **\*** |
| monitor | 73 | 34.2% | 927 | 42.8% | -8.6 (-19.9 to +2.8) |
| warden | 229 | 48.5% | 771 | 40.3% | +8.1 (+0.8 to +15.5) **\*** |
| augur | 193 | 35.8% | 807 | 43.7% | -8.0 (-15.6 to -0.4) **\*** |
| magistrate | 73 | 49.3% | 927 | 41.6% | +7.7 (-4.2 to +19.6) |
| martyr | 88 | 35.2% | 912 | 42.9% | -7.6 (-18.1 to +2.8) |
| archivist | 548 | 39.8% | 452 | 45.1% | -5.4 (-11.5 to +0.8) |
| surveyor | 508 | 44.3% | 492 | 40.0% | +4.3 (-1.9 to +10.4) |
| veteran | 73 | 38.4% | 927 | 42.5% | -4.1 (-15.7 to +7.5) |
| clerk | 545 | 43.5% | 455 | 40.7% | +2.8 (-3.3 to +9.0) |
| rumormonger | 504 | 40.9% | 496 | 43.5% | -2.7 (-8.8 to +3.4) |
| lamplighter | 203 | 43.8% | 797 | 41.8% | +2.1 (-5.6 to +9.7) |
| seer | 170 | 43.5% | 830 | 41.9% | +1.6 (-6.6 to +9.8) |
| confessor | 224 | 41.1% | 776 | 42.5% | -1.5 (-8.8 to +5.9) |
| executor | 87 | 42.5% | 913 | 42.2% | +0.4 (-10.5 to +11.2) |
| chronicler | 76 | 42.1% | 924 | 42.2% | -0.1 (-11.7 to +11.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 62.6% | 781 | 36.5% | +26.1 (+18.8 to +33.3) **\*** |
| poisoner | 325 | 32.3% | 675 | 47.0% | -14.7 (-21.0 to -8.3) **\*** |
| revenant | 221 | 35.3% | 779 | 44.2% | -8.9 (-16.1 to -1.7) **\*** |
| scion | 235 | 43.4% | 765 | 41.8% | +1.6 (-5.7 to +8.8) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 30.7% | 788 | 45.3% | -14.6 (-21.8 to -7.5) **\*** |
| lovers | 208 | 48.6% | 792 | 40.5% | +8.0 (+0.4 to +15.6) **\*** |
| muddler | 199 | 46.2% | 801 | 41.2% | +5.0 (-2.7 to +12.8) |
| sleepwalker | 186 | 46.2% | 814 | 41.3% | +5.0 (-3.0 to +12.9) |
| marked | 195 | 40.0% | 805 | 42.7% | -2.7 (-10.4 to +4.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 39.5% | 957 | 42.3% | -2.8 (-17.7 to +12.2) |
| 2 night-walkers | 636 | 42.6% | 364 | 41.5% | +1.1 (-5.2 to +7.5) |
| 3 night-walkers | 321 | 41.7% | 679 | 42.4% | -0.7 (-7.2 to +5.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 59.7% | 18.1% | 93.2% |
| clerk | 545 | 2.5 | 26.1% | 20.9% | 91.2% |
| surveyor | 508 | 2.5 | 25.4% | 20.5% | 94.1% |
| rumormonger | 504 | 2.6 | 21.8% | 21.8% | 95.2% |
| dowser | 286 | 1.9 | 52.1% | 8.0% | 88.8% |
| gravedigger | 283 | 2.2 | 38.9% | 20.1% | 88.3% |
| registrar | 270 | 2.3 | 37.0% | 7.4% | 84.4% |
| nightwatch | 238 | 2.1 | 36.6% | 9.7% | 88.7% |
| warden | 229 | 2.6 | 27.1% | 12.7% | 82.1% |
| confessor | 224 | 2.3 | 37.1% | 11.2% | 84.8% |
| lamplighter | 203 | 2.4 | 29.6% | 10.3% | 86.2% |
| augur | 193 | 2.6 | 30.1% | 20.7% | 86.0% |
| medium | 188 | 2.3 | 35.6% | 13.3% | 83.0% |
| seer | 170 | 2.0 | 51.2% | 8.8% | 82.4% |
| martyr | 88 | 2.7 | 14.8% | 18.2% | 86.4% |
| executor | 87 | 2.4 | 33.3% | 12.6% | 82.8% |
| chronicler | 76 | 2.3 | 31.6% | 22.4% | 82.9% |
| sexton | 74 | 2.5 | 28.4% | 21.6% | 73.0% |
| magistrate | 73 | 2.4 | 38.4% | 11.0% | 94.5% |
| monitor | 73 | 2.2 | 41.1% | 8.2% | 82.2% |
| veteran | 73 | 3.4 | 5.5% | 34.2% | 90.4% |
| psychologist | 67 | 2.5 | 32.8% | 19.4% | 89.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 147 | 0.0% | 42.2% |
| nightwatch | 143 | 0.0% | 28.0% |
| dowser | 139 | 0.0% | 46.0% |
| confessor | 137 | 0.0% | 46.0% |
| lamplighter | 132 | 0.0% | 34.1% |
| medium | 129 | 0.0% | 39.5% |
| gravedigger | 119 | 0.0% | 57.1% |
| surveyor | 112 | 0.0% | 53.6% |
| rumormonger | 109 | 0.0% | 52.3% |
| clerk | 105 | 0.0% | 52.4% |
| archivist | 101 | 0.0% | 64.4% |
| psychologist | 80 | 0.0% | 58.8% |
| executor | 79 | 0.0% | 41.8% |
| magistrate | 79 | 0.0% | 45.6% |
| chronicler | 77 | 0.0% | 50.6% |
| augur | 75 | 0.0% | 48.0% |
| seer | 74 | 0.0% | 33.8% |
| monitor | 65 | 0.0% | 16.9% |
| martyr | 18 | 0.0% | 22.2% |
| warden | 18 | 0.0% | 38.9% |
| veteran | 15 | 0.0% | 13.3% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 62.6% | 781 | 36.5% | +26.1 (+18.8 to +33.3) |
| demon + nightwatch | 238 | 53.8% | 762 | 38.6% | +15.2 (+8.0 to +22.4) |
| demon + poisoner | 325 | 32.3% | 675 | 47.0% | -14.7 (-21.0 to -8.3) |
| demon + gravedigger | 283 | 32.2% | 717 | 46.2% | -14.0 (-20.6 to -7.5) |
| demon + registrar | 270 | 49.6% | 730 | 39.5% | +10.2 (+3.2 to +17.1) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 389 | 55.8% | 610 | 67.5% | -11.8 (-17.9 to -5.6) **\*** |
| nightwatch | 396 | 69.4% | 603 | 58.7% | +10.7 (+4.7 to +16.7) **\*** |
| chronicler | 136 | 55.9% | 863 | 64.1% | -8.2 (-17.1 to +0.7) |
| monitor | 144 | 69.4% | 855 | 61.9% | +7.6 (-0.6 to +15.8) |
| surveyor | 588 | 60.9% | 411 | 65.9% | -5.1 (-11.1 to +1.0) |
| psychologist | 148 | 59.5% | 851 | 63.6% | -4.1 (-12.7 to +4.4) |
| clerk | 580 | 64.5% | 419 | 60.9% | +3.6 (-2.5 to +9.7) |
| dowser | 371 | 65.2% | 628 | 61.6% | +3.6 (-2.6 to +9.8) |
| lamplighter | 382 | 65.2% | 617 | 61.6% | +3.6 (-2.5 to +9.7) |
| augur | 231 | 60.6% | 768 | 63.7% | -3.1 (-10.2 to +4.1) |
| executor | 147 | 60.5% | 852 | 63.4% | -2.8 (-11.4 to +5.7) |
| veteran | 172 | 65.1% | 827 | 62.5% | +2.6 (-5.2 to +10.5) |
| warden | 376 | 64.4% | 623 | 62.1% | +2.2 (-3.9 to +8.4) |
| martyr | 156 | 64.7% | 843 | 62.6% | +2.1 (-6.1 to +10.3) |
| medium | 383 | 61.9% | 616 | 63.6% | -1.8 (-7.9 to +4.4) |
| sexton | 148 | 64.2% | 851 | 62.7% | +1.4 (-6.9 to +9.8) |
| rumormonger | 589 | 62.5% | 410 | 63.7% | -1.2 (-7.3 to +4.9) |
| gravedigger | 358 | 62.3% | 641 | 63.3% | -1.0 (-7.3 to +5.2) |
| magistrate | 135 | 63.7% | 864 | 62.8% | +0.9 (-7.9 to +9.6) |
| archivist | 562 | 62.6% | 437 | 63.4% | -0.8 (-6.8 to +5.3) |
| seer | 225 | 62.7% | 774 | 63.0% | -0.4 (-7.6 to +6.8) |
| registrar | 377 | 63.1% | 622 | 62.9% | +0.3 (-5.9 to +6.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 440 | 74.8% | 559 | 53.7% | +21.1 (+15.3 to +26.9) **\*** |
| scion | 466 | 55.2% | 533 | 69.8% | -14.6 (-20.6 to -8.7) **\*** |
| poisoner | 620 | 61.1% | 379 | 66.0% | -4.8 (-11.0 to +1.3) |
| revenant | 472 | 62.1% | 527 | 63.8% | -1.7 (-7.7 to +4.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 55.1% | 783 | 65.1% | -10.0 (-17.5 to -2.6) **\*** |
| lovers | 195 | 68.2% | 804 | 61.7% | +6.5 (-0.8 to +13.9) |
| muddler | 191 | 68.1% | 808 | 61.8% | +6.3 (-1.1 to +13.7) |
| sleepwalker | 206 | 59.7% | 793 | 63.8% | -4.1 (-11.6 to +3.4) |
| marked | 191 | 64.9% | 808 | 62.5% | +2.4 (-5.1 to +10.0) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 61.5% | 908 | 63.1% | -1.6 (-12.0 to +8.9) |
| 3 night-walkers | 542 | 63.5% | 457 | 62.4% | +1.1 (-4.9 to +7.1) |
| 4 night-walkers | 366 | 62.6% | 633 | 63.2% | -0.6 (-6.8 to +5.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 589 | 3.2 | 13.4% | 14.1% | 94.9% |
| surveyor | 588 | 2.9 | 18.5% | 16.2% | 93.7% |
| clerk | 580 | 3.1 | 11.6% | 14.1% | 95.7% |
| archivist | 562 | 2.0 | 49.1% | 11.9% | 93.6% |
| nightwatch | 396 | 2.3 | 29.3% | 15.9% | 86.9% |
| confessor | 389 | 2.6 | 19.8% | 28.5% | 92.5% |
| medium | 383 | 2.8 | 22.7% | 11.2% | 86.2% |
| lamplighter | 382 | 2.8 | 18.8% | 14.1% | 91.9% |
| registrar | 377 | 2.6 | 29.7% | 5.3% | 85.9% |
| warden | 376 | 3.0 | 12.5% | 21.0% | 87.5% |
| dowser | 371 | 2.1 | 50.7% | 8.1% | 93.0% |
| gravedigger | 358 | 2.4 | 33.2% | 9.8% | 89.7% |
| augur | 231 | 2.9 | 23.8% | 10.0% | 84.4% |
| seer | 225 | 2.3 | 40.0% | 10.2% | 86.7% |
| veteran | 172 | 3.6 | 1.7% | 20.9% | 91.9% |
| martyr | 156 | 3.3 | 9.0% | 12.8% | 88.5% |
| sexton | 148 | 2.9 | 10.1% | 23.0% | 75.7% |
| psychologist | 148 | 2.9 | 20.9% | 12.8% | 84.5% |
| executor | 147 | 2.9 | 21.8% | 6.8% | 91.2% |
| monitor | 144 | 2.9 | 17.4% | 9.0% | 79.2% |
| chronicler | 136 | 2.9 | 24.3% | 13.2% | 83.8% |
| magistrate | 135 | 2.7 | 25.9% | 10.4% | 81.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 215 | 0.0% | 52.1% |
| dowser | 204 | 0.0% | 74.5% |
| archivist | 196 | 0.0% | 60.2% |
| gravedigger | 196 | 0.0% | 63.3% |
| clerk | 189 | 0.0% | 55.0% |
| rumormonger | 181 | 0.0% | 59.1% |
| confessor | 179 | 0.0% | 72.6% |
| surveyor | 174 | 0.0% | 60.3% |
| medium | 167 | 0.0% | 54.5% |
| nightwatch | 165 | 0.0% | 66.7% |
| lamplighter | 160 | 0.0% | 66.2% |
| magistrate | 125 | 0.0% | 68.8% |
| augur | 123 | 0.0% | 53.7% |
| psychologist | 107 | 0.0% | 46.7% |
| chronicler | 107 | 0.0% | 68.2% |
| seer | 106 | 0.0% | 49.1% |
| monitor | 106 | 0.0% | 38.7% |
| executor | 96 | 0.0% | 43.8% |
| sexton | 33 | 0.0% | 42.4% |
| veteran | 31 | 0.0% | 45.2% |
| martyr | 20 | 0.0% | 45.0% |
| warden | 19 | 0.0% | 47.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 440 | 74.8% | 559 | 53.7% | +21.1 (+15.3 to +26.9) |
| poisoner + scion | 215 | 47.0% | 784 | 67.3% | -20.4 (-27.8 to -12.9) |
| breathstealer + clerk | 252 | 78.2% | 747 | 57.8% | +20.3 (+14.1 to +26.6) |
| breathstealer + rumormonger | 263 | 74.9% | 736 | 58.7% | +16.2 (+9.9 to +22.5) |
| confessor + poisoner | 220 | 51.4% | 779 | 66.2% | -14.9 (-22.3 to -7.5) |
| demon + scion | 466 | 55.2% | 533 | 69.8% | -14.6 (-20.6 to -8.7) |
| confessor + surveyor | 217 | 51.6% | 782 | 66.1% | -14.5 (-21.9 to -7.1) |
| rumormonger + scion | 275 | 52.7% | 724 | 66.9% | -14.1 (-20.9 to -7.3) |
| archivist + breathstealer | 242 | 73.1% | 757 | 59.7% | +13.4 (+6.8 to +20.0) |
| scion + surveyor | 267 | 54.3% | 732 | 66.1% | -11.8 (-18.7 to -4.9) |
| confessor + demon | 389 | 55.8% | 610 | 67.5% | -11.8 (-17.9 to -5.6) |
| breathstealer + surveyor | 261 | 71.6% | 738 | 59.9% | +11.8 (+5.2 to +18.3) |
| clerk + scion | 272 | 54.4% | 727 | 66.2% | -11.8 (-18.6 to -4.9) |
| demon + nightwatch | 396 | 69.4% | 603 | 58.7% | +10.7 (+4.7 to +16.7) |
| confessor + rumormonger | 221 | 54.8% | 778 | 65.3% | -10.5 (-17.9 to -3.2) |
| nightwatch + rumormonger | 227 | 70.9% | 772 | 60.6% | +10.3 (+3.5 to +17.1) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 46.7% | 604 | 34.8% | +11.9 (+5.7 to +18.2) **\*** |
| martyr | 156 | 31.4% | 844 | 41.0% | -9.6 (-17.6 to -1.6) **\*** |
| dowser | 372 | 45.4% | 628 | 36.0% | +9.4 (+3.1 to +15.7) **\*** |
| medium | 384 | 33.9% | 616 | 43.0% | -9.2 (-15.3 to -3.0) **\*** |
| augur | 231 | 32.9% | 769 | 41.5% | -8.6 (-15.6 to -1.6) **\*** |
| gravedigger | 358 | 34.4% | 642 | 42.4% | -8.0 (-14.2 to -1.8) **\*** |
| executor | 147 | 33.3% | 853 | 40.6% | -7.2 (-15.5 to +1.1) |
| veteran | 172 | 34.3% | 828 | 40.6% | -6.3 (-14.1 to +1.6) |
| warden | 377 | 42.7% | 623 | 37.6% | +5.1 (-1.1 to +11.4) |
| confessor | 389 | 42.2% | 611 | 37.8% | +4.4 (-1.9 to +10.6) |
| rumormonger | 590 | 41.2% | 410 | 37.1% | +4.1 (-2.0 to +10.2) |
| psychologist | 148 | 41.2% | 852 | 39.2% | +2.0 (-6.6 to +10.6) |
| chronicler | 137 | 38.0% | 863 | 39.7% | -1.8 (-10.5 to +7.0) |
| magistrate | 135 | 40.7% | 865 | 39.3% | +1.4 (-7.5 to +10.3) |
| registrar | 377 | 40.3% | 623 | 39.0% | +1.3 (-4.9 to +7.6) |
| lamplighter | 382 | 38.7% | 618 | 40.0% | -1.2 (-7.5 to +5.0) |
| seer | 225 | 40.4% | 775 | 39.2% | +1.2 (-6.1 to +8.5) |
| sexton | 148 | 38.5% | 852 | 39.7% | -1.2 (-9.7 to +7.3) |
| surveyor | 588 | 40.0% | 412 | 38.8% | +1.1 (-5.0 to +7.3) |
| monitor | 144 | 38.9% | 856 | 39.6% | -0.7 (-9.3 to +7.9) |
| clerk | 581 | 39.2% | 419 | 39.9% | -0.6 (-6.8 to +5.5) |
| archivist | 563 | 39.4% | 437 | 39.6% | -0.2 (-6.3 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 54.6% | 559 | 27.5% | +27.1 (+21.2 to +33.0) **\*** |
| poisoner | 620 | 34.5% | 380 | 47.6% | -13.1 (-19.4 to -6.9) **\*** |
| scion | 467 | 35.5% | 533 | 43.0% | -7.4 (-13.5 to -1.4) **\*** |
| revenant | 472 | 35.8% | 528 | 42.8% | -7.0 (-13.0 to -1.0) **\*** |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 216 | 31.5% | 784 | 41.7% | -10.2 (-17.3 to -3.1) **\*** |
| marked | 191 | 45.5% | 809 | 38.1% | +7.5 (-0.3 to +15.3) |
| muddler | 191 | 45.5% | 809 | 38.1% | +7.5 (-0.3 to +15.3) |
| sleepwalker | 207 | 35.3% | 793 | 40.6% | -5.3 (-12.7 to +2.0) |
| lovers | 195 | 41.0% | 805 | 39.1% | +1.9 (-5.8 to +9.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 33.0% | 909 | 40.2% | -7.2 (-17.4 to +3.0) |
| 4 night-walkers | 366 | 41.5% | 634 | 38.3% | +3.2 (-3.1 to +9.5) |
| 3 night-walkers | 543 | 39.2% | 457 | 39.8% | -0.6 (-6.7 to +5.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.5 | 14.2% | 20.3% | 95.3% |
| surveyor | 588 | 3.5 | 13.9% | 20.9% | 95.6% |
| clerk | 581 | 3.5 | 12.4% | 25.3% | 95.4% |
| archivist | 563 | 2.0 | 59.0% | 13.0% | 96.4% |
| nightwatch | 396 | 2.4 | 36.6% | 19.2% | 89.9% |
| confessor | 389 | 2.8 | 25.7% | 21.9% | 91.5% |
| medium | 384 | 2.9 | 22.4% | 16.4% | 90.1% |
| lamplighter | 382 | 3.0 | 21.7% | 18.8% | 90.8% |
| registrar | 377 | 2.9 | 30.2% | 9.8% | 86.7% |
| warden | 377 | 3.2 | 19.1% | 23.6% | 88.9% |
| dowser | 372 | 2.2 | 52.2% | 9.9% | 95.2% |
| gravedigger | 358 | 2.7 | 33.0% | 18.4% | 95.0% |
| augur | 231 | 3.1 | 20.8% | 21.2% | 86.1% |
| seer | 225 | 2.4 | 37.3% | 17.8% | 91.6% |
| veteran | 172 | 4.3 | 1.7% | 32.0% | 90.7% |
| martyr | 156 | 3.9 | 8.3% | 17.3% | 91.7% |
| sexton | 148 | 3.8 | 5.4% | 33.8% | 87.8% |
| psychologist | 148 | 2.9 | 25.0% | 18.2% | 85.8% |
| executor | 147 | 3.3 | 20.4% | 17.7% | 91.2% |
| monitor | 144 | 3.3 | 17.4% | 8.3% | 90.3% |
| chronicler | 137 | 3.2 | 14.6% | 13.1% | 94.2% |
| magistrate | 135 | 2.6 | 31.1% | 14.1% | 85.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 217 | 0.0% | 43.8% |
| dowser | 204 | 0.0% | 52.0% |
| archivist | 198 | 0.0% | 54.5% |
| gravedigger | 196 | 0.0% | 59.7% |
| clerk | 190 | 0.0% | 51.6% |
| rumormonger | 183 | 0.0% | 43.7% |
| confessor | 183 | 0.0% | 54.6% |
| surveyor | 176 | 0.0% | 47.2% |
| medium | 169 | 0.0% | 45.6% |
| nightwatch | 167 | 0.0% | 44.9% |
| lamplighter | 167 | 0.0% | 52.1% |
| magistrate | 131 | 0.0% | 58.8% |
| augur | 124 | 0.0% | 43.5% |
| chronicler | 110 | 0.0% | 43.6% |
| monitor | 109 | 0.0% | 28.4% |
| psychologist | 108 | 0.0% | 38.0% |
| seer | 106 | 0.0% | 36.8% |
| executor | 102 | 0.0% | 30.4% |
| sexton | 35 | 0.0% | 31.4% |
| veteran | 31 | 0.0% | 38.7% |
| warden | 21 | 0.0% | 33.3% |
| martyr | 20 | 0.0% | 45.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 54.6% | 559 | 27.5% | +27.1 (+21.2 to +33.0) |
| archivist + breathstealer | 243 | 56.0% | 757 | 34.2% | +21.8 (+14.7 to +28.9) |
| breathstealer + surveyor | 261 | 55.6% | 739 | 33.8% | +21.7 (+14.8 to +28.7) |
| breathstealer + clerk | 253 | 55.3% | 747 | 34.1% | +21.2 (+14.2 to +28.2) |
| breathstealer + rumormonger | 264 | 54.5% | 736 | 34.1% | +20.4 (+13.5 to +27.4) |
| poisoner + scion | 215 | 23.7% | 785 | 43.8% | -20.1 (-26.8 to -13.4) |
| poisoner + revenant | 214 | 27.6% | 786 | 42.7% | -15.2 (-22.1 to -8.3) |
| demon + poisoner | 620 | 34.5% | 380 | 47.6% | -13.1 (-19.4 to -6.9) |
| gravedigger + poisoner | 221 | 29.4% | 779 | 42.4% | -13.0 (-19.9 to -6.0) |
| nightwatch + rumormonger | 227 | 49.3% | 773 | 36.6% | +12.7 (+5.4 to +20.1) |
| dowser + rumormonger | 207 | 49.3% | 793 | 36.9% | +12.3 (+4.7 to +19.9) |
| medium + poisoner | 211 | 29.9% | 789 | 42.1% | -12.2 (-19.3 to -5.1) |
| demon + nightwatch | 396 | 46.7% | 604 | 34.8% | +11.9 (+5.7 to +18.2) |
| clerk + nightwatch | 225 | 48.4% | 775 | 36.9% | +11.5 (+4.2 to +18.9) |
| archivist + dowser | 210 | 47.6% | 790 | 37.3% | +10.3 (+2.7 to +17.8) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 1000 | 334 (33.4%) | 103 (10.3%) | 319 | 244 |
| 10 | 10 NPCs, bot insight 1.0 | 999 | 340 (34.0%) | 106 (10.6%) | 289 | 264 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 1 — seeds 100446 (timeout)
- Games with engine errors: 0
- Shared-model fallbacks: 12 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 54.4 | 109.3 | 292.8 |
| 7 NPCs, passive | 4.2 | 6.6 | 17.0 |
| 10 NPCs, bot insight 1.0 | 320.9 | 686.9 | 1660.5 |
| 10 NPCs, passive | 31.8 | 57.6 | 132.2 |

Slowest seeds: 100339 (10 NPCs bot, 1661 s), 100986 (10 NPCs bot, 1571 s), 100298 (10 NPCs bot, 1508 s), 100047 (10 NPCs bot, 1416 s), 100937 (10 NPCs bot, 1337 s), 100712 (10 NPCs bot, 1275 s), 100975 (10 NPCs bot, 1260 s), 100374 (10 NPCs bot, 1257 s), 100316 (10 NPCs bot, 1217 s), 100898 (10 NPCs bot, 1182 s), 100330 (10 NPCs bot, 1173 s), 100903 (10 NPCs bot, 1122 s), 100949 (10 NPCs bot, 1106 s), 100465 (10 NPCs bot, 1095 s), 100363 (10 NPCs bot, 1056 s), 100093 (10 NPCs bot, 1055 s), 100714 (10 NPCs bot, 1054 s), 100345 (10 NPCs bot, 1020 s), 100867 (10 NPCs bot, 998 s), 100286 (10 NPCs bot, 986 s)

