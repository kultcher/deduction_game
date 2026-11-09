# Balance sweep report

Records: 10734 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `0ca86540cd`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 978 | 59.7% (56.6%–62.7%) | 3.19 | 0.63 | 1.08 | 2.38 | 7.5% | 0.23 |
| 7 NPCs, bot (pre-M4) insight 1.0 | 1756 | 58.4% (56.1%–60.7%) | 3.11 | 0.72 | 1.06 | 2.37 | 8.9% | 0.24 |
| 7 NPCs, passive | 2000 | 34.8% (32.7%–36.9%) | 3.55 | 0.92 | 0.75 | 2.43 | 3.3% | 0.25 |
| 10 NPCs, bot insight 1.0 | 2000 | 55.8% (53.6%–57.9%) | 4.35 | 1.02 | 1.59 | 2.59 | 7.0% | 0.42 |
| 10 NPCs, bot (pre-M4) insight 1.0 | 2000 | 50.9% (48.7%–53.1%) | 4.37 | 1.15 | 1.54 | 2.62 | 7.4% | 0.45 |
| 10 NPCs, passive | 2000 | 28.7% (26.8%–30.8%) | 4.78 | 1.50 | 1.10 | 2.74 | 3.4% | 0.60 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=978)

- The demon's host was executed.: 584 (59.7%)
- Only two townsfolk remain and the demon still walks among them.: 394 (40.3%)
- Demon evidence on the board: 99.1% of games; good win rate 59.3% of 969
- Demon evidence reachable: 80.9% of games; good win rate 55.2% of 791
- Neither: 0.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot (pre-M4) insight 1.0** (n=1756)

- The demon's host was executed.: 1026 (58.4%)
- Only two townsfolk remain and the demon still walks among them.: 728 (41.5%)
- Time ran out: the demon survived 6 days.: 2 (0.1%)
- Demon evidence on the board: 98.6% of games; good win rate 57.9% of 1732
- Demon evidence reachable: 80.5% of games; good win rate 53.3% of 1413
- Neither: 0.9% of games; good win rate 100.0% of 15
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=2000)

- Only two townsfolk remain and the demon still walks among them.: 1302 (65.1%)
- The demon's host was executed.: 695 (34.8%)
- Time ran out: the demon survived 6 days.: 3 (0.1%)
- Demon evidence on the board: 59.9% of games; good win rate 43.5% of 1198
- Demon evidence reachable: 99.5% of games; good win rate 34.4% of 1990
- Neither: 0.3% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=2000)

- The demon's host was executed.: 1115 (55.8%)
- Only two townsfolk remain and the demon still walks among them.: 589 (29.4%)
- No good soul remains.: 294 (14.7%)
- Time ran out: the demon survived 8 days.: 2 (0.1%)
- Demon evidence on the board: 99.8% of games; good win rate 55.6% of 1995
- Demon evidence reachable: 90.0% of games; good win rate 53.3% of 1799
- Neither: 0.2% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot (pre-M4) insight 1.0** (n=2000)

- The demon's host was executed.: 1018 (50.9%)
- Only two townsfolk remain and the demon still walks among them.: 640 (32.0%)
- No good soul remains.: 339 (17.0%)
- Time ran out: the demon survived 8 days.: 3 (0.1%)
- Demon evidence on the board: 99.7% of games; good win rate 50.7% of 1993
- Demon evidence reachable: 90.0% of games; good win rate 48.8% of 1800
- Neither: 0.3% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=2000)

