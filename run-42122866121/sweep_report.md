# Balance sweep report

Records: 1499 games, 0 failed. Commit(s): `b1ca4e9ba3`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 177 | 57.6% (50.3%–64.7%) | 3.11 | 0.79 | 1.05 | 2.37 | 8.5% | 0.27 |
| 7 NPCs, passive | 695 | 37.7% (34.2%–41.4%) | 3.47 | 0.91 | 0.77 | 2.32 | 4.2% | 0.28 |
| 10 NPCs, bot insight 1.0 | 201 | 57.7% (50.8%–64.3%) | 4.04 | 1.22 | 1.52 | 2.47 | 9.0% | 0.47 |
| 10 NPCs, passive | 426 | 42.3% (37.7%–47.0%) | 4.45 | 1.41 | 1.34 | 2.52 | 3.3% | 0.58 |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=177)

- The demon's host was executed.: 102 (57.6%)
- Only two townsfolk remain and the demon still walks among them.: 75 (42.4%)
- Demon evidence on the board: 99.4% of games; good win rate 57.4% of 176
- Demon evidence reachable: 80.8% of games; good win rate 51.7% of 143
- Neither: 0.6% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=695)

- Only two townsfolk remain and the demon still walks among them.: 432 (62.2%)
- The demon's host was executed.: 262 (37.7%)
- Time ran out: the demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 60.7% of games; good win rate 44.1% of 422
- Demon evidence reachable: 99.4% of games; good win rate 37.3% of 691
- Neither: 0.6% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=201)

- The demon's host was executed.: 116 (57.7%)
- Only two townsfolk remain and the demon still walks among them.: 62 (30.8%)
- No good soul remains.: 23 (11.4%)
- Demon evidence on the board: 99.5% of games; good win rate 57.5% of 200
- Demon evidence reachable: 84.6% of games; good win rate 57.1% of 170
- Neither: 0.5% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=426)

