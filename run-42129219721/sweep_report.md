# Balance sweep report

Records: 4000 games, 0 failed. Commit(s): `501b83e369`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 57.7% (54.6%–60.7%) | 3.10 | 0.76 | 1.04 | 2.35 | 7.9% | 0.25 |
| 7 NPCs, passive | 1000 | 37.6% (34.7%–40.6%) | 3.45 | 0.94 | 0.75 | 2.38 | 3.5% | 0.25 |
| 10 NPCs, bot insight 1.0 | 1000 | 56.3% (53.2%–59.3%) | 4.19 | 1.10 | 1.55 | 2.47 | 7.4% | 0.39 |
| 10 NPCs, passive | 1000 | 42.6% (39.6%–45.7%) | 4.39 | 1.30 | 1.34 | 2.50 | 3.1% | 0.44 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 577 (57.7%)
- Only two townsfolk remain and the demon still walks among them.: 423 (42.3%)
- Demon evidence on the board: 99.0% of games; good win rate 57.3% of 990
- Demon evidence reachable: 80.7% of games; good win rate 53.2% of 807
- Neither: 0.6% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=1000)

- Only two townsfolk remain and the demon still walks among them.: 624 (62.4%)
- The demon's host was executed.: 376 (37.6%)
- Demon evidence on the board: 58.6% of games; good win rate 48.0% of 586
- Demon evidence reachable: 99.4% of games; good win rate 37.2% of 994
- Neither: 0.6% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 563 (56.3%)
- Only two townsfolk remain and the demon still walks among them.: 275 (27.5%)
- No good soul remains.: 150 (15.0%)
- Time ran out: the demon survived 8 days.: 8 (0.8%)
- (none): 4 (0.4%)
- Demon evidence on the board: 99.4% of games; good win rate 56.4% of 994
- Demon evidence reachable: 90.1% of games; good win rate 54.5% of 901
- Neither: 0.3% of games; good win rate 66.7% of 3
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=1000)

