# Balance sweep report

Records: 3999 games, 1 failed, 0 stuck (left out of the rates). Commit(s): `9b2ca88709`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 1000 | 65.8% (62.8%–68.7%) | 3.04 | 0.61 | 1.21 | 2.27 | 10.1% | 0.25 |
| 7 NPCs, passive | 1000 | 41.8% (38.8%–44.9%) | 3.44 | 0.82 | 0.88 | 2.42 | 3.9% | 0.23 |
| 10 NPCs, bot insight 1.0 | 999 | 62.7% (59.6%–65.6%) | 4.17 | 0.99 | 1.71 | 2.45 | 8.8% | 0.44 |
| 10 NPCs, passive | 1000 | 41.5% (38.5%–44.6%) | 4.54 | 1.27 | 1.43 | 2.58 | 3.2% | 0.51 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.90 | 20.7% | 28.4% | 2.04 | 14.6% | 13.8% | 13.0% |
| 7 NPCs, passive | 6.26 | 17.8% | 39.8% | 2.90 | 25.6% | 24.5% | 23.0% |
| 10 NPCs, bot insight 1.0 | 9.18 | 13.0% | 27.0% | 3.90 | 14.5% | 13.9% | 12.8% |
| 10 NPCs, passive | 10.61 | 10.7% | 31.8% | 5.04 | 25.4% | 24.8% | 21.2% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=1000)

- The demon's host was executed.: 658 (65.8%)
- Only two townsfolk remain and the demon still walks among them.: 342 (34.2%)
- Demon evidence on the board: 97.9% of games; good win rate 65.5% of 979
- Demon evidence reachable: 78.3% of games; good win rate 61.4% of 783
- Neither: 1.3% of games; good win rate 100.0% of 13
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=1000)

- Only two townsfolk remain and the demon still walks among them.: 581 (58.1%)
- The demon's host was executed.: 418 (41.8%)
- Time ran out: the demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 60.8% of games; good win rate 49.7% of 608
- Demon evidence reachable: 99.8% of games; good win rate 41.7% of 998
- Neither: 0.2% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=999)

- The demon's host was executed.: 626 (62.7%)
- Only two townsfolk remain and the demon still walks among them.: 253 (25.3%)
- No good soul remains.: 119 (11.9%)
- Time ran out: the demon survived 8 days.: 1 (0.1%)
- Demon evidence on the board: 99.6% of games; good win rate 62.5% of 995
- Demon evidence reachable: 86.9% of games; good win rate 60.1% of 868
- Neither: 0.4% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=1000)