- The demon's host was executed.: 180 (42.3%)
- Only two townsfolk remain and the demon still walks among them.: 129 (30.3%)
- No good soul remains.: 117 (27.5%)
- Demon evidence on the board: 70.4% of games; good win rate 45.7% of 300
- Demon evidence reachable: 100.0% of games; good win rate 42.3% of 426
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| dowser | 49 | 67.3% | 128 | 53.9% | +13.4 (-2.3 to +29.2) |
| medium | 34 | 47.1% | 143 | 60.1% | -13.1 (-31.7 to +5.5) |
| archivist | 92 | 53.3% | 85 | 62.4% | -9.1 (-23.6 to +5.4) |
| registrar | 49 | 63.3% | 128 | 55.5% | +7.8 (-8.2 to +23.8) |
| confessor | 33 | 51.5% | 144 | 59.0% | -7.5 (-26.4 to +11.3) |
| gravedigger | 44 | 52.3% | 133 | 59.4% | -7.1 (-24.1 to +9.8) |
| lamplighter | 45 | 62.2% | 132 | 56.1% | +6.2 (-10.3 to +22.7) |
| rumormonger | 92 | 59.8% | 85 | 55.3% | +4.5 (-10.1 to +19.1) |
| warden | 43 | 60.5% | 134 | 56.7% | +3.7 (-13.1 to +20.6) |
| seer | 31 | 54.8% | 146 | 58.2% | -3.4 (-22.6 to +15.9) |
| augur | 36 | 55.6% | 141 | 58.2% | -2.6 (-20.8 to +15.6) |
| clerk | 92 | 56.5% | 85 | 58.8% | -2.3 (-16.9 to +12.3) |
| nightwatch | 44 | 59.1% | 133 | 57.1% | +1.9 (-14.8 to +18.7) |
| surveyor | 88 | 58.0% | 89 | 57.3% | +0.7 (-13.9 to +15.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 37 | 64.9% | 140 | 55.7% | +9.2 (-8.3 to +26.6) |
| scion | 51 | 52.9% | 126 | 59.5% | -6.6 (-22.7 to +9.6) |
| breathstealer | 35 | 57.1% | 142 | 57.7% | -0.6 (-18.9 to +17.7) |
| poisoner | 54 | 57.4% | 123 | 57.7% | -0.3 (-16.1 to +15.5) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 40 | 40.0% | 137 | 62.8% | -22.8 (-40.0 to -5.6) **\*** |
| lovers | 40 | 67.5% | 137 | 54.7% | +12.8 (-4.0 to +29.5) |
| muddler | 38 | 63.2% | 139 | 56.1% | +7.0 (-10.4 to +24.5) |
| marked | 31 | 61.3% | 146 | 56.8% | +4.4 (-14.5 to +23.4) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 64 | 53.1% | 113 | 60.2% | -7.1 (-22.2 to +8.1) |
| 2 night-walkers | 107 | 59.8% | 70 | 54.3% | +5.5 (-9.4 to +20.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 92 | 2.4 | 19.6% | 15.2% | 94.6% |
| archivist | 92 | 1.6 | 53.3% | 16.3% | 95.7% |
| rumormonger | 92 | 2.0 | 27.2% | 21.7% | 88.0% |
| surveyor | 88 | 2.0 | 23.9% | 13.6% | 94.3% |
| registrar | 49 | 2.4 | 24.5% | 8.2% | 81.6% |
| dowser | 49 | 1.8 | 69.4% | 10.2% | 85.7% |
| lamplighter | 45 | 2.2 | 31.1% | 6.7% | 91.1% |
| nightwatch | 44 | 1.9 | 36.4% | 22.7% | 70.5% |
| gravedigger | 44 | 1.7 | 52.3% | 15.9% | 75.0% |
| warden | 43 | 2.2 | 23.3% | 16.3% | 83.7% |
| augur | 36 | 2.0 | 25.0% | 22.2% | 77.8% |
| medium | 34 | 2.4 | 23.5% | 14.7% | 85.3% |
| confessor | 33 | 2.2 | 36.4% | 15.2% | 78.8% |
| seer | 31 | 1.8 | 32.3% | 32.3% | 74.2% |
| executor | 20 | 2.0 | 35.0% | 10.0% | 85.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| medium | 28 | 0.0% | 21.4% |
| lamplighter | 26 | 0.0% | 50.0% |
| dowser | 25 | 0.0% | 76.0% |
| nightwatch | 23 | 0.0% | 87.0% |
| gravedigger | 23 | 0.0% | 82.6% |
| executor | 22 | 0.0% | 36.4% |
| registrar | 22 | 0.0% | 31.8% |
| confessor | 19 | 0.0% | 57.9% |
| surveyor | 19 | 0.0% | 57.9% |
| rumormonger | 18 | 0.0% | 55.6% |
| magistrate | 17 | 0.0% | 64.7% |
| chronicler | 16 | 0.0% | 62.5% |
| archivist | 15 | 0.0% | 40.0% |
| clerk | 15 | 0.0% | 60.0% |
| psychologist | 12 | 0.0% | 50.0% |
| seer | 11 | 0.0% | 54.5% |
| augur | 11 | 0.0% | 45.5% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| monitor | 52 | 19.2% | 643 | 39.2% | -20.0 (-31.3 to -8.6) **\*** |
| executor | 62 | 24.2% | 633 | 39.0% | -14.8 (-26.1 to -3.5) **\*** |
| warden | 161 | 47.8% | 534 | 34.6% | +13.2 (+4.5 to +21.9) **\*** |
| dowser | 201 | 46.8% | 494 | 34.0% | +12.8 (+4.7 to +20.8) **\*** |
| veteran | 48 | 27.1% | 647 | 38.5% | -11.4 (-24.5 to +1.7) |
| confessor | 160 | 46.2% | 535 | 35.1% | +11.1 (+2.4 to +19.8) **\*** |
| sexton | 56 | 28.6% | 639 | 38.5% | -9.9 (-22.3 to +2.5) |
| medium | 126 | 30.2% | 569 | 39.4% | -9.2 (-18.2 to -0.2) **\*** |
| augur | 138 | 30.4% | 557 | 39.5% | -9.1 (-17.7 to -0.4) **\*** |
| seer | 111 | 30.6% | 584 | 39.0% | -8.4 (-17.9 to +1.0) |
| martyr | 62 | 32.3% | 633 | 38.2% | -6.0 (-18.2 to +6.3) |
| registrar | 196 | 40.8% | 499 | 36.5% | +4.3 (-3.7 to +12.4) |
| lamplighter | 141 | 41.1% | 554 | 36.8% | +4.3 (-4.7 to +13.4) |
| nightwatch | 162 | 39.5% | 533 | 37.1% | +2.4 (-6.2 to +10.9) |
| psychologist | 48 | 39.6% | 647 | 37.6% | +2.0 (-12.3 to +16.4) |
| archivist | 377 | 36.9% | 318 | 38.7% | -1.8 (-9.0 to +5.4) |
| magistrate | 59 | 39.0% | 636 | 37.6% | +1.4 (-11.6 to +14.4) |
| gravedigger | 187 | 36.9% | 508 | 38.0% | -1.1 (-9.2 to +7.0) |
| rumormonger | 361 | 37.4% | 334 | 38.0% | -0.6 (-7.8 to +6.6) |
| surveyor | 345 | 38.0% | 350 | 37.4% | +0.5 (-6.7 to +7.7) |
| chronicler | 50 | 38.0% | 645 | 37.7% | +0.3 (-13.6 to +14.3) |
| clerk | 372 | 37.6% | 323 | 37.8% | -0.1 (-7.4 to +7.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 144 | 52.1% | 551 | 33.9% | +18.1 (+9.1 to +27.2) **\*** |
| revenant | 151 | 29.8% | 544 | 39.9% | -10.1 (-18.5 to -1.7) **\*** |
| poisoner | 229 | 31.9% | 466 | 40.6% | -8.7 (-16.2 to -1.2) **\*** |
| scion | 171 | 40.4% | 524 | 36.8% | +3.5 (-4.9 to +12.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 144 | 25.7% | 551 | 40.8% | -15.1 (-23.4 to -6.9) **\*** |
| lovers | 146 | 47.9% | 549 | 35.0% | +13.0 (+3.9 to +22.0) **\*** |
| muddler | 136 | 40.4% | 559 | 37.0% | +3.4 (-5.8 to +12.6) |
| marked | 133 | 35.3% | 562 | 38.3% | -2.9 (-12.0 to +6.1) |
| sleepwalker | 136 | 39.0% | 559 | 37.4% | +1.6 (-7.5 to +10.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 434 | 34.8% | 261 | 42.5% | -7.7 (-15.2 to -0.2) **\*** |
| 3 night-walkers | 238 | 42.0% | 457 | 35.4% | +6.6 (-1.1 to +14.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 377 | 1.7 | 58.1% | 18.6% | 95.8% |
| clerk | 372 | 2.7 | 22.6% | 22.3% | 93.8% |
| rumormonger | 361 | 2.6 | 23.0% | 24.1% | 95.0% |
| surveyor | 345 | 2.3 | 32.5% | 17.7% | 92.5% |
| dowser | 201 | 1.9 | 56.7% | 9.0% | 87.6% |
| registrar | 196 | 2.3 | 40.8% | 6.6% | 86.7% |
| gravedigger | 187 | 2.1 | 43.9% | 15.5% | 87.7% |
| nightwatch | 162 | 2.0 | 31.5% | 34.6% | 82.7% |
| warden | 161 | 2.7 | 20.5% | 13.7% | 83.2% |
| confessor | 160 | 2.2 | 38.1% | 10.0% | 88.1% |
| lamplighter | 141 | 2.4 | 29.1% | 7.1% | 83.0% |
| augur | 138 | 2.3 | 37.7% | 18.1% | 82.6% |
| medium | 126 | 2.3 | 34.9% | 15.9% | 81.7% |
| seer | 111 | 2.2 | 36.9% | 29.7% | 91.0% |
| executor | 62 | 2.4 | 41.9% | 12.9% | 80.6% |
| martyr | 62 | 2.8 | 22.6% | 24.2% | 83.9% |
| magistrate | 59 | 2.3 | 37.3% | 11.9% | 88.1% |
| sexton | 56 | 2.8 | 21.4% | 35.7% | 80.4% |
| monitor | 52 | 2.3 | 38.5% | 5.8% | 80.8% |
| chronicler | 50 | 2.3 | 30.0% | 16.0% | 78.0% |
| psychologist | 48 | 2.8 | 16.7% | 12.5% | 85.4% |
| veteran | 48 | 3.7 | 4.2% | 41.7% | 95.8% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 95 | 0.0% | 61.1% |
| confessor | 94 | 0.0% | 35.1% |
| medium | 94 | 0.0% | 19.1% |
| registrar | 93 | 0.0% | 45.2% |
| dowser | 92 | 0.0% | 50.0% |
| gravedigger | 87 | 0.0% | 48.3% |
| lamplighter | 86 | 0.0% | 24.4% |
| surveyor | 80 | 0.0% | 36.2% |
| rumormonger | 76 | 0.0% | 42.1% |
| clerk | 75 | 0.0% | 49.3% |
| archivist | 63 | 0.0% | 54.0% |
| seer | 59 | 0.0% | 50.8% |
| magistrate | 56 | 0.0% | 42.9% |
| chronicler | 55 | 0.0% | 38.2% |
| psychologist | 54 | 0.0% | 25.9% |
| executor | 53 | 0.0% | 26.4% |
| monitor | 52 | 0.0% | 19.2% |
| augur | 48 | 0.0% | 31.2% |
| martyr | 12 | 0.0% | 25.0% |
| warden | 12 | 0.0% | 0.0% |
| veteran | 11 | 0.0% | 36.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| demon + dowser | 201 | 46.8% | 494 | 34.0% | +12.8 (+4.7 to +20.8) |

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 30 | 43.3% | 171 | 60.2% | -16.9 (-36.1 to +2.3) |
| medium | 74 | 66.2% | 127 | 52.8% | +13.5 (-0.4 to +27.3) |
| clerk | 118 | 62.7% | 83 | 50.6% | +12.1 (-1.7 to +26.0) |
| lamplighter | 80 | 65.0% | 121 | 52.9% | +12.1 (-1.6 to +25.8) |
| gravedigger | 64 | 50.0% | 137 | 61.3% | -11.3 (-26.0 to +3.4) |
| archivist | 105 | 52.4% | 96 | 63.5% | -11.2 (-24.7 to +2.4) |
| seer | 48 | 50.0% | 153 | 60.1% | -10.1 (-26.3 to +6.0) |
| augur | 46 | 65.2% | 155 | 55.5% | +9.7 (-6.1 to +25.6) |
| veteran | 31 | 51.6% | 170 | 58.8% | -7.2 (-26.3 to +11.9) |
| monitor | 33 | 63.6% | 168 | 56.5% | +7.1 (-11.0 to +25.1) |
| nightwatch | 83 | 54.2% | 118 | 60.2% | -6.0 (-19.8 to +7.9) |
| confessor | 88 | 54.5% | 113 | 60.2% | -5.6 (-19.4 to +8.1) |
| warden | 68 | 60.3% | 133 | 56.4% | +3.9 (-10.5 to +18.3) |
| rumormonger | 122 | 59.0% | 79 | 55.7% | +3.3 (-10.7 to +17.3) |
| dowser | 69 | 59.4% | 132 | 56.8% | +2.6 (-11.7 to +16.9) |
| psychologist | 32 | 56.2% | 169 | 58.0% | -1.7 (-20.5 to +17.0) |
| surveyor | 122 | 58.2% | 79 | 57.0% | +1.2 (-12.8 to +15.2) |
| registrar | 88 | 58.0% | 113 | 57.5% | +0.4 (-13.3 to +14.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 92 | 66.3% | 109 | 50.5% | +15.8 (+2.4 to +29.3) **\*** |
| scion | 92 | 50.0% | 109 | 64.2% | -14.2 (-27.8 to -0.6) **\*** |
| poisoner | 121 | 52.1% | 80 | 66.2% | -14.2 (-27.8 to -0.5) **\*** |
| revenant | 97 | 63.9% | 104 | 51.9% | +12.0 (-1.6 to +25.5) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 33 | 69.7% | 168 | 55.4% | +14.3 (-3.0 to +31.7) |
| lovers | 34 | 67.6% | 167 | 55.7% | +12.0 (-5.5 to +29.4) |
| delusional | 53 | 49.1% | 148 | 60.8% | -11.8 (-27.3 to +3.8) |
| muddler | 38 | 50.0% | 163 | 59.5% | -9.5 (-27.1 to +8.1) |
| sleepwalker | 43 | 58.1% | 158 | 57.6% | +0.5 (-16.1 to +17.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 82 | 53.7% | 119 | 60.5% | -6.8 (-20.8 to +7.1) |
| 3 night-walkers | 104 | 58.7% | 97 | 56.7% | +2.0 (-11.7 to +15.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 122 | 3.0 | 13.9% | 19.7% | 94.3% |
| surveyor | 122 | 3.3 | 14.8% | 13.9% | 96.7% |
| clerk | 118 | 2.7 | 17.8% | 16.1% | 94.9% |
| archivist | 105 | 1.9 | 55.2% | 13.3% | 93.3% |
| registrar | 88 | 2.4 | 28.4% | 9.1% | 78.4% |
| confessor | 88 | 2.5 | 26.1% | 17.0% | 87.5% |
| nightwatch | 83 | 2.1 | 26.5% | 45.8% | 85.5% |
| lamplighter | 80 | 2.7 | 21.2% | 7.5% | 85.0% |
| medium | 74 | 2.7 | 23.0% | 9.5% | 87.8% |
| dowser | 69 | 2.2 | 46.4% | 17.4% | 84.1% |
| warden | 68 | 2.8 | 22.1% | 14.7% | 86.8% |
| gravedigger | 64 | 2.3 | 35.9% | 20.3% | 89.1% |
| seer | 48 | 2.3 | 31.2% | 35.4% | 83.3% |
| augur | 46 | 3.1 | 13.0% | 28.3% | 87.0% |
| monitor | 33 | 3.2 | 21.2% | 0.0% | 87.9% |
| psychologist | 32 | 2.6 | 25.0% | 12.5% | 68.8% |
| veteran | 31 | 3.6 | 0.0% | 25.8% | 90.3% |
| chronicler | 30 | 3.0 | 13.3% | 13.3% | 83.3% |
| magistrate | 28 | 2.9 | 25.0% | 10.7% | 75.0% |
| martyr | 28 | 3.8 | 7.1% | 14.3% | 85.7% |
| sexton | 25 | 3.9 | 4.0% | 24.0% | 88.0% |
| executor | 25 | 2.9 | 20.0% | 8.0% | 88.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 47 | 0.0% | 70.2% |
| archivist | 41 | 0.0% | 61.0% |
| medium | 40 | 0.0% | 20.0% |
| gravedigger | 40 | 0.0% | 65.0% |
| rumormonger | 39 | 0.0% | 51.3% |
| surveyor | 39 | 0.0% | 38.5% |
| clerk | 37 | 0.0% | 51.4% |
| lamplighter | 35 | 0.0% | 57.1% |
| magistrate | 31 | 0.0% | 51.6% |
| registrar | 29 | 0.0% | 48.3% |
| monitor | 29 | 0.0% | 24.1% |
| confessor | 29 | 0.0% | 69.0% |
| chronicler | 28 | 0.0% | 46.4% |
| augur | 24 | 0.0% | 58.3% |
| nightwatch | 23 | 0.0% | 87.0% |
| psychologist | 22 | 0.0% | 31.8% |
| executor | 17 | 0.0% | 35.3% |
| seer | 14 | 0.0% | 78.6% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| magistrate | 55 | 58.2% | 371 | 39.9% | +18.3 (+4.3 to +32.2) **\*** |
| lamplighter | 165 | 52.7% | 261 | 35.6% | +17.1 (+7.5 to +26.7) **\*** |
| sexton | 50 | 28.0% | 376 | 44.1% | -16.1 (-29.6 to -2.7) **\*** |
| chronicler | 59 | 30.5% | 367 | 44.1% | -13.6 (-26.4 to -0.8) **\*** |
| seer | 100 | 32.0% | 326 | 45.4% | -13.4 (-24.0 to -2.8) **\*** |
| martyr | 69 | 31.9% | 357 | 44.3% | -12.4 (-24.5 to -0.2) **\*** |
| archivist | 233 | 37.3% | 193 | 48.2% | -10.8 (-20.2 to -1.5) **\*** |
| rumormonger | 256 | 45.3% | 170 | 37.6% | +7.7 (-1.8 to +17.2) |
| gravedigger | 152 | 37.5% | 274 | 44.9% | -7.4 (-17.1 to +2.3) |
| warden | 161 | 46.6% | 265 | 39.6% | +7.0 (-2.7 to +16.7) |
| nightwatch | 156 | 38.5% | 270 | 44.4% | -6.0 (-15.6 to +3.7) |
| monitor | 57 | 47.4% | 369 | 41.5% | +5.9 (-8.0 to +19.8) |
| registrar | 162 | 45.7% | 264 | 40.2% | +5.5 (-4.2 to +15.2) |
| surveyor | 258 | 40.3% | 168 | 45.2% | -4.9 (-14.5 to +4.7) |
| clerk | 244 | 44.3% | 182 | 39.6% | +4.7 (-4.7 to +14.2) |
| veteran | 77 | 39.0% | 349 | 43.0% | -4.0 (-16.1 to +8.0) |
| executor | 65 | 44.6% | 361 | 41.8% | +2.8 (-10.3 to +15.9) |
| dowser | 162 | 43.8% | 264 | 41.3% | +2.5 (-7.1 to +12.2) |
| augur | 102 | 44.1% | 324 | 41.7% | +2.5 (-8.6 to +13.5) |
| medium | 172 | 43.6% | 254 | 41.3% | +2.3 (-7.3 to +11.8) |
| confessor | 166 | 43.4% | 260 | 41.5% | +1.8 (-7.8 to +11.5) |
| psychologist | 61 | 41.0% | 365 | 42.5% | -1.5 (-14.8 to +11.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 186 | 51.1% | 240 | 35.4% | +15.7 (+6.3 to +25.1) **\*** |
| poisoner | 259 | 38.6% | 167 | 47.9% | -9.3 (-18.9 to +0.3) |
| scion | 192 | 39.6% | 234 | 44.4% | -4.9 (-14.3 to +4.5) |
| revenant | 215 | 41.4% | 211 | 43.1% | -1.7 (-11.1 to +7.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 84 | 51.2% | 342 | 40.1% | +11.1 (-0.8 to +23.0) |
| delusional | 91 | 35.2% | 335 | 44.2% | -9.0 (-20.2 to +2.1) |
| sleepwalker | 96 | 38.5% | 330 | 43.3% | -4.8 (-15.9 to +6.3) |
| lovers | 72 | 44.4% | 354 | 41.8% | +2.6 (-9.9 to +15.2) |
| muddler | 83 | 43.4% | 343 | 42.0% | +1.4 (-10.5 to +13.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 34 | 55.9% | 392 | 41.1% | +14.8 (-2.6 to +32.2) |
| 3 night-walkers | 233 | 38.6% | 193 | 46.6% | -8.0 (-17.4 to +1.4) |
| 4 night-walkers | 159 | 44.7% | 267 | 40.8% | +3.8 (-5.9 to +13.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| surveyor | 258 | 3.4 | 17.8% | 25.6% | 94.6% |
| rumormonger | 256 | 3.4 | 15.6% | 23.4% | 94.1% |
| clerk | 244 | 3.4 | 13.9% | 26.6% | 96.7% |
| archivist | 233 | 1.8 | 61.4% | 10.7% | 97.0% |
| medium | 172 | 2.9 | 18.0% | 12.2% | 87.2% |
| confessor | 166 | 2.7 | 27.7% | 18.1% | 91.0% |
| lamplighter | 165 | 2.7 | 26.1% | 5.5% | 87.9% |
| registrar | 162 | 2.9 | 24.1% | 14.2% | 88.9% |
| dowser | 162 | 2.1 | 52.5% | 10.5% | 92.0% |
| warden | 161 | 3.4 | 14.9% | 16.8% | 86.3% |
| nightwatch | 156 | 2.4 | 20.5% | 55.1% | 91.7% |
| gravedigger | 152 | 2.7 | 32.9% | 15.8% | 91.4% |
| augur | 102 | 3.1 | 20.6% | 16.7% | 90.2% |
| seer | 100 | 2.3 | 42.0% | 27.0% | 82.0% |
| veteran | 77 | 4.3 | 1.3% | 35.1% | 93.5% |
| martyr | 69 | 3.6 | 10.1% | 26.1% | 89.9% |
| executor | 65 | 3.1 | 23.1% | 9.2% | 92.3% |
| psychologist | 61 | 2.8 | 24.6% | 14.8% | 82.0% |
| chronicler | 59 | 3.1 | 20.3% | 23.7% | 83.1% |
| monitor | 57 | 3.5 | 12.3% | 5.3% | 91.2% |
| magistrate | 55 | 2.7 | 27.3% | 7.3% | 90.9% |
| sexton | 50 | 3.1 | 10.0% | 44.0% | 86.0% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 95 | 0.0% | 36.8% |
| clerk | 90 | 0.0% | 54.4% |
| archivist | 90 | 0.0% | 56.7% |
| gravedigger | 88 | 0.0% | 53.4% |
| dowser | 87 | 0.0% | 48.3% |
| nightwatch | 76 | 0.0% | 81.6% |
| confessor | 76 | 0.0% | 42.1% |
| medium | 73 | 0.0% | 12.3% |
| lamplighter | 73 | 0.0% | 39.7% |
| rumormonger | 71 | 0.0% | 46.5% |
| surveyor | 69 | 0.0% | 44.9% |
| magistrate | 54 | 0.0% | 44.4% |
| augur | 52 | 0.0% | 51.9% |
| seer | 49 | 0.0% | 73.5% |
| monitor | 46 | 0.0% | 26.1% |
| executor | 42 | 0.0% | 21.4% |
| chronicler | 39 | 0.0% | 35.9% |
| psychologist | 34 | 0.0% | 38.2% |
| sexton | 12 | 0.0% | 25.0% |
| veteran | 11 | 0.0% | 36.4% |
| martyr | 10 | 0.0% | 20.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 177 | 54 (30.5%) | 19 (10.7%) | 48 | 56 |
| 10 | 10 NPCs, bot insight 1.0 | 96 | 24 (25.0%) | 10 (10.4%) | 33 | 29 |

## Health

- Stuck games (guard exhausted): 0
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 3 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 35.1 | 69.2 | 149.2 |
| 7 NPCs, passive | 4.8 | 8.1 | 18.6 |
| 10 NPCs, bot insight 1.0 | 145.4 | 282.1 | 557.7 |
| 10 NPCs, passive | 28.1 | 50.9 | 109.4 |

Slowest seeds: 100441 (10 NPCs bot, 558 s), 100112 (10 NPCs bot, 517 s), 100567 (10 NPCs bot, 488 s), 100127 (10 NPCs bot, 479 s), 100096 (10 NPCs bot, 447 s), 100551 (10 NPCs bot, 421 s), 100205 (10 NPCs bot, 393 s), 100141 (10 NPCs bot, 344 s), 100614 (10 NPCs bot, 328 s), 100204 (10 NPCs bot, 325 s), 100599 (10 NPCs bot, 318 s), 100378 (10 NPCs bot, 306 s), 100173 (10 NPCs bot, 297 s), 100221 (10 NPCs bot, 295 s), 100271 (10 NPCs bot, 294 s), 100646 (10 NPCs bot, 294 s), 100456 (10 NPCs bot, 292 s), 100047 (10 NPCs bot, 291 s), 100634 (10 NPCs bot, 289 s), 100584 (10 NPCs bot, 285 s)