- No good soul remains.: 839 (41.9%)
- The demon's host was executed.: 575 (28.7%)
- Only two townsfolk remain and the demon still walks among them.: 574 (28.7%)
- Time ran out: the demon survived 8 days.: 12 (0.6%)
- Demon evidence on the board: 78.1% of games; good win rate 30.4% of 1562
- Demon evidence reachable: 100.0% of games; good win rate 28.7% of 2000
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sexton | 82 | 45.1% | 896 | 61.0% | -15.9 (-27.2 to -4.7) **\*** |
| gravedigger | 296 | 51.0% | 682 | 63.5% | -12.5 (-19.2 to -5.7) **\*** |
| dowser | 299 | 67.6% | 679 | 56.3% | +11.3 (+4.8 to +17.8) **\*** |
| psychologist | 60 | 68.3% | 918 | 59.2% | +9.2 (-3.0 to +21.4) |
| monitor | 69 | 68.1% | 909 | 59.1% | +9.0 (-2.4 to +20.5) |
| medium | 181 | 66.3% | 797 | 58.2% | +8.1 (+0.4 to +15.8) **\*** |
| lamplighter | 200 | 53.5% | 778 | 61.3% | -7.8 (-15.5 to -0.1) **\*** |
| warden | 233 | 55.8% | 745 | 60.9% | -5.1 (-12.4 to +2.1) |
| magistrate | 64 | 64.1% | 914 | 59.4% | +4.7 (-7.5 to +16.8) |
| martyr | 81 | 63.0% | 897 | 59.4% | +3.5 (-7.5 to +14.5) |
| archivist | 535 | 58.1% | 443 | 61.6% | -3.5 (-9.7 to +2.7) |
| augur | 183 | 62.3% | 795 | 59.1% | +3.2 (-4.6 to +11.0) |
| nightwatch | 231 | 61.9% | 747 | 59.0% | +2.9 (-4.3 to +10.1) |
| seer | 163 | 57.7% | 815 | 60.1% | -2.5 (-10.8 to +5.8) |
| veteran | 71 | 62.0% | 907 | 59.5% | +2.4 (-9.3 to +14.2) |
| executor | 70 | 61.4% | 908 | 59.6% | +1.8 (-10.0 to +13.7) |
| surveyor | 496 | 60.3% | 482 | 59.1% | +1.2 (-5.0 to +7.3) |
| registrar | 253 | 60.5% | 725 | 59.4% | +1.0 (-6.0 to +8.0) |
| chronicler | 68 | 58.8% | 910 | 59.8% | -1.0 (-13.1 to +11.2) |
| rumormonger | 526 | 60.1% | 452 | 59.3% | +0.8 (-5.4 to +7.0) |
| clerk | 528 | 59.8% | 450 | 59.6% | +0.3 (-5.9 to +6.5) |
| confessor | 201 | 59.7% | 777 | 59.7% | -0.0 (-7.6 to +7.6) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 217 | 71.0% | 761 | 56.5% | +14.5 (+7.5 to +21.5) **\*** |
| scion | 216 | 52.3% | 762 | 61.8% | -9.5 (-17.0 to -2.0) **\*** |
| poisoner | 331 | 56.5% | 647 | 61.4% | -4.9 (-11.4 to +1.7) |
| revenant | 214 | 60.7% | 764 | 59.4% | +1.3 (-6.1 to +8.7) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 199 | 50.8% | 779 | 62.0% | -11.2 (-19.0 to -3.5) **\*** |
| lovers | 213 | 65.7% | 765 | 58.0% | +7.7 (+0.4 to +15.0) **\*** |
| sleepwalker | 183 | 62.3% | 795 | 59.1% | +3.2 (-4.6 to +11.0) |
| marked | 185 | 61.6% | 793 | 59.3% | +2.4 (-5.4 to +10.2) |
| muddler | 198 | 58.1% | 780 | 60.1% | -2.0 (-9.7 to +5.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 45 | 42.2% | 933 | 60.6% | -18.3 (-33.1 to -3.6) **\*** |
| 2 night-walkers | 624 | 60.9% | 354 | 57.6% | +3.3 (-3.1 to +9.7) |
| 3 night-walkers | 309 | 59.9% | 669 | 59.6% | +0.2 (-6.4 to +6.8) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 535 | 1.7 | 54.6% | 12.0% | 94.0% |
| clerk | 528 | 2.2 | 20.8% | 11.9% | 91.9% |
| rumormonger | 526 | 2.4 | 19.6% | 15.4% | 92.4% |
| surveyor | 496 | 2.3 | 24.4% | 12.1% | 91.1% |
| dowser | 299 | 1.8 | 53.5% | 7.0% | 83.3% |
| gravedigger | 296 | 2.1 | 41.2% | 11.1% | 84.1% |
| registrar | 253 | 2.1 | 37.9% | 7.9% | 83.0% |
| warden | 233 | 2.6 | 19.3% | 19.3% | 78.5% |
| nightwatch | 231 | 2.0 | 37.2% | 15.2% | 84.8% |
| confessor | 201 | 1.9 | 32.8% | 18.9% | 82.6% |
| lamplighter | 200 | 2.2 | 28.0% | 9.5% | 83.5% |
| augur | 183 | 2.2 | 27.3% | 14.2% | 77.0% |
| medium | 181 | 2.0 | 31.5% | 10.5% | 78.5% |
| seer | 163 | 2.1 | 39.3% | 9.2% | 81.6% |
| sexton | 82 | 2.7 | 18.3% | 23.2% | 73.2% |
| martyr | 81 | 2.7 | 16.0% | 14.8% | 86.4% |
| veteran | 71 | 2.9 | 2.8% | 19.7% | 90.1% |
| executor | 70 | 2.5 | 27.1% | 10.0% | 78.6% |
| monitor | 69 | 2.2 | 29.0% | 5.8% | 72.5% |
| chronicler | 68 | 2.1 | 33.8% | 8.8% | 72.1% |
| magistrate | 64 | 2.2 | 32.8% | 6.2% | 68.8% |
| psychologist | 60 | 2.1 | 20.0% | 16.7% | 78.3% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 143 | 0.0% | 61.5% |
| confessor | 137 | 0.0% | 62.0% |
| lamplighter | 127 | 0.0% | 75.6% |
| medium | 122 | 0.0% | 33.6% |
| clerk | 120 | 0.0% | 51.7% |
| dowser | 119 | 0.0% | 61.3% |
| registrar | 117 | 0.0% | 50.4% |
| surveyor | 108 | 0.0% | 49.1% |
| rumormonger | 106 | 0.0% | 52.8% |
| gravedigger | 104 | 0.0% | 54.8% |
| archivist | 88 | 0.0% | 56.8% |
| executor | 86 | 0.0% | 57.0% |
| magistrate | 83 | 0.0% | 44.6% |
| monitor | 79 | 0.0% | 39.2% |
| chronicler | 79 | 0.0% | 55.7% |
| psychologist | 76 | 0.0% | 57.9% |
| augur | 74 | 0.0% | 60.8% |
| seer | 65 | 0.0% | 60.0% |
| warden | 17 | 0.0% | 76.5% |
| veteran | 15 | 0.0% | 66.7% |
| martyr | 13 | 0.0% | 23.1% |
| sexton | 12 | 0.0% | 25.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 217 | 71.0% | 761 | 56.5% | +14.5 (+7.5 to +21.5) |
| demon + gravedigger | 296 | 51.0% | 682 | 63.5% | -12.5 (-19.2 to -5.7) |
| demon + dowser | 299 | 67.6% | 679 | 56.3% | +11.3 (+4.8 to +17.8) |

### 7 NPCs, bot (pre-M4) insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| magistrate | 125 | 69.6% | 1631 | 57.6% | +12.0 (+3.6 to +20.4) **\*** |
| executor | 130 | 48.5% | 1626 | 59.2% | -10.8 (-19.7 to -1.8) **\*** |
| psychologist | 111 | 50.5% | 1645 | 59.0% | -8.5 (-18.1 to +1.1) |
| gravedigger | 515 | 53.6% | 1241 | 60.4% | -6.8 (-11.9 to -1.7) **\*** |
| archivist | 969 | 55.4% | 787 | 62.1% | -6.7 (-11.3 to -2.1) **\*** |
| dowser | 514 | 62.8% | 1242 | 56.6% | +6.2 (+1.2 to +11.2) **\*** |
| nightwatch | 409 | 63.1% | 1347 | 57.0% | +6.1 (+0.7 to +11.4) **\*** |
| clerk | 950 | 60.7% | 806 | 55.7% | +5.0 (+0.4 to +9.7) **\*** |
| martyr | 142 | 54.9% | 1614 | 58.7% | -3.8 (-12.3 to +4.7) |
| chronicler | 120 | 55.0% | 1636 | 58.7% | -3.7 (-12.9 to +5.5) |
| medium | 329 | 60.8% | 1427 | 57.9% | +2.9 (-3.0 to +8.8) |
| confessor | 384 | 56.5% | 1372 | 59.0% | -2.5 (-8.1 to +3.1) |
| warden | 417 | 60.2% | 1339 | 57.9% | +2.3 (-3.1 to +7.7) |
| sexton | 135 | 56.3% | 1621 | 58.6% | -2.3 (-11.0 to +6.4) |
| seer | 305 | 60.3% | 1451 | 58.0% | +2.3 (-3.8 to +8.3) |
| surveyor | 879 | 59.5% | 877 | 57.4% | +2.1 (-2.5 to +6.8) |
| registrar | 479 | 57.4% | 1277 | 58.8% | -1.4 (-6.6 to +3.8) |
| augur | 313 | 57.5% | 1443 | 58.6% | -1.1 (-7.2 to +4.9) |
| lamplighter | 373 | 57.6% | 1383 | 58.6% | -1.0 (-6.6 to +4.6) |
| rumormonger | 931 | 58.0% | 825 | 58.9% | -0.9 (-5.5 to +3.7) |
| monitor | 130 | 59.2% | 1626 | 58.4% | +0.9 (-7.9 to +9.6) |
| veteran | 120 | 59.2% | 1636 | 58.4% | +0.8 (-8.3 to +9.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 400 | 66.8% | 1356 | 56.0% | +10.8 (+5.5 to +16.1) **\*** |
| scion | 391 | 54.0% | 1365 | 59.7% | -5.7 (-11.3 to -0.2) **\*** |
| poisoner | 579 | 55.4% | 1177 | 59.9% | -4.5 (-9.4 to +0.5) |
| revenant | 386 | 58.8% | 1370 | 58.3% | +0.5 (-5.1 to +6.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 363 | 46.6% | 1393 | 61.5% | -15.0 (-20.7 to -9.2) **\*** |
| muddler | 349 | 64.8% | 1407 | 56.9% | +7.9 (+2.3 to +13.5) **\*** |
| lovers | 365 | 61.9% | 1391 | 57.5% | +4.4 (-1.2 to +10.0) |
| sleepwalker | 337 | 60.8% | 1419 | 57.9% | +3.0 (-2.8 to +8.8) |
| marked | 342 | 58.5% | 1414 | 58.4% | +0.1 (-5.8 to +5.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 87 | 64.4% | 1669 | 58.1% | +6.2 (-4.1 to +16.6) |
| 3 night-walkers | 561 | 57.8% | 1195 | 58.7% | -1.0 (-5.9 to +4.0) |
| 2 night-walkers | 1108 | 58.3% | 648 | 58.6% | -0.3 (-5.1 to +4.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 969 | 1.6 | 52.8% | 15.8% | 93.2% |
| clerk | 950 | 2.2 | 21.3% | 16.4% | 91.1% |
| rumormonger | 931 | 2.2 | 22.9% | 16.5% | 92.2% |
| surveyor | 879 | 2.1 | 26.8% | 14.4% | 90.8% |
| gravedigger | 515 | 2.0 | 37.3% | 14.4% | 84.3% |
| dowser | 514 | 1.7 | 51.8% | 9.3% | 84.4% |
| registrar | 479 | 2.1 | 33.6% | 9.8% | 77.0% |
| warden | 417 | 2.3 | 22.3% | 17.3% | 76.7% |
| nightwatch | 409 | 2.0 | 33.5% | 14.4% | 85.1% |
| confessor | 384 | 2.0 | 31.5% | 19.5% | 82.0% |
| lamplighter | 373 | 2.2 | 27.6% | 8.6% | 82.3% |
| medium | 329 | 2.1 | 31.0% | 11.6% | 77.8% |
| augur | 313 | 2.2 | 27.5% | 16.0% | 77.0% |
| seer | 305 | 2.0 | 40.7% | 10.2% | 82.0% |
| martyr | 142 | 2.3 | 20.4% | 12.0% | 78.9% |
| sexton | 135 | 2.4 | 20.0% | 17.0% | 64.4% |
| executor | 130 | 2.4 | 26.9% | 11.5% | 75.4% |
| monitor | 130 | 2.2 | 34.6% | 8.5% | 72.3% |
| magistrate | 125 | 2.3 | 28.0% | 12.0% | 77.6% |
| veteran | 120 | 2.8 | 8.3% | 19.2% | 87.5% |
| chronicler | 120 | 2.2 | 26.7% | 15.8% | 82.5% |
| psychologist | 111 | 2.5 | 21.6% | 15.3% | 82.9% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 244 | 0.0% | 55.7% |
| confessor | 236 | 0.0% | 62.3% |
| registrar | 236 | 0.0% | 55.9% |
| lamplighter | 228 | 0.0% | 62.7% |
| medium | 223 | 0.0% | 37.2% |
| dowser | 219 | 0.0% | 62.6% |
| surveyor | 206 | 0.0% | 54.4% |
| gravedigger | 196 | 0.0% | 62.2% |
| clerk | 195 | 0.0% | 54.9% |
| rumormonger | 186 | 0.0% | 53.2% |
| archivist | 172 | 0.0% | 62.2% |
| chronicler | 151 | 0.0% | 52.3% |
| psychologist | 143 | 0.0% | 49.0% |
| monitor | 137 | 0.0% | 38.7% |
| executor | 135 | 0.0% | 43.7% |
| magistrate | 135 | 0.0% | 46.7% |
| augur | 125 | 0.0% | 60.8% |
| seer | 124 | 0.0% | 46.8% |
| warden | 32 | 0.0% | 62.5% |
| veteran | 27 | 0.0% | 37.0% |
| martyr | 22 | 0.0% | 36.4% |
| sexton | 22 | 0.0% | 36.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + clerk | 217 | 71.4% | 1539 | 56.6% | +14.8 (+8.3 to +21.3) |
| breathstealer + demon | 400 | 66.8% | 1356 | 56.0% | +10.8 (+5.5 to +16.1) |
| clerk + nightwatch | 208 | 67.3% | 1548 | 57.2% | +10.1 (+3.2 to +16.9) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 464 | 46.6% | 1536 | 31.2% | +15.4 (+10.3 to +20.5) **\*** |
| dowser | 591 | 41.8% | 1409 | 31.8% | +10.0 (+5.3 to +14.7) **\*** |
| augur | 357 | 27.7% | 1643 | 36.3% | -8.5 (-13.7 to -3.4) **\*** |
| gravedigger | 583 | 30.0% | 1417 | 36.7% | -6.7 (-11.2 to -2.2) **\*** |
| veteran | 147 | 28.6% | 1853 | 35.2% | -6.7 (-14.3 to +1.0) |
| executor | 149 | 28.9% | 1851 | 35.2% | -6.4 (-14.0 to +1.2) |
| chronicler | 135 | 29.6% | 1865 | 35.1% | -5.5 (-13.5 to +2.5) |
| medium | 377 | 30.8% | 1623 | 35.7% | -4.9 (-10.1 to +0.3) |
| warden | 476 | 38.0% | 1524 | 33.7% | +4.3 (-0.7 to +9.3) |
| sexton | 155 | 31.0% | 1845 | 35.1% | -4.1 (-11.7 to +3.5) |
| lamplighter | 419 | 31.7% | 1581 | 35.5% | -3.8 (-8.8 to +1.2) |
| registrar | 539 | 37.1% | 1461 | 33.9% | +3.2 (-1.5 to +8.0) |
| rumormonger | 1069 | 34.0% | 931 | 35.7% | -1.7 (-5.9 to +2.5) |
| psychologist | 126 | 33.3% | 1874 | 34.8% | -1.5 (-10.0 to +7.0) |
| confessor | 433 | 33.7% | 1567 | 35.0% | -1.3 (-6.4 to +3.7) |
| seer | 351 | 33.9% | 1649 | 34.9% | -1.0 (-6.5 to +4.4) |
| monitor | 152 | 35.5% | 1848 | 34.7% | +0.8 (-7.1 to +8.8) |
| magistrate | 138 | 34.1% | 1862 | 34.8% | -0.7 (-8.9 to +7.5) |
| martyr | 161 | 35.4% | 1839 | 34.7% | +0.7 (-7.0 to +8.4) |
| clerk | 1076 | 35.0% | 924 | 34.4% | +0.6 (-3.6 to +4.8) |
| archivist | 1099 | 34.5% | 901 | 35.1% | -0.6 (-4.8 to +3.6) |
| surveyor | 1003 | 35.0% | 997 | 34.5% | +0.5 (-3.7 to +4.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 45.7% | 1540 | 31.5% | +14.2 (+9.0 to +19.3) **\*** |
| poisoner | 658 | 27.7% | 1342 | 38.2% | -10.6 (-14.9 to -6.3) **\*** |
| revenant | 447 | 27.3% | 1553 | 36.9% | -9.6 (-14.4 to -4.8) **\*** |
| scion | 435 | 41.6% | 1565 | 32.8% | +8.8 (+3.6 to +13.9) **\*** |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 424 | 21.0% | 1576 | 38.5% | -17.5 (-22.0 to -12.9) **\*** |
| sleepwalker | 385 | 41.3% | 1615 | 33.2% | +8.1 (+2.7 to +13.5) **\*** |
| lovers | 413 | 38.7% | 1587 | 33.7% | +5.0 (-0.2 to +10.3) |
| muddler | 392 | 37.2% | 1608 | 34.1% | +3.1 (-2.2 to +8.4) |
| marked | 386 | 36.5% | 1614 | 34.3% | +2.2 (-3.1 to +7.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 32.0% | 1903 | 34.9% | -2.9 (-12.5 to +6.6) |
| 2 night-walkers | 1270 | 35.2% | 730 | 34.0% | +1.2 (-3.1 to +5.5) |
| 3 night-walkers | 633 | 34.3% | 1367 | 35.0% | -0.7 (-5.2 to +3.8) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 1.8 | 58.3% | 20.6% | 93.7% |
| clerk | 1076 | 2.7 | 21.0% | 27.2% | 92.8% |
| rumormonger | 1069 | 2.6 | 22.6% | 24.5% | 93.9% |
| surveyor | 1003 | 2.6 | 26.5% | 23.9% | 94.4% |
| dowser | 591 | 1.9 | 58.2% | 10.0% | 88.5% |
| gravedigger | 583 | 2.2 | 44.8% | 14.9% | 86.6% |
| registrar | 539 | 2.3 | 41.6% | 10.8% | 82.6% |
| warden | 476 | 2.8 | 21.4% | 16.6% | 84.5% |
| nightwatch | 464 | 2.2 | 39.9% | 11.4% | 85.6% |
| confessor | 433 | 2.4 | 39.3% | 12.5% | 85.2% |
| lamplighter | 419 | 2.4 | 31.7% | 13.8% | 85.7% |
| medium | 377 | 2.4 | 35.0% | 11.9% | 82.5% |
| augur | 357 | 2.4 | 34.2% | 20.4% | 80.7% |
| seer | 351 | 2.1 | 53.3% | 9.1% | 86.0% |
| martyr | 161 | 2.9 | 14.3% | 23.6% | 88.8% |
| sexton | 155 | 2.8 | 19.4% | 25.2% | 73.5% |
| monitor | 152 | 2.3 | 39.5% | 5.3% | 78.3% |
| executor | 149 | 2.5 | 33.6% | 14.8% | 78.5% |
| veteran | 147 | 3.4 | 4.8% | 34.0% | 89.8% |
| magistrate | 138 | 2.3 | 35.5% | 13.0% | 80.4% |
| chronicler | 135 | 2.5 | 28.9% | 19.3% | 80.0% |
| psychologist | 126 | 2.5 | 27.0% | 19.0% | 86.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 281 | 0.0% | 20.6% |
| registrar | 279 | 0.0% | 39.4% |
| confessor | 273 | 0.0% | 37.7% |
| lamplighter | 265 | 0.0% | 39.6% |
| medium | 258 | 0.0% | 29.5% |
| dowser | 253 | 0.0% | 45.1% |
| clerk | 226 | 0.0% | 46.0% |
| surveyor | 225 | 0.0% | 39.6% |
| gravedigger | 221 | 0.0% | 52.5% |
| rumormonger | 214 | 0.0% | 40.2% |
| archivist | 202 | 0.0% | 46.5% |
| chronicler | 173 | 0.0% | 43.4% |
| executor | 161 | 0.0% | 32.9% |
| magistrate | 159 | 0.0% | 40.3% |
| psychologist | 159 | 0.0% | 40.9% |
| seer | 153 | 0.0% | 32.0% |
| monitor | 153 | 0.0% | 17.6% |
| augur | 136 | 0.0% | 43.4% |
| warden | 41 | 0.0% | 39.0% |
| veteran | 28 | 0.0% | 39.3% |
| martyr | 27 | 0.0% | 18.5% |
| sexton | 23 | 0.0% | 34.8% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch + surveyor | 230 | 48.7% | 1770 | 32.9% | +15.8 (+8.9 to +22.6) |
| demon + nightwatch | 464 | 46.6% | 1536 | 31.2% | +15.4 (+10.3 to +20.5) |
| archivist + revenant | 256 | 21.9% | 1744 | 36.6% | -14.8 (-20.3 to -9.2) |
| archivist + breathstealer | 254 | 47.6% | 1746 | 32.9% | +14.8 (+8.2 to +21.3) |
| breathstealer + demon | 460 | 45.7% | 1540 | 31.5% | +14.2 (+9.0 to +19.3) |
| nightwatch + rumormonger | 251 | 46.6% | 1749 | 33.0% | +13.6 (+7.0 to +20.1) |
| archivist + nightwatch | 249 | 46.6% | 1751 | 33.1% | +13.5 (+6.9 to +20.1) |
| breathstealer + surveyor | 220 | 46.4% | 1780 | 33.3% | +13.0 (+6.1 to +20.0) |
| archivist + scion | 233 | 45.9% | 1767 | 33.3% | +12.6 (+5.9 to +19.4) |
| clerk + nightwatch | 238 | 45.0% | 1762 | 33.4% | +11.6 (+4.9 to +18.3) |
| breathstealer + clerk | 252 | 44.8% | 1748 | 33.3% | +11.5 (+5.0 to +18.1) |
| gravedigger + poisoner | 218 | 24.8% | 1782 | 36.0% | -11.2 (-17.3 to -5.1) |
| clerk + warden | 254 | 44.5% | 1746 | 33.3% | +11.2 (+4.7 to +17.7) |
| clerk + dowser | 311 | 44.1% | 1689 | 33.0% | +11.0 (+5.1 to +17.0) |
| clerk + scion | 237 | 44.3% | 1763 | 33.5% | +10.8 (+4.1 to +17.5) |
| clerk + poisoner | 361 | 26.0% | 1639 | 36.7% | -10.6 (-15.7 to -5.5) |
| demon + poisoner | 658 | 27.7% | 1342 | 38.2% | -10.6 (-14.9 to -6.3) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 761 | 49.9% | 1239 | 59.3% | -9.4 (-13.9 to -4.9) **\*** |
| medium | 720 | 60.6% | 1280 | 53.0% | +7.5 (+3.0 to +12.0) **\*** |
| psychologist | 293 | 49.5% | 1707 | 56.8% | -7.3 (-13.5 to -1.1) **\*** |
| rumormonger | 1158 | 52.7% | 842 | 60.0% | -7.3 (-11.7 to -2.9) **\*** |
| dowser | 711 | 59.5% | 1289 | 53.7% | +5.8 (+1.3 to +10.3) **\*** |
| martyr | 320 | 51.2% | 1680 | 56.6% | -5.4 (-11.3 to +0.6) |
| registrar | 718 | 58.6% | 1282 | 54.1% | +4.5 (-0.0 to +9.0) |
| archivist | 1117 | 57.1% | 883 | 54.0% | +3.1 (-1.3 to +7.5) |
| chronicler | 273 | 53.1% | 1727 | 56.2% | -3.1 (-9.4 to +3.3) |
| surveyor | 1166 | 56.9% | 834 | 54.1% | +2.9 (-1.5 to +7.3) |
| executor | 328 | 53.4% | 1672 | 56.2% | -2.9 (-8.8 to +3.0) |
| magistrate | 286 | 53.5% | 1714 | 56.1% | -2.6 (-8.9 to +3.6) |
| clerk | 1181 | 56.8% | 819 | 54.2% | +2.6 (-1.8 to +7.0) |
| nightwatch | 773 | 57.3% | 1227 | 54.8% | +2.5 (-1.9 to +7.0) |
| veteran | 324 | 57.7% | 1676 | 55.4% | +2.3 (-3.5 to +8.2) |
| lamplighter | 777 | 54.6% | 1223 | 56.5% | -1.9 (-6.4 to +2.5) |
| augur | 453 | 55.0% | 1547 | 56.0% | -1.0 (-6.2 to +4.2) |
| warden | 773 | 56.3% | 1227 | 55.4% | +0.9 (-3.6 to +5.3) |
| monitor | 305 | 56.1% | 1695 | 55.7% | +0.4 (-5.7 to +6.4) |
| sexton | 310 | 55.5% | 1690 | 55.8% | -0.3 (-6.3 to +5.7) |
| confessor | 785 | 55.8% | 1215 | 55.7% | +0.1 (-4.4 to +4.5) |
| seer | 468 | 55.8% | 1532 | 55.7% | +0.0 (-5.1 to +5.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 893 | 67.1% | 1107 | 46.6% | +20.5 (+16.2 to +24.7) **\*** |
| scion | 913 | 48.4% | 1087 | 61.9% | -13.5 (-17.8 to -9.2) **\*** |
| poisoner | 1244 | 52.6% | 756 | 61.0% | -8.4 (-12.9 to -4.0) **\*** |
| revenant | 950 | 56.3% | 1050 | 55.2% | +1.1 (-3.3 to +5.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 427 | 48.0% | 1573 | 57.9% | -9.8 (-15.2 to -4.5) **\*** |
| sleepwalker | 426 | 58.9% | 1574 | 54.9% | +4.0 (-1.3 to +9.3) |
| marked | 385 | 58.7% | 1615 | 55.0% | +3.7 (-1.8 to +9.1) |
| muddler | 384 | 57.8% | 1616 | 55.3% | +2.6 (-2.9 to +8.1) |
| lovers | 378 | 55.8% | 1622 | 55.7% | +0.1 (-5.5 to +5.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 177 | 57.1% | 1823 | 55.6% | +1.4 (-6.2 to +9.1) |
| 4 night-walkers | 718 | 55.4% | 1282 | 55.9% | -0.5 (-5.0 to +4.0) |
| 3 night-walkers | 1105 | 55.7% | 895 | 55.8% | -0.0 (-4.4 to +4.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 1181 | 3.4 | 13.3% | 14.5% | 94.6% |
| surveyor | 1166 | 3.3 | 14.0% | 16.4% | 95.7% |
| rumormonger | 1158 | 3.5 | 13.2% | 18.2% | 94.3% |
| archivist | 1117 | 2.0 | 54.1% | 9.0% | 95.2% |
| confessor | 785 | 2.7 | 21.5% | 23.2% | 87.9% |
| lamplighter | 777 | 3.0 | 22.9% | 12.5% | 90.1% |
| nightwatch | 773 | 2.4 | 31.8% | 17.2% | 87.1% |
| warden | 773 | 3.3 | 12.5% | 23.8% | 84.9% |
| gravedigger | 761 | 2.6 | 32.9% | 12.0% | 91.1% |
| medium | 720 | 2.8 | 23.1% | 6.8% | 85.7% |
| registrar | 718 | 2.7 | 27.3% | 6.4% | 85.1% |
| dowser | 711 | 2.1 | 50.4% | 10.4% | 88.9% |
| seer | 468 | 2.4 | 36.8% | 11.1% | 87.2% |
| augur | 453 | 2.9 | 22.1% | 14.1% | 85.7% |
| executor | 328 | 3.0 | 23.2% | 10.4% | 86.9% |
| veteran | 324 | 4.3 | 3.1% | 20.1% | 90.4% |
| martyr | 320 | 3.5 | 11.2% | 14.1% | 87.8% |
| sexton | 310 | 3.5 | 8.1% | 29.4% | 76.8% |
| monitor | 305 | 3.2 | 20.3% | 8.9% | 85.9% |
| psychologist | 293 | 3.1 | 20.1% | 14.7% | 88.4% |
| magistrate | 286 | 2.7 | 25.5% | 12.2% | 89.2% |
| chronicler | 273 | 3.1 | 19.4% | 12.5% | 88.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 418 | 0.0% | 72.7% |
| registrar | 392 | 0.0% | 42.6% |
| archivist | 391 | 0.0% | 46.0% |
| rumormonger | 388 | 0.0% | 57.2% |
| gravedigger | 378 | 0.0% | 60.1% |
| clerk | 368 | 0.0% | 51.1% |
| confessor | 360 | 0.0% | 63.9% |
| surveyor | 348 | 0.0% | 46.0% |
| medium | 344 | 0.0% | 23.8% |
| nightwatch | 333 | 0.0% | 66.7% |
| lamplighter | 325 | 0.0% | 67.4% |
| magistrate | 246 | 0.0% | 65.4% |
| chronicler | 238 | 0.0% | 58.0% |
| monitor | 230 | 0.0% | 33.9% |
| augur | 221 | 0.0% | 62.0% |
| psychologist | 215 | 0.0% | 49.3% |
| seer | 211 | 0.0% | 46.9% |
| executor | 208 | 0.0% | 42.3% |
| warden | 55 | 0.0% | 52.7% |
| veteran | 50 | 0.0% | 48.0% |
| sexton | 49 | 0.0% | 42.9% |
| martyr | 44 | 0.0% | 31.8% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + medium | 350 | 73.4% | 1650 | 52.0% | +21.4 (+16.2 to +26.6) |
| poisoner + scion | 396 | 39.1% | 1604 | 59.9% | -20.7 (-26.1 to -15.3) |
| breathstealer + demon | 893 | 67.1% | 1107 | 46.6% | +20.5 (+16.2 to +24.7) |
| breathstealer + revenant | 239 | 72.8% | 1761 | 53.4% | +19.4 (+13.3 to +25.5) |
| breathstealer + registrar | 294 | 71.8% | 1706 | 53.0% | +18.8 (+13.1 to +24.4) |
| rumormonger + scion | 522 | 42.9% | 1478 | 60.3% | -17.4 (-22.3 to -12.4) |
| breathstealer + surveyor | 525 | 68.4% | 1475 | 51.3% | +17.1 (+12.4 to +21.9) |
| breathstealer + clerk | 532 | 68.0% | 1468 | 51.3% | +16.8 (+12.0 to +21.5) |
| archivist + breathstealer | 491 | 67.8% | 1509 | 51.8% | +16.0 (+11.2 to +20.8) |
| breathstealer + dowser | 304 | 69.1% | 1696 | 53.4% | +15.7 (+10.0 to +21.4) |
| gravedigger + scion | 333 | 42.9% | 1667 | 58.3% | -15.4 (-21.2 to -9.5) |
| breathstealer + lamplighter | 364 | 67.6% | 1636 | 53.1% | +14.5 (+9.1 to +19.8) |
| breathstealer + confessor | 353 | 67.1% | 1647 | 53.3% | +13.8 (+8.4 to +19.3) |
| breathstealer + seer | 207 | 68.1% | 1793 | 54.3% | +13.8 (+7.0 to +20.5) |
| breathstealer + warden | 347 | 67.1% | 1653 | 53.4% | +13.8 (+8.3 to +19.3) |
| demon + scion | 913 | 48.4% | 1087 | 61.9% | -13.5 (-17.8 to -9.2) |
| breathstealer + rumormonger | 520 | 65.4% | 1480 | 52.4% | +13.0 (+8.2 to +17.8) |
| gravedigger + poisoner | 482 | 46.1% | 1518 | 58.8% | -12.8 (-17.9 to -7.7) |
| scion + seer | 202 | 44.6% | 1798 | 57.0% | -12.5 (-19.7 to -5.2) |
| gravedigger + rumormonger | 414 | 45.9% | 1586 | 58.3% | -12.4 (-17.8 to -7.1) |
| lamplighter + scion | 384 | 46.4% | 1616 | 58.0% | -11.6 (-17.2 to -6.1) |
| breathstealer + scion | 242 | 65.7% | 1758 | 54.4% | +11.3 (+4.9 to +17.7) |
| medium + nightwatch | 219 | 65.8% | 1781 | 54.5% | +11.2 (+4.5 to +17.9) |
| breathstealer + poisoner | 412 | 64.6% | 1588 | 53.5% | +11.1 (+5.9 to +16.3) |
| medium + surveyor | 410 | 64.4% | 1590 | 53.5% | +10.9 (+5.6 to +16.1) |
| dowser + medium | 253 | 65.2% | 1747 | 54.4% | +10.8 (+4.5 to +17.2) |
| revenant + scion | 275 | 46.5% | 1725 | 57.2% | -10.7 (-17.0 to -4.3) |
| augur + scion | 214 | 46.3% | 1786 | 56.9% | -10.6 (-17.7 to -3.6) |

### 10 NPCs, bot (pre-M4) insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 273 | 44.0% | 1727 | 52.0% | -8.0 (-14.4 to -1.7) **\*** |
| gravedigger | 761 | 46.8% | 1239 | 53.4% | -6.6 (-11.2 to -2.1) **\*** |
| dowser | 711 | 54.1% | 1289 | 49.1% | +5.0 (+0.5 to +9.6) **\*** |
| veteran | 324 | 47.5% | 1676 | 51.6% | -4.0 (-10.0 to +1.9) |
| nightwatch | 773 | 52.9% | 1227 | 49.6% | +3.3 (-1.2 to +7.8) |
| monitor | 305 | 48.2% | 1695 | 51.4% | -3.2 (-9.3 to +2.9) |
| lamplighter | 777 | 52.8% | 1223 | 49.7% | +3.1 (-1.4 to +7.5) |
| medium | 720 | 52.8% | 1280 | 49.8% | +2.9 (-1.6 to +7.5) |
| warden | 773 | 52.4% | 1227 | 50.0% | +2.4 (-2.1 to +6.9) |
| registrar | 718 | 52.4% | 1282 | 50.1% | +2.3 (-2.3 to +6.9) |
| executor | 328 | 49.1% | 1672 | 51.3% | -2.2 (-8.1 to +3.7) |
| magistrate | 286 | 49.3% | 1714 | 51.2% | -1.9 (-8.1 to +4.4) |
| sexton | 310 | 49.4% | 1690 | 51.2% | -1.8 (-7.9 to +4.2) |
| psychologist | 293 | 49.5% | 1707 | 51.1% | -1.7 (-7.9 to +4.5) |
| augur | 453 | 49.9% | 1547 | 51.2% | -1.3 (-6.5 to +3.9) |
| martyr | 320 | 51.9% | 1680 | 50.7% | +1.2 (-4.8 to +7.1) |
| seer | 468 | 51.7% | 1532 | 50.7% | +1.1 (-4.1 to +6.2) |
| clerk | 1181 | 50.6% | 819 | 51.3% | -0.6 (-5.1 to +3.8) |
| surveyor | 1166 | 50.8% | 834 | 51.1% | -0.3 (-4.8 to +4.1) |
| confessor | 785 | 51.1% | 1215 | 50.8% | +0.3 (-4.2 to +4.8) |
| rumormonger | 1158 | 50.9% | 842 | 50.8% | +0.1 (-4.3 to +4.6) |
| archivist | 1117 | 50.9% | 883 | 50.8% | +0.1 (-4.3 to +4.5) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 893 | 61.1% | 1107 | 42.6% | +18.5 (+14.2 to +22.8) **\*** |
| scion | 913 | 44.7% | 1087 | 56.1% | -11.4 (-15.8 to -7.1) **\*** |
| poisoner | 1244 | 48.0% | 756 | 55.7% | -7.7 (-12.2 to -3.2) **\*** |
| revenant | 950 | 51.1% | 1050 | 50.8% | +0.3 (-4.1 to +4.7) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 427 | 46.4% | 1573 | 52.1% | -5.8 (-11.1 to -0.4) **\*** |
| muddler | 384 | 54.4% | 1616 | 50.1% | +4.4 (-1.2 to +9.9) |
| lovers | 378 | 52.9% | 1622 | 50.4% | +2.5 (-3.1 to +8.1) |
| marked | 385 | 49.4% | 1615 | 51.3% | -1.9 (-7.5 to +3.6) |
| sleepwalker | 426 | 51.9% | 1574 | 50.6% | +1.2 (-4.1 to +6.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 177 | 57.1% | 1823 | 50.3% | +6.8 (-0.9 to +14.4) |
| 3 night-walkers | 1105 | 50.0% | 895 | 52.0% | -1.9 (-6.3 to +2.5) |
| 4 night-walkers | 718 | 50.7% | 1282 | 51.0% | -0.3 (-4.9 to +4.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 1181 | 3.3 | 12.6% | 19.3% | 94.7% |
| surveyor | 1166 | 3.3 | 14.2% | 20.7% | 94.7% |
| rumormonger | 1158 | 3.3 | 14.2% | 20.2% | 94.8% |
| archivist | 1117 | 2.0 | 55.1% | 12.4% | 95.2% |
| confessor | 785 | 2.7 | 21.8% | 23.3% | 89.9% |
| lamplighter | 777 | 3.0 | 21.0% | 11.2% | 89.7% |
| nightwatch | 773 | 2.5 | 33.0% | 16.6% | 88.4% |
| warden | 773 | 3.3 | 12.4% | 24.2% | 86.3% |
| gravedigger | 761 | 2.6 | 32.6% | 14.1% | 91.6% |
| medium | 720 | 2.8 | 19.6% | 11.0% | 86.0% |
| registrar | 718 | 2.7 | 26.5% | 9.5% | 85.9% |
| dowser | 711 | 2.1 | 50.8% | 10.5% | 89.2% |
| seer | 468 | 2.4 | 37.2% | 9.6% | 87.8% |
| augur | 453 | 2.9 | 23.4% | 15.2% | 84.1% |
| executor | 328 | 2.9 | 22.6% | 11.6% | 86.0% |
| veteran | 324 | 4.2 | 2.8% | 23.1% | 87.7% |
| martyr | 320 | 3.4 | 11.6% | 13.1% | 88.1% |
| sexton | 310 | 3.4 | 10.0% | 32.9% | 78.7% |
| monitor | 305 | 3.0 | 21.6% | 11.1% | 84.9% |
| psychologist | 293 | 3.1 | 21.2% | 13.7% | 86.0% |
| magistrate | 286 | 2.8 | 26.2% | 10.8% | 88.8% |
| chronicler | 273 | 3.1 | 19.0% | 16.1% | 90.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 419 | 0.0% | 68.7% |
| registrar | 394 | 0.0% | 45.9% |
| archivist | 391 | 0.0% | 48.8% |
| rumormonger | 388 | 0.0% | 54.9% |
| gravedigger | 377 | 0.0% | 58.4% |
| clerk | 368 | 0.0% | 54.6% |
| confessor | 361 | 0.0% | 65.1% |
| surveyor | 350 | 0.0% | 47.4% |
| medium | 345 | 0.0% | 24.1% |
| nightwatch | 336 | 0.0% | 56.8% |
| lamplighter | 329 | 0.0% | 58.7% |
| magistrate | 242 | 0.0% | 62.8% |
| chronicler | 238 | 0.0% | 51.3% |
| monitor | 229 | 0.0% | 35.4% |
| augur | 218 | 0.0% | 53.2% |
| psychologist | 215 | 0.0% | 43.7% |
| seer | 212 | 0.0% | 45.3% |
| executor | 211 | 0.0% | 43.1% |
| warden | 62 | 0.0% | 41.9% |
| sexton | 50 | 0.0% | 44.0% |
| veteran | 50 | 0.0% | 42.0% |
| martyr | 44 | 0.0% | 34.1% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner + scion | 396 | 33.8% | 1604 | 55.1% | -21.3 (-26.5 to -16.0) |
| breathstealer + demon | 893 | 61.1% | 1107 | 42.6% | +18.5 (+14.2 to +22.8) |
| breathstealer + registrar | 294 | 65.6% | 1706 | 48.4% | +17.3 (+11.4 to +23.2) |
| breathstealer + dowser | 304 | 65.1% | 1696 | 48.3% | +16.8 (+10.9 to +22.6) |
| breathstealer + medium | 350 | 64.0% | 1650 | 48.1% | +15.9 (+10.3 to +21.5) |
| breathstealer + rumormonger | 520 | 62.5% | 1480 | 46.8% | +15.7 (+10.8 to +20.6) |
| breathstealer + surveyor | 525 | 61.9% | 1475 | 47.0% | +14.9 (+10.0 to +19.8) |
| breathstealer + confessor | 353 | 62.9% | 1647 | 48.3% | +14.6 (+9.0 to +20.1) |
| breathstealer + lamplighter | 364 | 62.6% | 1636 | 48.3% | +14.3 (+8.8 to +19.9) |
| gravedigger + scion | 333 | 40.2% | 1667 | 53.0% | -12.8 (-18.6 to -7.0) |
| archivist + breathstealer | 491 | 60.5% | 1509 | 47.8% | +12.7 (+7.7 to +17.7) |
| breathstealer + poisoner | 412 | 60.9% | 1588 | 48.3% | +12.6 (+7.3 to +17.9) |
| breathstealer + clerk | 532 | 60.2% | 1468 | 47.5% | +12.6 (+7.7 to +17.5) |
| breathstealer + warden | 347 | 61.1% | 1653 | 48.8% | +12.3 (+6.7 to +18.0) |
| breathstealer + revenant | 239 | 61.5% | 1761 | 49.5% | +12.0 (+5.4 to +18.6) |
| breathstealer + scion | 242 | 61.2% | 1758 | 49.5% | +11.7 (+5.1 to +18.2) |
| demon + scion | 913 | 44.7% | 1087 | 56.1% | -11.4 (-15.8 to -7.1) |
| gravedigger + poisoner | 482 | 42.3% | 1518 | 53.6% | -11.3 (-16.4 to -6.2) |
| breathstealer + nightwatch | 379 | 59.9% | 1621 | 48.8% | +11.1 (+5.6 to +16.6) |
| confessor + scion | 369 | 42.3% | 1631 | 52.9% | -10.6 (-16.2 to -5.0) |

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 773 | 36.0% | 1227 | 24.2% | +11.8 (+7.6 to +15.9) **\*** |
| psychologist | 293 | 23.2% | 1707 | 29.7% | -6.5 (-11.8 to -1.2) **\*** |
| veteran | 324 | 23.5% | 1676 | 29.8% | -6.3 (-11.4 to -1.2) **\*** |
| dowser | 711 | 32.5% | 1289 | 26.7% | +5.8 (+1.6 to +10.0) **\*** |
| executor | 328 | 25.0% | 1672 | 29.5% | -4.5 (-9.7 to +0.7) |
| augur | 453 | 25.4% | 1547 | 29.7% | -4.3 (-9.0 to +0.3) |
| gravedigger | 761 | 26.3% | 1239 | 30.3% | -4.0 (-8.0 to +0.1) |
| rumormonger | 1158 | 27.2% | 842 | 30.9% | -3.7 (-7.7 to +0.4) |
| clerk | 1181 | 30.2% | 819 | 26.6% | +3.6 (-0.4 to +7.6) |
| seer | 468 | 31.4% | 1532 | 27.9% | +3.5 (-1.3 to +8.2) |
| confessor | 785 | 26.8% | 1215 | 30.0% | -3.3 (-7.3 to +0.7) |
| sexton | 310 | 31.3% | 1690 | 28.3% | +3.0 (-2.6 to +8.6) |
| chronicler | 273 | 26.4% | 1727 | 29.1% | -2.8 (-8.4 to +2.9) |
| medium | 720 | 30.0% | 1280 | 28.0% | +2.0 (-2.2 to +6.1) |
| monitor | 305 | 27.2% | 1695 | 29.0% | -1.8 (-7.3 to +3.6) |
| magistrate | 286 | 27.3% | 1714 | 29.0% | -1.7 (-7.3 to +3.9) |
| warden | 773 | 29.8% | 1227 | 28.1% | +1.6 (-2.5 to +5.7) |
| lamplighter | 777 | 28.1% | 1223 | 29.2% | -1.1 (-5.2 to +2.9) |
| archivist | 1117 | 29.2% | 883 | 28.2% | +1.0 (-3.0 to +5.0) |
| surveyor | 1166 | 28.4% | 834 | 29.3% | -0.9 (-4.9 to +3.2) |
| registrar | 718 | 28.4% | 1282 | 28.9% | -0.5 (-4.7 to +3.6) |
| martyr | 320 | 28.4% | 1680 | 28.8% | -0.4 (-5.8 to +5.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 893 | 38.3% | 1107 | 21.0% | +17.2 (+13.3 to +21.2) **\*** |
| poisoner | 1244 | 24.2% | 756 | 36.2% | -12.0 (-16.2 to -7.9) **\*** |
| revenant | 950 | 26.7% | 1050 | 30.6% | -3.8 (-7.8 to +0.1) |
| scion | 913 | 27.7% | 1087 | 29.6% | -1.9 (-5.9 to +2.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| muddler | 384 | 33.1% | 1616 | 27.7% | +5.4 (+0.2 to +10.5) **\*** |
| sleepwalker | 426 | 25.4% | 1574 | 29.7% | -4.3 (-9.0 to +0.4) |
| delusional | 427 | 25.5% | 1573 | 29.6% | -4.1 (-8.8 to +0.6) |
| marked | 385 | 30.4% | 1615 | 28.4% | +2.0 (-3.1 to +7.1) |
| lovers | 378 | 30.2% | 1622 | 28.4% | +1.7 (-3.4 to +6.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 177 | 26.6% | 1823 | 29.0% | -2.4 (-9.2 to +4.4) |
| 4 night-walkers | 718 | 29.1% | 1282 | 28.5% | +0.6 (-3.6 to +4.7) |
| 3 night-walkers | 1105 | 28.9% | 895 | 28.6% | +0.3 (-3.7 to +4.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 1181 | 3.7 | 12.1% | 27.3% | 96.5% |
| surveyor | 1166 | 3.6 | 16.7% | 25.1% | 95.8% |
| rumormonger | 1158 | 3.7 | 13.3% | 28.8% | 96.4% |
| archivist | 1117 | 2.2 | 54.6% | 15.8% | 96.5% |
| confessor | 785 | 2.8 | 27.6% | 24.6% | 90.6% |
| lamplighter | 777 | 3.0 | 24.2% | 24.7% | 90.9% |
| warden | 773 | 3.4 | 14.7% | 33.0% | 89.1% |
| nightwatch | 773 | 2.5 | 38.7% | 17.9% | 91.2% |
| gravedigger | 761 | 2.8 | 29.8% | 17.0% | 91.9% |
| medium | 720 | 3.0 | 21.8% | 14.0% | 92.5% |
| registrar | 718 | 2.9 | 30.5% | 10.3% | 88.3% |
| dowser | 711 | 2.2 | 54.0% | 12.2% | 92.5% |
| seer | 468 | 2.5 | 40.2% | 13.7% | 91.7% |
| augur | 453 | 3.1 | 26.0% | 17.2% | 87.9% |
| executor | 328 | 3.4 | 21.3% | 17.7% | 89.9% |
| veteran | 324 | 4.3 | 2.2% | 39.8% | 95.1% |
| martyr | 320 | 4.0 | 6.9% | 20.6% | 91.9% |
| sexton | 310 | 3.6 | 11.9% | 29.7% | 78.7% |
| monitor | 305 | 3.5 | 18.0% | 12.5% | 86.9% |
| psychologist | 293 | 3.2 | 20.8% | 23.9% | 87.7% |
| magistrate | 286 | 2.8 | 26.9% | 17.5% | 91.3% |
| chronicler | 273 | 3.2 | 16.8% | 20.1% | 91.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 417 | 0.0% | 46.5% |
| registrar | 401 | 0.0% | 31.2% |
| archivist | 396 | 0.0% | 38.1% |
| rumormonger | 388 | 0.0% | 39.2% |
| gravedigger | 382 | 0.0% | 48.7% |
| clerk | 368 | 0.0% | 35.9% |
| confessor | 366 | 0.0% | 39.3% |
| medium | 349 | 0.0% | 30.9% |
| surveyor | 345 | 0.0% | 40.3% |
| nightwatch | 339 | 0.0% | 35.1% |
| lamplighter | 332 | 0.0% | 44.3% |
| magistrate | 249 | 0.0% | 37.3% |
| chronicler | 247 | 0.0% | 36.0% |
| monitor | 230 | 0.0% | 12.2% |
| augur | 226 | 0.0% | 35.0% |
| psychologist | 221 | 0.0% | 30.3% |
| executor | 214 | 0.0% | 28.0% |
| seer | 213 | 0.0% | 36.6% |
| warden | 60 | 0.0% | 40.0% |
| sexton | 53 | 0.0% | 43.4% |
| veteran | 52 | 0.0% | 30.8% |
| martyr | 44 | 0.0% | 18.2% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + nightwatch | 379 | 45.1% | 1621 | 24.9% | +20.2 (+14.8 to +25.6) |
| breathstealer + dowser | 304 | 43.8% | 1696 | 26.1% | +17.7 (+11.7 to +23.6) |
| breathstealer + scion | 242 | 44.2% | 1758 | 26.6% | +17.6 (+11.0 to +24.2) |
| breathstealer + demon | 893 | 38.3% | 1107 | 21.0% | +17.2 (+13.3 to +21.2) |
| breathstealer + seer | 207 | 43.0% | 1793 | 27.1% | +15.9 (+8.8 to +22.9) |
| medium + nightwatch | 219 | 42.0% | 1781 | 27.1% | +14.9 (+8.0 to +21.7) |
| archivist + breathstealer | 491 | 39.7% | 1509 | 25.2% | +14.5 (+9.7 to +19.4) |
| breathstealer + clerk | 532 | 39.1% | 1468 | 25.0% | +14.1 (+9.4 to +18.8) |
| breathstealer + revenant | 239 | 40.6% | 1761 | 27.1% | +13.4 (+6.9 to +20.0) |
| nightwatch + warden | 237 | 40.5% | 1763 | 27.2% | +13.3 (+6.8 to +19.9) |
| breathstealer + surveyor | 525 | 38.1% | 1475 | 25.4% | +12.7 (+8.0 to +17.4) |
| poisoner + veteran | 229 | 17.9% | 1771 | 30.2% | -12.2 (-17.7 to -6.8) |
| breathstealer + registrar | 294 | 39.1% | 1706 | 27.0% | +12.2 (+6.2 to +18.1) |
| demon + poisoner | 1244 | 24.2% | 756 | 36.2% | -12.0 (-16.2 to -7.9) |
| poisoner + scion | 396 | 19.2% | 1604 | 31.1% | -11.9 (-16.4 to -7.4) |
| dowser + nightwatch | 267 | 39.0% | 1733 | 27.2% | +11.8 (+5.6 to +18.0) |
| demon + nightwatch | 773 | 36.0% | 1227 | 24.2% | +11.8 (+7.6 to +15.9) |
| breathstealer + warden | 347 | 38.3% | 1653 | 26.7% | +11.6 (+6.0 to +17.1) |
| breathstealer + medium | 350 | 38.3% | 1650 | 26.7% | +11.6 (+6.0 to +17.1) |
| clerk + nightwatch | 445 | 37.5% | 1555 | 26.2% | +11.3 (+6.3 to +16.3) |
| poisoner + revenant | 436 | 20.0% | 1564 | 31.2% | -11.2 (-15.6 to -6.8) |
| breathstealer + rumormonger | 520 | 36.9% | 1480 | 25.9% | +11.0 (+6.3 to +15.8) |
| augur + poisoner | 282 | 19.5% | 1718 | 30.3% | -10.8 (-15.9 to -5.7) |
| nightwatch + revenant | 388 | 36.9% | 1612 | 26.8% | +10.1 (+4.8 to +15.3) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 978 | 349 (35.7%) | 92 (9.4%) | 235 | 302 |
| 7 | 7 NPCs, bot (pre-M4) insight 1.0 | 1756 | 599 (34.1%) | 183 (10.4%) | 427 | 547 |
| 10 | 10 NPCs, bot insight 1.0 | 2000 | 705 (35.2%) | 165 (8.2%) | 410 | 720 |
| 10 | 10 NPCs, bot (pre-M4) insight 1.0 | 2000 | 640 (32.0%) | 197 (9.8%) | 378 | 785 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: 7 NPCs, bot insight 1.0: 1022 (first 100257, 100258, 100259, 100260, 100261, 100262, 100263, 100264, 100265, 100266); 7 NPCs, bot (pre-M4) insight 1.0: 244 (first 100454, 100455, 100456, 100457, 100458, 100459, 100460, 100461, 100462, 100463)
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 24 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 70.4 | 138.0 | 405.0 |
| 7 NPCs, bot (pre-M4) insight 1.0 | 40.7 | 75.3 | 199.2 |
| 7 NPCs, passive | 3.0 | 4.6 | 15.8 |
| 10 NPCs, bot insight 1.0 | 300.1 | 604.5 | 1788.5 |
| 10 NPCs, bot (pre-M4) insight 1.0 | 178.6 | 369.6 | 921.9 |
| 10 NPCs, passive | 32.6 | 60.0 | 185.8 |

Slowest seeds: 100370 (10 NPCs bot, 1789 s), 100684 (10 NPCs bot, 1655 s), 100598 (10 NPCs bot, 1434 s), 101204 (10 NPCs bot, 1394 s), 100421 (10 NPCs bot, 1320 s), 101233 (10 NPCs bot, 1313 s), 101479 (10 NPCs bot, 1242 s), 100597 (10 NPCs bot, 1228 s), 101560 (10 NPCs bot, 1192 s), 100184 (10 NPCs bot, 1182 s), 100520 (10 NPCs bot, 1171 s), 100132 (10 NPCs bot, 1151 s), 100387 (10 NPCs bot, 1135 s), 100927 (10 NPCs bot, 1132 s), 100564 (10 NPCs bot, 1132 s), 100664 (10 NPCs bot, 1121 s), 100283 (10 NPCs bot, 1114 s), 100986 (10 NPCs bot, 1079 s), 100393 (10 NPCs bot, 1073 s), 100974 (10 NPCs bot, 1065 s)