- The demon's host was executed.: 426 (42.6%)
- Only two townsfolk remain and the demon still walks among them.: 289 (28.9%)
- No good soul remains.: 283 (28.3%)
- Time ran out: the demon survived 8 days.: 2 (0.2%)
- Demon evidence on the board: 74.0% of games; good win rate 47.0% of 740
- Demon evidence reachable: 100.0% of games; good win rate 42.6% of 1000
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| martyr | 88 | 44.3% | 912 | 59.0% | -14.7 (-25.5 to -3.8) **\*** |
| psychologist | 67 | 49.3% | 933 | 58.3% | -9.1 (-21.4 to +3.3) |
| veteran | 73 | 65.8% | 927 | 57.1% | +8.7 (-2.7 to +20.0) |
| augur | 193 | 50.8% | 807 | 59.4% | -8.6 (-16.4 to -0.8) **\*** |
| gravedigger | 283 | 51.9% | 717 | 60.0% | -8.0 (-14.9 to -1.2) **\*** |
| nightwatch | 238 | 63.4% | 762 | 55.9% | +7.5 (+0.5 to +14.6) **\*** |
| chronicler | 76 | 64.5% | 924 | 57.1% | +7.3 (-3.9 to +18.6) |
| magistrate | 73 | 64.4% | 927 | 57.2% | +7.2 (-4.2 to +18.6) |
| monitor | 73 | 52.1% | 927 | 58.1% | -6.1 (-18.0 to +5.8) |
| registrar | 270 | 61.9% | 730 | 56.2% | +5.7 (-1.1 to +12.5) |
| dowser | 286 | 61.5% | 714 | 56.2% | +5.4 (-1.3 to +12.1) |
| archivist | 548 | 55.7% | 452 | 60.2% | -4.5 (-10.7 to +1.6) |
| executor | 87 | 60.9% | 913 | 57.4% | +3.5 (-7.2 to +14.3) |
| seer | 170 | 60.6% | 830 | 57.1% | +3.5 (-4.6 to +11.6) |
| medium | 188 | 55.3% | 812 | 58.3% | -2.9 (-10.8 to +4.9) |
| sexton | 74 | 55.4% | 926 | 57.9% | -2.5 (-14.2 to +9.3) |
| surveyor | 508 | 58.9% | 492 | 56.5% | +2.4 (-3.8 to +8.5) |
| clerk | 545 | 58.3% | 455 | 56.9% | +1.4 (-4.7 to +7.6) |
| confessor | 224 | 58.5% | 776 | 57.5% | +1.0 (-6.3 to +8.3) |
| lamplighter | 203 | 57.1% | 797 | 57.8% | -0.7 (-8.3 to +6.9) |
| warden | 229 | 57.2% | 771 | 57.8% | -0.6 (-7.9 to +6.7) |
| rumormonger | 504 | 57.7% | 496 | 57.7% | +0.1 (-6.0 to +6.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 67.6% | 781 | 54.9% | +12.7 (+5.5 to +19.8) **\*** |
| poisoner | 325 | 54.5% | 675 | 59.3% | -4.8 (-11.4 to +1.8) |
| revenant | 221 | 54.3% | 779 | 58.7% | -4.4 (-11.8 to +3.1) |
| scion | 235 | 56.2% | 765 | 58.2% | -2.0 (-9.2 to +5.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 48.6% | 788 | 60.2% | -11.6 (-19.1 to -4.0) **\*** |
| lovers | 208 | 66.8% | 792 | 55.3% | +11.5 (+4.2 to +18.8) **\*** |
| sleepwalker | 186 | 59.7% | 814 | 57.2% | +2.4 (-5.4 to +10.3) |
| marked | 195 | 56.4% | 805 | 58.0% | -1.6 (-9.4 to +6.1) |
| muddler | 199 | 57.3% | 801 | 57.8% | -0.5 (-8.2 to +7.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 321 | 57.0% | 679 | 58.0% | -1.0 (-7.6 to +5.5) |
| 2 night-walkers | 636 | 58.0% | 364 | 57.1% | +0.9 (-5.5 to +7.2) |
| 4 night-walkers | 43 | 58.1% | 957 | 57.7% | +0.5 (-14.6 to +15.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.6 | 54.0% | 18.8% | 94.3% |
| clerk | 545 | 2.3 | 22.0% | 16.7% | 93.6% |
| surveyor | 508 | 2.2 | 23.6% | 15.0% | 94.3% |
| rumormonger | 504 | 2.2 | 26.2% | 17.3% | 90.7% |
| dowser | 286 | 1.8 | 49.7% | 10.8% | 81.1% |
| gravedigger | 283 | 2.0 | 40.3% | 20.5% | 84.1% |
| registrar | 270 | 2.1 | 33.0% | 5.2% | 77.4% |
| nightwatch | 238 | 2.0 | 34.5% | 13.4% | 81.5% |
| warden | 229 | 2.3 | 26.2% | 18.8% | 79.9% |
| confessor | 224 | 2.1 | 29.5% | 17.0% | 79.9% |
| lamplighter | 203 | 2.3 | 28.1% | 8.4% | 83.3% |
| augur | 193 | 2.3 | 27.5% | 18.1% | 76.2% |
| medium | 188 | 2.1 | 25.5% | 15.4% | 77.1% |
| seer | 170 | 1.8 | 40.0% | 11.8% | 78.8% |
| martyr | 88 | 2.8 | 9.1% | 11.4% | 94.3% |
| executor | 87 | 2.3 | 27.6% | 13.8% | 75.9% |
| chronicler | 76 | 2.1 | 27.6% | 17.1% | 77.6% |
| sexton | 74 | 2.2 | 21.6% | 21.6% | 67.6% |
| veteran | 73 | 3.0 | 2.7% | 8.2% | 84.9% |
| monitor | 73 | 2.4 | 28.8% | 4.1% | 72.6% |
| magistrate | 73 | 2.2 | 31.5% | 12.3% | 83.6% |
| psychologist | 67 | 2.4 | 29.9% | 19.4% | 85.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 142 | 0.0% | 47.2% |
| registrar | 142 | 0.0% | 47.9% |
| dowser | 137 | 0.0% | 70.1% |
| confessor | 135 | 0.0% | 61.5% |
| lamplighter | 126 | 0.0% | 57.1% |
| medium | 126 | 0.0% | 34.9% |
| gravedigger | 120 | 0.0% | 60.0% |
| surveyor | 113 | 0.0% | 61.1% |
| rumormonger | 109 | 0.0% | 60.6% |
| clerk | 105 | 0.0% | 53.3% |
| archivist | 101 | 0.0% | 60.4% |
| chronicler | 78 | 0.0% | 61.5% |
| psychologist | 78 | 0.0% | 57.7% |
| executor | 77 | 0.0% | 39.0% |
| magistrate | 76 | 0.0% | 50.0% |
| seer | 76 | 0.0% | 39.5% |
| augur | 70 | 0.0% | 50.0% |
| monitor | 59 | 0.0% | 33.9% |
| warden | 19 | 0.0% | 36.8% |
| martyr | 18 | 0.0% | 22.2% |
| veteran | 14 | 0.0% | 35.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 67.6% | 781 | 54.9% | +12.7 (+5.5 to +19.8) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 238 | 50.8% | 762 | 33.5% | +17.4 (+10.2 to +24.6) **\*** |
| monitor | 73 | 21.9% | 927 | 38.8% | -16.9 (-26.9 to -6.9) **\*** |
| martyr | 88 | 27.3% | 912 | 38.6% | -11.3 (-21.2 to -1.5) **\*** |
| veteran | 73 | 27.4% | 927 | 38.4% | -11.0 (-21.7 to -0.3) **\*** |
| dowser | 286 | 45.1% | 714 | 34.6% | +10.5 (+3.8 to +17.3) **\*** |
| warden | 229 | 45.4% | 771 | 35.3% | +10.1 (+2.9 to +17.4) **\*** |
| sexton | 74 | 28.4% | 926 | 38.3% | -10.0 (-20.7 to +0.8) |
| executor | 87 | 28.7% | 913 | 38.4% | -9.7 (-19.7 to +0.3) |
| magistrate | 73 | 43.8% | 927 | 37.1% | +6.7 (-5.1 to +18.5) |
| medium | 188 | 32.4% | 812 | 38.8% | -6.3 (-13.8 to +1.1) |
| augur | 193 | 32.6% | 807 | 38.8% | -6.1 (-13.6 to +1.3) |
| gravedigger | 283 | 34.3% | 717 | 38.9% | -4.6 (-11.2 to +1.9) |
| confessor | 224 | 41.1% | 776 | 36.6% | +4.5 (-2.8 to +11.8) |
| chronicler | 76 | 34.2% | 924 | 37.9% | -3.7 (-14.8 to +7.4) |
| archivist | 548 | 36.7% | 452 | 38.7% | -2.0 (-8.1 to +4.0) |
| lamplighter | 203 | 36.5% | 797 | 37.9% | -1.4 (-8.9 to +6.0) |
| seer | 170 | 36.5% | 830 | 37.8% | -1.4 (-9.3 to +6.6) |
| psychologist | 67 | 38.8% | 933 | 37.5% | +1.3 (-10.8 to +13.4) |
| registrar | 270 | 38.1% | 730 | 37.4% | +0.8 (-6.0 to +7.5) |
| rumormonger | 504 | 37.3% | 496 | 37.9% | -0.6 (-6.6 to +5.4) |
| clerk | 545 | 37.4% | 455 | 37.8% | -0.4 (-6.4 to +5.7) |
| surveyor | 508 | 37.6% | 492 | 37.6% | -0.0 (-6.0 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 51.6% | 781 | 33.7% | +17.9 (+10.5 to +25.3) **\*** |
| revenant | 221 | 30.3% | 779 | 39.7% | -9.3 (-16.3 to -2.4) **\*** |
| poisoner | 325 | 33.5% | 675 | 39.6% | -6.0 (-12.3 to +0.3) |
| scion | 235 | 37.0% | 765 | 37.8% | -0.8 (-7.8 to +6.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 22.6% | 788 | 41.6% | -19.0 (-25.6 to -12.4) **\*** |
| lovers | 208 | 47.1% | 792 | 35.1% | +12.0 (+4.5 to +19.6) **\*** |
| sleepwalker | 186 | 41.4% | 814 | 36.7% | +4.7 (-3.1 to +12.5) |
| muddler | 199 | 40.7% | 801 | 36.8% | +3.9 (-3.7 to +11.5) |
| marked | 195 | 36.9% | 805 | 37.8% | -0.8 (-8.4 to +6.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 48.8% | 957 | 37.1% | +11.7 (-3.5 to +27.0) |
| 2 night-walkers | 636 | 33.3% | 364 | 45.1% | -11.7 (-18.0 to -5.4) **\*** |
| 3 night-walkers | 321 | 44.5% | 679 | 34.3% | +10.2 (+3.7 to +16.7) **\*** |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.6 | 59.3% | 19.2% | 94.9% |
| clerk | 545 | 2.6 | 20.6% | 26.2% | 93.6% |
| surveyor | 508 | 2.5 | 29.1% | 22.4% | 93.3% |
| rumormonger | 504 | 2.6 | 24.4% | 27.4% | 94.2% |
| dowser | 286 | 1.9 | 56.6% | 10.5% | 88.1% |
| gravedigger | 283 | 2.0 | 45.6% | 19.4% | 86.9% |
| registrar | 270 | 2.2 | 41.9% | 7.8% | 85.6% |
| nightwatch | 238 | 2.2 | 39.5% | 8.0% | 84.5% |
| warden | 229 | 2.5 | 23.1% | 17.5% | 79.0% |
| confessor | 224 | 2.3 | 34.8% | 12.9% | 87.9% |
| lamplighter | 203 | 2.4 | 29.1% | 11.3% | 85.7% |
| augur | 193 | 2.4 | 33.7% | 15.5% | 82.4% |
| medium | 188 | 2.3 | 34.0% | 14.9% | 80.3% |
| seer | 170 | 2.0 | 46.5% | 11.2% | 85.9% |
| martyr | 88 | 2.8 | 19.3% | 30.7% | 85.2% |
| executor | 87 | 2.5 | 32.2% | 20.7% | 79.3% |
| chronicler | 76 | 2.4 | 27.6% | 14.5% | 81.6% |
| sexton | 74 | 2.7 | 23.0% | 31.1% | 81.1% |
| magistrate | 73 | 2.3 | 35.6% | 11.0% | 84.9% |
| monitor | 73 | 2.4 | 35.6% | 6.8% | 78.1% |
| veteran | 73 | 3.6 | 4.1% | 42.5% | 94.5% |
| psychologist | 67 | 2.7 | 20.9% | 20.9% | 83.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 148 | 0.0% | 48.6% |
| nightwatch | 140 | 0.0% | 18.6% |
| dowser | 138 | 0.0% | 48.6% |
| confessor | 137 | 0.0% | 39.4% |
| medium | 131 | 0.0% | 16.8% |
| lamplighter | 128 | 0.0% | 31.2% |
| gravedigger | 117 | 0.0% | 46.2% |
| surveyor | 113 | 0.0% | 37.2% |
| rumormonger | 109 | 0.0% | 46.8% |
| clerk | 105 | 0.0% | 53.3% |
| archivist | 100 | 0.0% | 58.0% |
| seer | 78 | 0.0% | 30.8% |
| executor | 77 | 0.0% | 28.6% |
| magistrate | 77 | 0.0% | 40.3% |
| chronicler | 77 | 0.0% | 41.6% |
| psychologist | 77 | 0.0% | 40.3% |
| augur | 72 | 0.0% | 41.7% |
| monitor | 63 | 0.0% | 23.8% |
| warden | 19 | 0.0% | 5.3% |
| martyr | 17 | 0.0% | 29.4% |
| veteran | 16 | 0.0% | 25.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 51.6% | 781 | 33.7% | +17.9 (+10.5 to +25.3) |
| demon + nightwatch | 238 | 50.8% | 762 | 33.5% | +17.4 (+10.2 to +24.6) |
| demon + dowser | 286 | 45.1% | 714 | 34.6% | +10.5 (+3.8 to +17.3) |
| demon + warden | 229 | 45.4% | 771 | 35.3% | +10.1 (+2.9 to +17.4) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 137 | 45.3% | 863 | 58.1% | -12.8 (-21.8 to -3.8) **\*** |
| dowser | 372 | 61.3% | 628 | 53.3% | +7.9 (+1.6 to +14.2) **\*** |
| sexton | 148 | 50.0% | 852 | 57.4% | -7.4 (-16.1 to +1.3) |
| gravedigger | 358 | 52.5% | 642 | 58.4% | -5.9 (-12.3 to +0.5) |
| nightwatch | 396 | 59.8% | 604 | 54.0% | +5.9 (-0.4 to +12.1) |
| martyr | 156 | 51.9% | 844 | 57.1% | -5.2 (-13.7 to +3.3) |
| augur | 231 | 52.4% | 769 | 57.5% | -5.1 (-12.4 to +2.2) |
| executor | 147 | 52.4% | 853 | 57.0% | -4.6 (-13.3 to +4.1) |
| medium | 384 | 59.1% | 616 | 54.5% | +4.6 (-1.7 to +10.9) |
| monitor | 144 | 54.2% | 856 | 56.7% | -2.5 (-11.3 to +6.3) |
| psychologist | 148 | 58.1% | 852 | 56.0% | +2.1 (-6.5 to +10.7) |
| lamplighter | 382 | 57.6% | 618 | 55.5% | +2.1 (-4.2 to +8.4) |
| warden | 377 | 57.6% | 623 | 55.5% | +2.0 (-4.3 to +8.4) |
| confessor | 389 | 55.3% | 611 | 57.0% | -1.7 (-8.0 to +4.6) |
| archivist | 563 | 57.0% | 437 | 55.4% | +1.6 (-4.6 to +7.8) |
| registrar | 377 | 57.3% | 623 | 55.7% | +1.6 (-4.7 to +7.9) |
| rumormonger | 590 | 56.8% | 410 | 55.6% | +1.2 (-5.1 to +7.4) |
| magistrate | 135 | 55.6% | 865 | 56.4% | -0.9 (-9.9 to +8.1) |
| veteran | 172 | 57.0% | 828 | 56.2% | +0.8 (-7.3 to +9.0) |
| clerk | 581 | 56.1% | 419 | 56.6% | -0.5 (-6.7 to +5.8) |
| surveyor | 588 | 56.5% | 412 | 56.1% | +0.4 (-5.9 to +6.6) |
| seer | 225 | 56.4% | 775 | 56.3% | +0.2 (-7.2 to +7.5) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 67.8% | 559 | 47.2% | +20.6 (+14.6 to +26.6) **\*** |
| scion | 467 | 46.9% | 533 | 64.5% | -17.6 (-23.7 to -11.6) **\*** |
| poisoner | 620 | 52.4% | 380 | 62.6% | -10.2 (-16.5 to -4.0) **\*** |
| revenant | 472 | 60.0% | 528 | 53.0% | +6.9 (+0.8 to +13.1) **\*** |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 191 | 63.4% | 809 | 54.6% | +8.7 (+1.1 to +16.4) **\*** |
| delusional | 216 | 49.5% | 784 | 58.2% | -8.6 (-16.1 to -1.1) **\*** |
| sleepwalker | 207 | 54.1% | 793 | 56.9% | -2.8 (-10.4 to +4.8) |
| lovers | 195 | 58.5% | 805 | 55.8% | +2.7 (-5.0 to +10.4) |
| muddler | 191 | 57.1% | 809 | 56.1% | +0.9 (-6.9 to +8.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 58.2% | 909 | 56.1% | +2.1 (-8.5 to +12.8) |
| 3 night-walkers | 543 | 55.4% | 457 | 57.3% | -1.9 (-8.1 to +4.3) |
| 4 night-walkers | 366 | 57.1% | 634 | 55.8% | +1.3 (-5.1 to +7.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.3 | 11.5% | 19.0% | 92.7% |
| surveyor | 588 | 3.1 | 17.2% | 17.3% | 93.9% |
| clerk | 581 | 3.2 | 13.4% | 18.9% | 94.8% |
| archivist | 563 | 1.8 | 53.6% | 12.3% | 94.8% |
| nightwatch | 396 | 2.4 | 30.3% | 16.2% | 87.9% |
| confessor | 389 | 2.5 | 23.4% | 22.1% | 86.1% |
| medium | 384 | 2.8 | 19.3% | 7.3% | 85.7% |
| lamplighter | 382 | 2.9 | 20.7% | 8.4% | 89.5% |
| registrar | 377 | 2.5 | 29.2% | 8.0% | 83.3% |
| warden | 377 | 3.1 | 19.1% | 15.6% | 81.2% |
| dowser | 372 | 2.1 | 43.8% | 12.6% | 90.6% |
| gravedigger | 358 | 2.5 | 27.4% | 19.3% | 90.5% |
| augur | 231 | 2.9 | 20.3% | 20.3% | 85.7% |
| seer | 225 | 2.3 | 32.4% | 11.6% | 85.3% |
| veteran | 172 | 3.9 | 2.3% | 22.7% | 89.0% |
| martyr | 156 | 3.5 | 9.0% | 15.4% | 87.8% |
| psychologist | 148 | 2.9 | 23.0% | 16.2% | 82.4% |
| sexton | 148 | 3.4 | 8.1% | 33.1% | 81.1% |
| executor | 147 | 3.2 | 18.4% | 9.5% | 86.4% |
| monitor | 144 | 2.9 | 20.1% | 11.1% | 79.2% |
| chronicler | 137 | 2.8 | 19.7% | 15.3% | 86.1% |
| magistrate | 135 | 2.7 | 25.9% | 15.6% | 88.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 211 | 0.0% | 48.8% |
| archivist | 196 | 0.0% | 55.1% |
| gravedigger | 195 | 0.0% | 66.2% |
| dowser | 193 | 0.0% | 63.2% |
| clerk | 189 | 0.0% | 58.7% |
| rumormonger | 182 | 0.0% | 53.3% |
| confessor | 179 | 0.0% | 67.0% |
| surveyor | 172 | 0.0% | 51.2% |
| medium | 168 | 0.0% | 23.2% |
| lamplighter | 168 | 0.0% | 60.7% |
| nightwatch | 164 | 0.0% | 62.2% |
| magistrate | 125 | 0.0% | 59.2% |
| augur | 118 | 0.0% | 57.6% |
| chronicler | 107 | 0.0% | 47.7% |
| psychologist | 107 | 0.0% | 37.4% |
| monitor | 104 | 0.0% | 33.7% |
| seer | 103 | 0.0% | 51.5% |
| executor | 99 | 0.0% | 43.4% |
| sexton | 33 | 0.0% | 42.4% |
| veteran | 29 | 0.0% | 31.0% |
| martyr | 21 | 0.0% | 19.0% |
| warden | 20 | 0.0% | 40.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner + scion | 215 | 31.6% | 785 | 63.1% | -31.4 (-38.5 to -24.4) |
| breathstealer + demon | 441 | 67.8% | 559 | 47.2% | +20.6 (+14.6 to +26.6) |
| archivist + breathstealer | 243 | 70.8% | 757 | 51.7% | +19.1 (+12.4 to +25.9) |
| demon + scion | 467 | 46.9% | 533 | 64.5% | -17.6 (-23.7 to -11.6) |
| breathstealer + rumormonger | 264 | 68.9% | 736 | 51.8% | +17.2 (+10.5 to +23.8) |
| breathstealer + surveyor | 261 | 67.4% | 739 | 52.4% | +15.1 (+8.3 to +21.8) |
| rumormonger + scion | 276 | 45.7% | 724 | 60.4% | -14.7 (-21.6 to -7.8) |
| breathstealer + clerk | 253 | 66.0% | 747 | 53.0% | +13.0 (+6.1 to +19.8) |
| clerk + scion | 273 | 47.3% | 727 | 59.7% | -12.4 (-19.4 to -5.5) |
| scion + surveyor | 267 | 47.2% | 733 | 59.6% | -12.4 (-19.4 to -5.5) |
| gravedigger + poisoner | 221 | 47.1% | 779 | 58.9% | -11.9 (-19.3 to -4.4) |
| demon + poisoner | 620 | 52.4% | 380 | 62.6% | -10.2 (-16.5 to -4.0) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 137 | 32.8% | 863 | 44.1% | -11.3 (-19.8 to -2.8) **\*** |
| nightwatch | 396 | 49.2% | 604 | 38.2% | +11.0 (+4.7 to +17.3) **\*** |
| sexton | 148 | 34.5% | 852 | 44.0% | -9.6 (-17.9 to -1.2) **\*** |
| archivist | 563 | 38.7% | 437 | 47.6% | -8.9 (-15.1 to -2.7) **\*** |
| psychologist | 148 | 36.5% | 852 | 43.7% | -7.2 (-15.6 to +1.3) |
| warden | 377 | 46.9% | 623 | 40.0% | +7.0 (+0.6 to +13.3) **\*** |
| lamplighter | 382 | 46.9% | 618 | 40.0% | +6.9 (+0.6 to +13.2) **\*** |
| gravedigger | 358 | 38.5% | 642 | 44.9% | -6.3 (-12.7 to +0.0) |
| augur | 231 | 38.5% | 769 | 43.8% | -5.3 (-12.5 to +1.9) |
| registrar | 377 | 44.8% | 623 | 41.3% | +3.6 (-2.8 to +9.9) |
| monitor | 144 | 45.1% | 856 | 42.2% | +3.0 (-5.8 to +11.7) |
| confessor | 389 | 41.1% | 611 | 43.5% | -2.4 (-8.7 to +3.9) |
| rumormonger | 590 | 43.6% | 410 | 41.2% | +2.3 (-3.9 to +8.6) |
| medium | 384 | 43.8% | 616 | 41.9% | +1.9 (-4.4 to +8.2) |
| clerk | 581 | 43.2% | 419 | 41.8% | +1.4 (-4.8 to +7.6) |
| magistrate | 135 | 41.5% | 865 | 42.8% | -1.3 (-10.2 to +7.6) |
| dowser | 372 | 43.3% | 628 | 42.2% | +1.1 (-5.3 to +7.4) |
| veteran | 172 | 43.0% | 828 | 42.5% | +0.5 (-7.6 to +8.6) |
| executor | 147 | 42.2% | 853 | 42.7% | -0.5 (-9.1 to +8.1) |
| seer | 225 | 42.2% | 775 | 42.7% | -0.5 (-7.8 to +6.8) |
| martyr | 156 | 42.9% | 844 | 42.5% | +0.4 (-8.0 to +8.9) |
| surveyor | 588 | 42.7% | 412 | 42.5% | +0.2 (-6.0 to +6.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 52.2% | 559 | 35.1% | +17.1 (+11.0 to +23.2) **\*** |
| poisoner | 620 | 39.2% | 380 | 48.2% | -9.0 (-15.3 to -2.6) **\*** |
| scion | 467 | 38.1% | 533 | 46.5% | -8.4 (-14.5 to -2.3) **\*** |
| revenant | 472 | 42.6% | 528 | 42.6% | -0.0 (-6.2 to +6.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| muddler | 191 | 48.7% | 809 | 41.2% | +7.5 (-0.3 to +15.4) |
| delusional | 216 | 37.5% | 784 | 44.0% | -6.5 (-13.8 to +0.8) |
| sleepwalker | 207 | 39.1% | 793 | 43.5% | -4.4 (-11.9 to +3.1) |
| marked | 191 | 46.1% | 809 | 41.8% | +4.3 (-3.6 to +12.1) |
| lovers | 195 | 42.6% | 805 | 42.6% | -0.0 (-7.8 to +7.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 59.3% | 909 | 40.9% | +18.4 (+7.8 to +29.0) **\*** |
| 3 night-walkers | 543 | 38.7% | 457 | 47.3% | -8.6 (-14.7 to -2.4) **\*** |
| 4 night-walkers | 366 | 44.3% | 634 | 41.6% | +2.6 (-3.8 to +9.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 14.4% | 25.9% | 93.4% |
| surveyor | 588 | 3.4 | 14.5% | 26.5% | 95.9% |
| clerk | 581 | 3.6 | 10.5% | 26.2% | 95.5% |
| archivist | 563 | 1.9 | 55.2% | 14.2% | 95.9% |
| nightwatch | 396 | 2.5 | 33.8% | 13.6% | 90.4% |
| confessor | 389 | 2.8 | 24.9% | 17.2% | 90.5% |
| medium | 384 | 2.9 | 22.7% | 9.6% | 88.5% |
| lamplighter | 382 | 2.8 | 24.3% | 8.9% | 88.0% |
| registrar | 377 | 2.8 | 26.5% | 13.5% | 89.1% |
| warden | 377 | 3.1 | 17.2% | 19.4% | 87.8% |
| dowser | 372 | 2.1 | 54.6% | 11.0% | 91.1% |
| gravedigger | 358 | 2.6 | 33.2% | 19.0% | 89.9% |
| augur | 231 | 3.0 | 20.8% | 19.9% | 89.2% |
| seer | 225 | 2.3 | 46.2% | 14.7% | 88.4% |
| veteran | 172 | 4.1 | 3.5% | 29.1% | 86.6% |
| martyr | 156 | 3.4 | 12.8% | 23.1% | 86.5% |
| sexton | 148 | 3.4 | 10.1% | 41.2% | 87.8% |
| psychologist | 148 | 2.9 | 18.2% | 24.3% | 84.5% |
| executor | 147 | 3.3 | 17.0% | 12.9% | 91.8% |
| monitor | 144 | 3.4 | 18.1% | 5.6% | 83.3% |
| chronicler | 137 | 2.8 | 27.0% | 19.7% | 83.9% |
| magistrate | 135 | 2.6 | 31.1% | 12.6% | 90.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 214 | 0.0% | 45.3% |
| dowser | 202 | 0.0% | 57.9% |
| archivist | 197 | 0.0% | 57.4% |
| gravedigger | 196 | 0.0% | 59.7% |
| clerk | 190 | 0.0% | 54.2% |
| rumormonger | 183 | 0.0% | 48.6% |
| confessor | 179 | 0.0% | 45.3% |
| surveyor | 176 | 0.0% | 47.2% |
| medium | 169 | 0.0% | 14.8% |
| lamplighter | 166 | 0.0% | 42.2% |
| nightwatch | 164 | 0.0% | 43.3% |
| magistrate | 131 | 0.0% | 45.8% |
| augur | 124 | 0.0% | 46.0% |
| psychologist | 110 | 0.0% | 38.2% |
| monitor | 108 | 0.0% | 25.0% |
| seer | 107 | 0.0% | 44.9% |
| chronicler | 107 | 0.0% | 48.6% |
| executor | 99 | 0.0% | 30.3% |
| sexton | 34 | 0.0% | 32.4% |
| veteran | 29 | 0.0% | 44.8% |
| martyr | 20 | 0.0% | 30.0% |
| warden | 19 | 0.0% | 36.8% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 52.2% | 559 | 35.1% | +17.1 (+11.0 to +23.2) |
| poisoner + scion | 215 | 29.8% | 785 | 46.1% | -16.3 (-23.4 to -9.3) |
| breathstealer + clerk | 253 | 53.8% | 747 | 38.8% | +14.9 (+7.9 to +22.0) |
| breathstealer + rumormonger | 264 | 52.7% | 736 | 39.0% | +13.7 (+6.7 to +20.6) |
| archivist + poisoner | 345 | 33.9% | 655 | 47.2% | -13.3 (-19.6 to -7.0) |
| breathstealer + surveyor | 261 | 52.1% | 739 | 39.2% | +12.9 (+5.9 to +19.9) |
| nightwatch + rumormonger | 227 | 51.1% | 773 | 40.1% | +11.0 (+3.6 to +18.4) |
| demon + nightwatch | 396 | 49.2% | 604 | 38.2% | +11.0 (+4.7 to +17.3) |
| clerk + nightwatch | 225 | 51.1% | 775 | 40.1% | +11.0 (+3.6 to +18.4) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 1000 | 305 (30.5%) | 104 (10.4%) | 272 | 319 |
| 10 | 10 NPCs, bot insight 1.0 | 1000 | 251 (25.1%) | 114 (11.4%) | 312 | 323 |

## Health

- Stuck games (guard exhausted): 4 — seeds 100704 (10 NPCs, bot), 100016 (10 NPCs, bot), 100960 (10 NPCs, bot), 100785 (10 NPCs, bot)
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 10 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 33.7 | 71.8 | 325.7 |
| 7 NPCs, passive | 2.7 | 4.5 | 10.6 |
| 10 NPCs, bot insight 1.0 | 163.4 | 341.8 | 1034.1 |
| 10 NPCs, passive | 38.4 | 72.9 | 210.6 |

Slowest seeds: 100011 (10 NPCs bot, 1034 s), 100707 (10 NPCs bot, 928 s), 100217 (10 NPCs bot, 836 s), 100968 (10 NPCs bot, 825 s), 100918 (10 NPCs bot, 803 s), 100080 (10 NPCs bot, 774 s), 100726 (10 NPCs bot, 751 s), 100720 (10 NPCs bot, 729 s), 100067 (10 NPCs bot, 720 s), 100195 (10 NPCs bot, 712 s), 100746 (10 NPCs bot, 711 s), 100097 (10 NPCs bot, 710 s), 100737 (10 NPCs bot, 707 s), 100573 (10 NPCs bot, 695 s), 100589 (10 NPCs bot, 629 s), 100684 (10 NPCs bot, 614 s), 100871 (10 NPCs bot, 610 s), 100841 (10 NPCs bot, 597 s), 100106 (10 NPCs bot, 559 s), 100874 (10 NPCs bot, 544 s)