- The demon's host was executed.: 415 (41.5%)
- No good soul remains.: 295 (29.5%)
- Only two townsfolk remain and the demon still walks among them.: 287 (28.7%)
- Time ran out: the demon survived 8 days.: 3 (0.3%)
- Demon evidence on the board: 76.5% of games; good win rate 44.2% of 765
- Demon evidence reachable: 100.0% of games; good win rate 41.5% of 1000
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| dowser | 286 | 73.8% | 714 | 62.6% | +11.2 (+5.0 to +17.4) **\*** |
| nightwatch | 238 | 72.7% | 762 | 63.6% | +9.0 (+2.4 to +15.7) **\*** |
| veteran | 73 | 74.0% | 927 | 65.2% | +8.8 (-1.7 to +19.3) |
| warden | 229 | 72.1% | 771 | 63.9% | +8.1 (+1.4 to +14.8) **\*** |
| surveyor | 508 | 69.7% | 492 | 61.8% | +7.9 (+2.0 to +13.8) **\*** |
| monitor | 73 | 58.9% | 927 | 66.3% | -7.4 (-19.1 to +4.3) |
| confessor | 224 | 60.3% | 776 | 67.4% | -7.1 (-14.3 to +0.1) |
| archivist | 548 | 62.6% | 452 | 69.7% | -7.1 (-13.0 to -1.2) **\*** |
| sexton | 74 | 59.5% | 926 | 66.3% | -6.8 (-18.4 to +4.7) |
| executor | 87 | 59.8% | 913 | 66.4% | -6.6 (-17.4 to +4.1) |
| martyr | 88 | 60.2% | 912 | 66.3% | -6.1 (-16.8 to +4.6) |
| gravedigger | 283 | 61.8% | 717 | 67.4% | -5.5 (-12.1 to +1.1) |
| lamplighter | 203 | 62.6% | 797 | 66.6% | -4.1 (-11.5 to +3.4) |
| rumormonger | 504 | 63.9% | 496 | 67.7% | -3.9 (-9.7 to +2.0) |
| registrar | 270 | 63.3% | 730 | 66.7% | -3.4 (-10.1 to +3.3) |
| seer | 170 | 67.6% | 830 | 65.4% | +2.2 (-5.5 to +10.0) |
| augur | 193 | 64.2% | 807 | 66.2% | -1.9 (-9.4 to +5.6) |
| clerk | 545 | 66.6% | 455 | 64.8% | +1.8 (-4.1 to +7.7) |
| psychologist | 67 | 67.2% | 933 | 65.7% | +1.5 (-10.2 to +13.1) |
| chronicler | 76 | 64.5% | 924 | 65.9% | -1.4 (-12.6 to +9.8) |
| medium | 188 | 66.0% | 812 | 65.8% | +0.2 (-7.3 to +7.7) |
| magistrate | 73 | 65.8% | 927 | 65.8% | -0.1 (-11.4 to +11.3) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 80.4% | 781 | 61.7% | +18.6 (+12.4 to +24.9) **\*** |
| revenant | 221 | 57.9% | 779 | 68.0% | -10.1 (-17.4 to -2.8) **\*** |
| poisoner | 325 | 60.6% | 675 | 68.3% | -7.7 (-14.0 to -1.3) **\*** |
| scion | 235 | 66.8% | 765 | 65.5% | +1.3 (-5.6 to +8.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 61.3% | 788 | 67.0% | -5.7 (-13.0 to +1.6) |
| sleepwalker | 186 | 69.9% | 814 | 64.9% | +5.0 (-2.3 to +12.4) |
| lovers | 208 | 67.3% | 792 | 65.4% | +1.9 (-5.3 to +9.1) |
| muddler | 199 | 64.3% | 801 | 66.2% | -1.8 (-9.3 to +5.6) |
| marked | 195 | 66.7% | 805 | 65.6% | +1.1 (-6.3 to +8.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 69.8% | 957 | 65.6% | +4.1 (-9.9 to +18.2) |
| 3 night-walkers | 321 | 63.2% | 679 | 67.0% | -3.8 (-10.1 to +2.6) |
| 2 night-walkers | 636 | 66.8% | 364 | 64.0% | +2.8 (-3.3 to +9.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.5 | 56.0% | 14.6% | 94.9% |
| clerk | 545 | 2.1 | 21.3% | 11.4% | 89.7% |
| surveyor | 508 | 2.0 | 24.8% | 9.3% | 92.1% |
| rumormonger | 504 | 2.1 | 22.8% | 13.1% | 90.3% |
| dowser | 286 | 1.8 | 46.9% | 7.3% | 87.4% |
| gravedigger | 283 | 2.0 | 41.0% | 12.0% | 85.9% |
| registrar | 270 | 2.0 | 39.3% | 6.3% | 74.1% |
| nightwatch | 238 | 1.9 | 33.2% | 13.4% | 84.5% |
| warden | 229 | 2.1 | 21.0% | 18.8% | 78.2% |
| confessor | 224 | 2.0 | 25.0% | 25.4% | 83.9% |
| lamplighter | 203 | 2.1 | 20.2% | 13.3% | 85.2% |
| augur | 193 | 2.1 | 28.0% | 13.0% | 82.4% |
| medium | 188 | 2.1 | 29.8% | 9.0% | 75.5% |
| seer | 170 | 1.9 | 45.3% | 8.2% | 82.4% |
| martyr | 88 | 2.4 | 14.8% | 13.6% | 85.2% |
| executor | 87 | 2.2 | 28.7% | 4.6% | 77.0% |
| chronicler | 76 | 2.2 | 30.3% | 14.5% | 76.3% |
| sexton | 74 | 2.4 | 13.5% | 10.8% | 68.9% |
| veteran | 73 | 2.8 | 4.1% | 15.1% | 89.0% |
| magistrate | 73 | 2.0 | 31.5% | 4.1% | 84.9% |
| monitor | 73 | 2.1 | 34.2% | 8.2% | 83.6% |
| psychologist | 67 | 2.3 | 22.4% | 17.9% | 79.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 147 | 0.0% | 57.8% |
| nightwatch | 140 | 0.0% | 62.1% |
| dowser | 139 | 0.0% | 64.0% |
| confessor | 132 | 0.0% | 69.7% |
| lamplighter | 130 | 0.0% | 77.7% |
| medium | 126 | 0.0% | 57.9% |
| gravedigger | 116 | 0.0% | 62.9% |
| surveyor | 112 | 0.0% | 58.9% |
| rumormonger | 109 | 0.0% | 67.9% |
| clerk | 105 | 0.0% | 59.0% |
| archivist | 100 | 0.0% | 74.0% |
| chronicler | 79 | 0.0% | 51.9% |
| seer | 78 | 0.0% | 46.2% |
| psychologist | 78 | 0.0% | 64.1% |
| magistrate | 78 | 0.0% | 57.7% |
| executor | 76 | 0.0% | 48.7% |
| augur | 73 | 0.0% | 60.3% |
| monitor | 65 | 0.0% | 44.6% |
| martyr | 18 | 0.0% | 44.4% |
| warden | 18 | 0.0% | 61.1% |
| veteran | 16 | 0.0% | 31.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 80.4% | 781 | 61.7% | +18.6 (+12.4 to +24.9) |
| demon + dowser | 286 | 73.8% | 714 | 62.6% | +11.2 (+5.0 to +17.4) |
| demon + revenant | 221 | 57.9% | 779 | 68.0% | -10.1 (-17.4 to -2.8) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| psychologist | 67 | 28.4% | 933 | 42.8% | -14.4 (-25.7 to -3.2) **\*** |
| nightwatch | 238 | 52.5% | 762 | 38.5% | +14.1 (+6.8 to +21.3) **\*** |
| martyr | 88 | 29.5% | 912 | 43.0% | -13.4 (-23.5 to -3.4) **\*** |
| magistrate | 73 | 53.4% | 927 | 40.9% | +12.5 (+0.7 to +24.4) **\*** |
| gravedigger | 283 | 33.6% | 717 | 45.0% | -11.5 (-18.1 to -4.9) **\*** |
| augur | 193 | 34.2% | 807 | 43.6% | -9.4 (-16.9 to -1.9) **\*** |
| registrar | 270 | 48.5% | 730 | 39.3% | +9.2 (+2.3 to +16.1) **\*** |
| medium | 188 | 34.6% | 812 | 43.5% | -8.9 (-16.5 to -1.3) **\*** |
| sexton | 74 | 33.8% | 926 | 42.4% | -8.7 (-19.9 to +2.6) |
| warden | 229 | 48.5% | 771 | 39.8% | +8.7 (+1.3 to +16.0) **\*** |
| dowser | 286 | 47.9% | 714 | 39.4% | +8.5 (+1.7 to +15.4) **\*** |
| monitor | 73 | 34.2% | 927 | 42.4% | -8.1 (-19.5 to +3.2) |
| surveyor | 508 | 44.9% | 492 | 38.6% | +6.3 (+0.2 to +12.4) **\*** |
| archivist | 548 | 39.1% | 452 | 45.1% | -6.1 (-12.2 to +0.1) |
| chronicler | 76 | 39.5% | 924 | 42.0% | -2.5 (-14.0 to +8.9) |
| rumormonger | 504 | 40.7% | 496 | 42.9% | -2.3 (-8.4 to +3.8) |
| clerk | 545 | 42.8% | 455 | 40.7% | +2.1 (-4.0 to +8.2) |
| executor | 87 | 40.2% | 913 | 41.9% | -1.7 (-12.5 to +9.1) |
| seer | 170 | 42.9% | 830 | 41.6% | +1.4 (-6.8 to +9.5) |
| lamplighter | 203 | 40.9% | 797 | 42.0% | -1.1 (-8.7 to +6.4) |
| confessor | 224 | 42.4% | 776 | 41.6% | +0.8 (-6.6 to +8.1) |
| veteran | 73 | 41.1% | 927 | 41.9% | -0.8 (-12.5 to +11.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 60.7% | 781 | 36.5% | +24.2 (+16.9 to +31.5) **\*** |
| poisoner | 325 | 32.3% | 675 | 46.4% | -14.1 (-20.4 to -7.7) **\*** |
| revenant | 221 | 35.3% | 779 | 43.6% | -8.4 (-15.6 to -1.2) **\*** |
| scion | 235 | 43.4% | 765 | 41.3% | +2.1 (-5.1 to +9.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 30.2% | 788 | 44.9% | -14.7 (-21.8 to -7.6) **\*** |
| lovers | 208 | 48.1% | 792 | 40.2% | +7.9 (+0.3 to +15.5) **\*** |
| muddler | 199 | 47.2% | 801 | 40.4% | +6.8 (-0.9 to +14.5) |
| sleepwalker | 186 | 45.7% | 814 | 40.9% | +4.8 (-3.1 to +12.7) |
| marked | 195 | 38.5% | 805 | 42.6% | -4.1 (-11.8 to +3.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 39.5% | 957 | 41.9% | -2.4 (-17.3 to +12.6) |
| 2 night-walkers | 636 | 42.3% | 364 | 40.9% | +1.4 (-5.0 to +7.7) |
| 3 night-walkers | 321 | 41.1% | 679 | 42.1% | -1.0 (-7.5 to +5.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 57.5% | 19.0% | 94.3% |
| clerk | 545 | 2.4 | 24.0% | 20.0% | 91.4% |
| surveyor | 508 | 2.4 | 25.6% | 20.3% | 93.3% |
| rumormonger | 504 | 2.6 | 21.4% | 22.2% | 95.2% |
| dowser | 286 | 1.9 | 54.5% | 7.3% | 90.2% |
| gravedigger | 283 | 2.3 | 36.4% | 19.4% | 89.0% |
| registrar | 270 | 2.3 | 40.0% | 6.7% | 84.1% |
| nightwatch | 238 | 2.1 | 40.8% | 10.5% | 87.4% |
| warden | 229 | 2.5 | 29.3% | 14.4% | 79.9% |
| confessor | 224 | 2.2 | 38.4% | 11.6% | 83.5% |
| lamplighter | 203 | 2.4 | 30.5% | 12.3% | 85.2% |
| augur | 193 | 2.6 | 31.6% | 19.2% | 87.6% |
| medium | 188 | 2.3 | 34.6% | 13.3% | 83.0% |
| seer | 170 | 2.0 | 52.4% | 8.8% | 82.4% |
| martyr | 88 | 2.6 | 15.9% | 20.5% | 84.1% |
| executor | 87 | 2.5 | 33.3% | 12.6% | 82.8% |
| chronicler | 76 | 2.4 | 30.3% | 25.0% | 80.3% |
| sexton | 74 | 2.6 | 25.7% | 17.6% | 71.6% |
| magistrate | 73 | 2.4 | 41.1% | 9.6% | 93.2% |
| monitor | 73 | 2.3 | 35.6% | 8.2% | 79.5% |
| veteran | 73 | 3.5 | 5.5% | 31.5% | 89.0% |
| psychologist | 67 | 2.6 | 29.9% | 17.9% | 91.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 146 | 0.0% | 43.2% |
| nightwatch | 142 | 0.0% | 31.0% |
| dowser | 139 | 0.0% | 47.5% |
| confessor | 135 | 0.0% | 45.9% |
| lamplighter | 130 | 0.0% | 41.5% |
| medium | 127 | 0.0% | 37.8% |
| gravedigger | 120 | 0.0% | 54.2% |
| surveyor | 113 | 0.0% | 49.6% |
| rumormonger | 109 | 0.0% | 51.4% |
| clerk | 105 | 0.0% | 50.5% |
| archivist | 101 | 0.0% | 65.3% |
| psychologist | 80 | 0.0% | 53.8% |
| magistrate | 79 | 0.0% | 46.8% |
| executor | 78 | 0.0% | 41.0% |
| chronicler | 77 | 0.0% | 49.4% |
| augur | 75 | 0.0% | 49.3% |
| seer | 75 | 0.0% | 34.7% |
| monitor | 66 | 0.0% | 15.2% |
| warden | 19 | 0.0% | 42.1% |
| martyr | 18 | 0.0% | 22.2% |
| veteran | 15 | 0.0% | 13.3% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 60.7% | 781 | 36.5% | +24.2 (+16.9 to +31.5) |
| demon + nightwatch | 238 | 52.5% | 762 | 38.5% | +14.1 (+6.8 to +21.3) |
| demon + poisoner | 325 | 32.3% | 675 | 46.4% | -14.1 (-20.4 to -7.7) |
| demon + gravedigger | 283 | 33.6% | 717 | 45.0% | -11.5 (-18.1 to -4.9) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 136 | 50.0% | 863 | 64.7% | -14.7 (-23.6 to -5.7) **\*** |
| monitor | 144 | 71.5% | 855 | 61.2% | +10.4 (+2.3 to +18.4) **\*** |
| confessor | 389 | 57.1% | 610 | 66.2% | -9.2 (-15.3 to -3.0) **\*** |
| psychologist | 148 | 68.9% | 851 | 61.6% | +7.3 (-0.8 to +15.5) |
| executor | 147 | 57.1% | 852 | 63.6% | -6.5 (-15.1 to +2.2) |
| nightwatch | 396 | 66.4% | 603 | 60.2% | +6.2 (+0.1 to +12.3) **\*** |
| warden | 376 | 65.4% | 623 | 61.0% | +4.4 (-1.7 to +10.6) |
| surveyor | 588 | 60.9% | 411 | 65.2% | -4.3 (-10.4 to +1.7) |
| veteran | 171 | 65.5% | 828 | 62.1% | +3.4 (-4.4 to +11.3) |
| medium | 384 | 60.7% | 615 | 63.9% | -3.2 (-9.4 to +3.0) |
| dowser | 372 | 64.5% | 627 | 61.6% | +3.0 (-3.2 to +9.1) |
| magistrate | 135 | 65.2% | 864 | 62.3% | +2.9 (-5.7 to +11.6) |
| rumormonger | 589 | 63.7% | 410 | 61.2% | +2.4 (-3.7 to +8.6) |
| seer | 225 | 61.3% | 774 | 63.0% | -1.7 (-8.9 to +5.5) |
| archivist | 562 | 63.3% | 437 | 61.8% | +1.6 (-4.5 to +7.6) |
| lamplighter | 381 | 63.5% | 618 | 62.1% | +1.4 (-4.8 to +7.5) |
| registrar | 377 | 61.8% | 622 | 63.2% | -1.4 (-7.6 to +4.8) |
| augur | 231 | 61.9% | 768 | 62.9% | -1.0 (-8.1 to +6.1) |
| martyr | 156 | 63.5% | 843 | 62.5% | +0.9 (-7.3 to +9.2) |
| clerk | 581 | 62.3% | 418 | 63.2% | -0.9 (-6.9 to +5.2) |
| sexton | 148 | 62.2% | 851 | 62.7% | -0.6 (-9.0 to +7.9) |
| gravedigger | 357 | 62.5% | 642 | 62.8% | -0.3 (-6.6 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 440 | 74.1% | 559 | 53.7% | +20.4 (+14.6 to +26.2) **\*** |
| scion | 467 | 55.0% | 532 | 69.4% | -14.3 (-20.3 to -8.4) **\*** |
| poisoner | 620 | 60.3% | 379 | 66.5% | -6.2 (-12.3 to -0.1) **\*** |
| revenant | 471 | 62.6% | 528 | 62.7% | -0.1 (-6.1 to +6.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 215 | 53.5% | 784 | 65.2% | -11.7 (-19.1 to -4.2) **\*** |
| muddler | 191 | 68.6% | 808 | 61.3% | +7.3 (-0.1 to +14.7) |
| marked | 191 | 68.1% | 808 | 61.4% | +6.7 (-0.7 to +14.1) |
| sleepwalker | 207 | 58.9% | 792 | 63.6% | -4.7 (-12.2 to +2.8) |
| lovers | 195 | 65.6% | 804 | 61.9% | +3.7 (-3.8 to +11.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 56.0% | 908 | 63.3% | -7.3 (-18.0 to +3.4) |
| 3 night-walkers | 542 | 64.4% | 457 | 60.6% | +3.8 (-2.2 to +9.8) |
| 4 night-walkers | 366 | 61.7% | 633 | 63.2% | -1.4 (-7.7 to +4.8) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 589 | 3.2 | 13.1% | 14.8% | 94.9% |
| surveyor | 588 | 3.0 | 18.2% | 15.5% | 93.4% |
| clerk | 581 | 3.0 | 13.6% | 12.9% | 94.3% |
| archivist | 562 | 1.9 | 51.1% | 11.7% | 94.3% |
| nightwatch | 396 | 2.3 | 29.8% | 17.2% | 88.1% |
| confessor | 389 | 2.7 | 20.6% | 26.2% | 91.0% |
| medium | 384 | 2.8 | 21.9% | 9.9% | 87.0% |
| lamplighter | 381 | 2.8 | 18.4% | 15.5% | 92.4% |
| registrar | 377 | 2.6 | 30.0% | 6.4% | 84.6% |
| warden | 376 | 3.0 | 13.0% | 20.5% | 86.2% |
| dowser | 372 | 2.1 | 46.8% | 8.9% | 92.2% |
| gravedigger | 357 | 2.4 | 30.3% | 11.2% | 88.0% |
| augur | 231 | 2.7 | 28.1% | 9.5% | 84.0% |
| seer | 225 | 2.3 | 39.1% | 12.0% | 89.8% |
| veteran | 171 | 3.8 | 1.2% | 19.9% | 90.6% |
| martyr | 156 | 3.3 | 8.3% | 12.8% | 87.8% |
| sexton | 148 | 3.2 | 9.5% | 23.0% | 75.0% |
| psychologist | 148 | 2.7 | 24.3% | 11.5% | 85.8% |
| executor | 147 | 2.9 | 23.1% | 8.8% | 88.4% |
| monitor | 144 | 2.9 | 15.3% | 10.4% | 81.9% |
| chronicler | 136 | 2.9 | 24.3% | 12.5% | 87.5% |
| magistrate | 135 | 2.5 | 28.1% | 12.6% | 79.3% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 217 | 0.0% | 51.2% |
| dowser | 202 | 0.0% | 71.3% |
| archivist | 197 | 0.0% | 59.9% |
| gravedigger | 194 | 0.0% | 60.3% |
| clerk | 189 | 0.0% | 55.6% |
| rumormonger | 181 | 0.0% | 55.2% |
| confessor | 180 | 0.0% | 70.0% |
| surveyor | 173 | 0.0% | 59.0% |
| medium | 166 | 0.0% | 55.4% |
| lamplighter | 163 | 0.0% | 68.7% |
| nightwatch | 160 | 0.0% | 61.9% |
| magistrate | 125 | 0.0% | 61.6% |
| augur | 121 | 0.0% | 56.2% |
| psychologist | 110 | 0.0% | 46.4% |
| monitor | 108 | 0.0% | 38.0% |
| chronicler | 108 | 0.0% | 62.0% |
| seer | 104 | 0.0% | 45.2% |
| executor | 99 | 0.0% | 48.5% |
| sexton | 31 | 0.0% | 45.2% |
| veteran | 29 | 0.0% | 51.7% |
| warden | 21 | 0.0% | 61.9% |
| martyr | 20 | 0.0% | 40.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 440 | 74.1% | 559 | 53.7% | +20.4 (+14.6 to +26.2) |
| breathstealer + rumormonger | 263 | 77.6% | 736 | 57.3% | +20.2 (+14.1 to +26.4) |
| poisoner + scion | 215 | 47.0% | 784 | 67.0% | -20.0 (-27.4 to -12.5) |
| archivist + breathstealer | 242 | 74.8% | 757 | 58.8% | +16.0 (+9.5 to +22.5) |
| demon + scion | 467 | 55.0% | 532 | 69.4% | -14.3 (-20.3 to -8.4) |
| breathstealer + clerk | 253 | 73.1% | 746 | 59.1% | +14.0 (+7.5 to +20.5) |
| scion + surveyor | 267 | 52.8% | 732 | 66.3% | -13.4 (-20.3 to -6.5) |
| confessor + poisoner | 220 | 52.3% | 779 | 65.6% | -13.3 (-20.7 to -5.9) |
| breathstealer + surveyor | 261 | 71.6% | 738 | 59.5% | +12.2 (+5.6 to +18.7) |
| rumormonger + scion | 276 | 54.0% | 723 | 66.0% | -12.0 (-18.8 to -5.2) |
| clerk + scion | 273 | 54.2% | 726 | 65.8% | -11.6 (-18.5 to -4.8) |
| confessor + surveyor | 217 | 53.9% | 782 | 65.1% | -11.2 (-18.6 to -3.7) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 396 | 49.2% | 604 | 36.4% | +12.8 (+6.6 to +19.1) **\*** |
| martyr | 156 | 34.6% | 844 | 42.8% | -8.2 (-16.3 to +0.0) |
| veteran | 172 | 35.5% | 828 | 42.8% | -7.3 (-15.2 to +0.6) |
| gravedigger | 358 | 37.2% | 642 | 43.9% | -6.8 (-13.1 to -0.5) **\*** |
| augur | 231 | 36.8% | 769 | 42.9% | -6.1 (-13.3 to +1.0) |
| medium | 384 | 38.0% | 616 | 43.7% | -5.6 (-11.9 to +0.6) |
| dowser | 372 | 44.1% | 628 | 40.0% | +4.1 (-2.2 to +10.5) |
| rumormonger | 590 | 43.1% | 410 | 39.3% | +3.8 (-2.4 to +10.0) |
| warden | 377 | 43.5% | 623 | 40.3% | +3.2 (-3.1 to +9.5) |
| executor | 147 | 38.8% | 853 | 42.0% | -3.2 (-11.7 to +5.4) |
| psychologist | 148 | 43.9% | 852 | 41.1% | +2.8 (-5.8 to +11.5) |
| sexton | 148 | 43.9% | 852 | 41.1% | +2.8 (-5.8 to +11.5) |
| archivist | 563 | 40.5% | 437 | 42.8% | -2.3 (-8.5 to +3.9) |
| monitor | 144 | 39.6% | 856 | 41.8% | -2.2 (-10.9 to +6.4) |
| surveyor | 588 | 40.6% | 412 | 42.7% | -2.1 (-8.3 to +4.1) |
| registrar | 377 | 42.7% | 623 | 40.8% | +1.9 (-4.4 to +8.2) |
| confessor | 389 | 42.7% | 611 | 40.8% | +1.9 (-4.4 to +8.2) |
| seer | 225 | 42.7% | 775 | 41.2% | +1.5 (-5.8 to +8.8) |
| lamplighter | 382 | 42.1% | 618 | 41.1% | +1.0 (-5.2 to +7.3) |
| chronicler | 137 | 41.6% | 863 | 41.5% | +0.1 (-8.8 to +9.0) |
| clerk | 581 | 41.5% | 419 | 41.5% | -0.0 (-6.2 to +6.1) |
| magistrate | 135 | 41.5% | 865 | 41.5% | -0.0 (-9.0 to +8.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 441 | 59.2% | 559 | 27.5% | +31.6 (+25.7 to +37.5) **\*** |
| poisoner | 620 | 36.1% | 380 | 50.3% | -14.1 (-20.4 to -7.8) **\*** |
| revenant | 472 | 36.0% | 528 | 46.4% | -10.4 (-16.5 to -4.3) **\*** |
| scion | 467 | 37.5% | 533 | 45.0% | -7.6 (-13.6 to -1.5) **\*** |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 191 | 47.1% | 809 | 40.2% | +6.9 (-0.9 to +14.8) |
| delusional | 216 | 36.1% | 784 | 43.0% | -6.9 (-14.2 to +0.4) |
| sleepwalker | 207 | 36.7% | 793 | 42.7% | -6.0 (-13.4 to +1.4) |
| lovers | 195 | 45.1% | 805 | 40.6% | +4.5 (-3.3 to +12.3) |
| muddler | 191 | 43.5% | 809 | 41.0% | +2.4 (-5.4 to +10.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 91 | 44.0% | 909 | 41.3% | +2.7 (-8.0 to +13.4) |
| 4 night-walkers | 366 | 39.9% | 634 | 42.4% | -2.5 (-8.9 to +3.8) |
| 3 night-walkers | 543 | 42.2% | 457 | 40.7% | +1.5 (-4.7 to +7.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 590 | 3.4 | 15.3% | 20.3% | 94.4% |
| surveyor | 588 | 3.4 | 15.8% | 20.4% | 94.9% |
| clerk | 581 | 3.4 | 12.4% | 23.4% | 94.8% |
| archivist | 563 | 2.0 | 56.3% | 13.9% | 94.3% |
| nightwatch | 396 | 2.5 | 34.6% | 20.2% | 90.4% |
| confessor | 389 | 2.8 | 26.0% | 20.6% | 92.3% |
| medium | 384 | 2.9 | 24.2% | 15.1% | 89.8% |
| lamplighter | 382 | 3.0 | 20.2% | 17.0% | 91.4% |
| registrar | 377 | 2.8 | 29.2% | 10.1% | 87.5% |
| warden | 377 | 3.2 | 18.3% | 25.5% | 89.7% |
| dowser | 372 | 2.1 | 52.2% | 9.4% | 93.8% |
| gravedigger | 358 | 2.7 | 32.4% | 18.2% | 93.3% |
| augur | 231 | 3.1 | 22.9% | 19.5% | 87.9% |
| seer | 225 | 2.3 | 42.2% | 14.2% | 88.9% |
| veteran | 172 | 4.3 | 2.3% | 32.0% | 90.1% |
| martyr | 156 | 3.9 | 9.0% | 17.9% | 92.3% |
| sexton | 148 | 3.7 | 6.8% | 29.7% | 85.8% |
| psychologist | 148 | 3.0 | 19.6% | 17.6% | 87.2% |
| executor | 147 | 3.3 | 19.0% | 13.6% | 86.4% |
| monitor | 144 | 3.2 | 17.4% | 6.9% | 88.2% |
| chronicler | 137 | 3.2 | 15.3% | 13.9% | 94.2% |
| magistrate | 135 | 2.7 | 30.4% | 12.6% | 84.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 214 | 0.0% | 45.8% |
| dowser | 205 | 0.0% | 53.7% |
| archivist | 198 | 0.0% | 58.1% |
| gravedigger | 197 | 0.0% | 60.4% |
| clerk | 189 | 0.0% | 49.2% |
| rumormonger | 183 | 0.0% | 46.4% |
| confessor | 181 | 0.0% | 54.7% |
| surveyor | 176 | 0.0% | 48.9% |
| nightwatch | 168 | 0.0% | 39.9% |
| medium | 165 | 0.0% | 44.2% |
| lamplighter | 164 | 0.0% | 50.6% |
| magistrate | 131 | 0.0% | 58.0% |
| augur | 123 | 0.0% | 40.7% |
| chronicler | 110 | 0.0% | 43.6% |
| monitor | 109 | 0.0% | 26.6% |
| psychologist | 107 | 0.0% | 44.9% |
| seer | 104 | 0.0% | 44.2% |
| executor | 98 | 0.0% | 32.7% |
| sexton | 34 | 0.0% | 35.3% |
| veteran | 31 | 0.0% | 35.5% |
| warden | 21 | 0.0% | 33.3% |
| martyr | 21 | 0.0% | 47.6% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 441 | 59.2% | 559 | 27.5% | +31.6 (+25.7 to +37.5) |
| breathstealer + clerk | 253 | 60.5% | 747 | 35.1% | +25.4 (+18.5 to +32.3) |
| breathstealer + rumormonger | 264 | 58.7% | 736 | 35.3% | +23.4 (+16.5 to +30.3) |
| poisoner + scion | 215 | 23.7% | 785 | 46.4% | -22.6 (-29.3 to -16.0) |
| archivist + breathstealer | 243 | 58.4% | 757 | 36.1% | +22.4 (+15.3 to +29.5) |
| breathstealer + surveyor | 261 | 57.1% | 739 | 36.0% | +21.1 (+14.2 to +28.0) |
| poisoner + revenant | 214 | 27.6% | 786 | 45.3% | -17.7 (-24.6 to -10.8) |
| gravedigger + poisoner | 221 | 30.3% | 779 | 44.7% | -14.4 (-21.3 to -7.4) |
| demon + poisoner | 620 | 36.1% | 380 | 50.3% | -14.1 (-20.4 to -7.8) |
| nightwatch + rumormonger | 227 | 51.5% | 773 | 38.6% | +13.0 (+5.6 to +20.3) |
| demon + nightwatch | 396 | 49.2% | 604 | 36.4% | +12.8 (+6.6 to +19.1) |
| clerk + nightwatch | 225 | 51.1% | 775 | 38.7% | +12.4 (+5.0 to +19.8) |
| archivist + revenant | 274 | 33.6% | 726 | 44.5% | -10.9 (-17.6 to -4.3) |
| demon + revenant | 472 | 36.0% | 528 | 46.4% | -10.4 (-16.5 to -4.3) |
| archivist + nightwatch | 225 | 49.3% | 775 | 39.2% | +10.1 (+2.7 to +17.5) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 1000 | 330 (33.0%) | 90 (9.0%) | 328 | 252 |
| 10 | 10 NPCs, bot insight 1.0 | 999 | 322 (32.2%) | 111 (11.1%) | 304 | 262 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 1 — seeds 100429 (timeout)
- Games with engine errors: 0
- Shared-model fallbacks: 12 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 64.7 | 127.8 | 300.3 |
| 7 NPCs, passive | 3.7 | 5.7 | 15.3 |
| 10 NPCs, bot insight 1.0 | 323.1 | 675.9 | 1723.8 |
| 10 NPCs, passive | 39.3 | 72.6 | 166.8 |

Slowest seeds: 100339 (10 NPCs bot, 1724 s), 100428 (10 NPCs bot, 1711 s), 100308 (10 NPCs bot, 1439 s), 100466 (10 NPCs bot, 1227 s), 100105 (10 NPCs bot, 1225 s), 100654 (10 NPCs bot, 1124 s), 100465 (10 NPCs bot, 1084 s), 100714 (10 NPCs bot, 1074 s), 100986 (10 NPCs bot, 1071 s), 100449 (10 NPCs bot, 1069 s), 100345 (10 NPCs bot, 1067 s), 100826 (10 NPCs bot, 1065 s), 100712 (10 NPCs bot, 1056 s), 100363 (10 NPCs bot, 1052 s), 100828 (10 NPCs bot, 1050 s), 100780 (10 NPCs bot, 1039 s), 100425 (10 NPCs bot, 1035 s), 100332 (10 NPCs bot, 1014 s), 100542 (10 NPCs bot, 979 s), 100702 (10 NPCs bot, 962 s)

