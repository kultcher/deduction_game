# Balance sweep report

Records: 1319 games, 1 failed, 0 stuck (left out of the rates). Commit(s): `d83e90f8db`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 219 | 80.4% (74.6%–85.1%) | 2.97 | 0.38 | 1.39 | 2.29 | 8.7% | 0.17 |
| 7 NPCs, passive | 219 | 59.8% (53.2%–66.1%) | 3.37 | 0.55 | 1.10 | 2.40 | 4.1% | 0.16 |
| 10 NPCs, bot insight 1.0 | 440 | 69.3% (64.9%–73.4%) | 4.23 | 0.80 | 1.83 | 2.52 | 8.2% | 0.34 |
| 10 NPCs, passive | 441 | 51.2% (46.6%–55.9%) | 4.36 | 1.05 | 1.49 | 2.56 | 1.4% | 0.45 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.60 | 19.5% | 29.1% | 2.19 | 8.1% | 7.7% | 7.7% |
| 7 NPCs, passive | 5.69 | 16.4% | 38.0% | 2.92 | 20.0% | 17.8% | 16.9% |
| 10 NPCs, bot insight 1.0 | 9.28 | 13.4% | 27.2% | 4.05 | 12.8% | 11.1% | 9.9% |
| 10 NPCs, passive | 9.96 | 9.9% | 31.0% | 5.00 | 23.9% | 22.9% | 19.0% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=219)

- The demon's host was executed.: 176 (80.4%)
- Only two townsfolk remain and the demon still walks among them.: 43 (19.6%)
- Demon evidence on the board: 98.6% of games; good win rate 80.1% of 216
- Demon evidence reachable: 79.0% of games; good win rate 76.3% of 173
- Neither: 0.9% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=219)

- The demon's host was executed.: 131 (59.8%)
- Only two townsfolk remain and the demon still walks among them.: 88 (40.2%)
- Demon evidence on the board: 58.9% of games; good win rate 72.9% of 129
- Demon evidence reachable: 99.1% of games; good win rate 59.4% of 217
- Neither: 0.9% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=440)

- The demon's host was executed.: 305 (69.3%)
- Only two townsfolk remain and the demon still walks among them.: 105 (23.9%)
- No good soul remains.: 30 (6.8%)
- Demon evidence on the board: 99.8% of games; good win rate 69.2% of 439
- Demon evidence reachable: 88.4% of games; good win rate 66.6% of 389
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=441)

- The demon's host was executed.: 226 (51.2%)
- Only two townsfolk remain and the demon still walks among them.: 124 (28.1%)
- No good soul remains.: 91 (20.6%)
- Demon evidence on the board: 77.1% of games; good win rate 54.4% of 340
- Demon evidence reachable: 100.0% of games; good win rate 51.2% of 441
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 55 | 89.1% | 164 | 77.4% | +11.7 (+1.2 to +22.1) **\*** |
| registrar | 62 | 72.6% | 157 | 83.4% | -10.9 (-23.4 to +1.7) |
| archivist | 130 | 76.2% | 89 | 86.5% | -10.4 (-20.6 to -0.2) **\*** |
| medium | 42 | 88.1% | 177 | 78.5% | +9.6 (-1.9 to +21.1) |
| dowser | 53 | 86.8% | 166 | 78.3% | +8.5 (-2.6 to +19.5) |
| confessor | 53 | 75.5% | 166 | 81.9% | -6.5 (-19.4 to +6.5) |
| surveyor | 103 | 83.5% | 116 | 77.6% | +5.9 (-4.5 to +16.3) |
| clerk | 127 | 78.0% | 92 | 83.7% | -5.7 (-16.2 to +4.7) |
| seer | 31 | 83.9% | 188 | 79.8% | +4.1 (-10.1 to +18.2) |
| lamplighter | 44 | 77.3% | 175 | 81.1% | -3.9 (-17.5 to +9.8) |
| gravedigger | 59 | 83.1% | 160 | 79.4% | +3.7 (-7.8 to +15.1) |
| augur | 46 | 78.3% | 173 | 80.9% | -2.7 (-15.9 to +10.6) |
| rumormonger | 99 | 81.8% | 120 | 79.2% | +2.7 (-7.9 to +13.2) |
| warden | 70 | 80.0% | 149 | 80.5% | -0.5 (-11.9 to +10.8) |

**Minions**

_Not enough games._

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 42 | 66.7% | 177 | 83.6% | -16.9 (-32.2 to -1.7) **\*** |
| lovers | 47 | 89.4% | 172 | 77.9% | +11.5 (+0.7 to +22.2) **\*** |
| marked | 35 | 85.7% | 184 | 79.3% | +6.4 (-6.6 to +19.4) |
| muddler | 47 | 78.7% | 172 | 80.8% | -2.1 (-15.2 to +11.0) |
| sleepwalker | 48 | 81.2% | 171 | 80.1% | +1.1 (-11.4 to +13.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 45 | 88.9% | 174 | 78.2% | +10.7 (-0.3 to +21.8) |
| 2 night-walkers | 174 | 78.2% | 45 | 88.9% | -10.7 (-21.8 to +0.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 130 | 1.4 | 60.0% | 7.7% | 93.8% |
| clerk | 127 | 1.9 | 18.9% | 6.3% | 85.0% |
| surveyor | 103 | 1.7 | 23.3% | 6.8% | 85.4% |
| rumormonger | 99 | 1.7 | 28.3% | 8.1% | 83.8% |
| warden | 70 | 1.9 | 22.9% | 8.6% | 65.7% |
| registrar | 62 | 2.0 | 30.6% | 4.8% | 72.6% |
| gravedigger | 59 | 2.1 | 35.6% | 8.5% | 76.3% |
| nightwatch | 55 | 1.8 | 29.1% | 9.1% | 80.0% |
| dowser | 53 | 1.8 | 43.4% | 1.9% | 90.6% |
| confessor | 53 | 2.1 | 32.1% | 18.9% | 69.8% |
| augur | 46 | 1.8 | 30.4% | 6.5% | 76.1% |
| lamplighter | 44 | 2.0 | 27.3% | 15.9% | 79.5% |
| medium | 42 | 1.7 | 28.6% | 2.4% | 71.4% |
| seer | 31 | 2.0 | 29.0% | 0.0% | 77.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 35 | 0.0% | 80.0% |
| surveyor | 34 | 0.0% | 70.6% |
| gravedigger | 34 | 0.0% | 67.6% |
| nightwatch | 30 | 0.0% | 76.7% |
| lamplighter | 29 | 0.0% | 96.6% |
| confessor | 29 | 0.0% | 89.7% |
| rumormonger | 28 | 0.0% | 71.4% |
| dowser | 27 | 0.0% | 85.2% |
| medium | 20 | 0.0% | 65.0% |
| archivist | 19 | 0.0% | 68.4% |
| seer | 19 | 0.0% | 52.6% |
| clerk | 17 | 0.0% | 70.6% |
| executor | 17 | 0.0% | 41.2% |
| psychologist | 17 | 0.0% | 70.6% |
| magistrate | 14 | 0.0% | 64.3% |
| augur | 14 | 0.0% | 57.1% |
| monitor | 13 | 0.0% | 69.2% |
| chronicler | 12 | 0.0% | 83.3% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| augur | 46 | 41.3% | 173 | 64.7% | -23.4 (-39.3 to -7.5) **\*** |
| dowser | 53 | 73.6% | 166 | 55.4% | +18.2 (+4.1 to +32.2) **\*** |
| rumormonger | 99 | 52.5% | 120 | 65.8% | -13.3 (-26.3 to -0.3) **\*** |
| medium | 42 | 50.0% | 177 | 62.1% | -12.1 (-28.9 to +4.6) |
| confessor | 53 | 67.9% | 166 | 57.2% | +10.7 (-4.0 to +25.3) |
| nightwatch | 55 | 67.3% | 164 | 57.3% | +10.0 (-4.6 to +24.5) |
| seer | 31 | 67.7% | 188 | 58.5% | +9.2 (-8.7 to +27.1) |
| gravedigger | 59 | 54.2% | 160 | 61.9% | -7.6 (-22.4 to +7.1) |
| lamplighter | 44 | 54.5% | 175 | 61.1% | -6.6 (-23.0 to +9.8) |
| warden | 70 | 64.3% | 149 | 57.7% | +6.6 (-7.2 to +20.3) |
| registrar | 62 | 64.5% | 157 | 58.0% | +6.6 (-7.6 to +20.7) |
| archivist | 130 | 61.5% | 89 | 57.3% | +4.2 (-9.0 to +17.5) |
| clerk | 127 | 60.6% | 92 | 58.7% | +1.9 (-11.2 to +15.1) |
| surveyor | 103 | 60.2% | 116 | 59.5% | +0.7 (-12.3 to +13.7) |

**Minions**

_Not enough games._

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 42 | 45.2% | 177 | 63.3% | -18.0 (-34.7 to -1.4) **\*** |
| muddler | 47 | 72.3% | 172 | 56.4% | +15.9 (+1.2 to +30.7) **\*** |
| sleepwalker | 48 | 52.1% | 171 | 62.0% | -9.9 (-25.8 to +6.0) |
| marked | 35 | 65.7% | 184 | 58.7% | +7.0 (-10.2 to +24.3) |
| lovers | 47 | 63.8% | 172 | 58.7% | +5.1 (-10.5 to +20.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 45 | 71.1% | 174 | 56.9% | +14.2 (-0.9 to +29.4) |
| 2 night-walkers | 174 | 56.9% | 45 | 71.1% | -14.2 (-29.4 to +0.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 130 | 1.6 | 56.9% | 11.5% | 93.1% |
| clerk | 127 | 2.4 | 17.3% | 11.8% | 89.8% |
| surveyor | 103 | 2.1 | 30.1% | 12.6% | 90.3% |
| rumormonger | 99 | 2.6 | 22.2% | 16.2% | 88.9% |
| warden | 70 | 2.4 | 25.7% | 10.0% | 77.1% |
| registrar | 62 | 2.0 | 41.9% | 3.2% | 75.8% |
| gravedigger | 59 | 2.3 | 33.9% | 8.5% | 86.4% |
| nightwatch | 55 | 1.9 | 45.5% | 9.1% | 76.4% |
| confessor | 53 | 2.0 | 41.5% | 3.8% | 79.2% |
| dowser | 53 | 1.8 | 62.3% | 0.0% | 92.5% |
| augur | 46 | 2.5 | 23.9% | 19.6% | 73.9% |
| lamplighter | 44 | 2.3 | 29.5% | 6.8% | 75.0% |
| medium | 42 | 2.1 | 33.3% | 11.9% | 69.0% |
| seer | 31 | 2.2 | 41.9% | 6.5% | 77.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 35 | 0.0% | 71.4% |
| gravedigger | 35 | 0.0% | 60.0% |
| surveyor | 35 | 0.0% | 48.6% |
| nightwatch | 30 | 0.0% | 40.0% |
| confessor | 29 | 0.0% | 69.0% |
| rumormonger | 27 | 0.0% | 51.9% |
| lamplighter | 27 | 0.0% | 70.4% |
| dowser | 27 | 0.0% | 70.4% |
| seer | 20 | 0.0% | 45.0% |
| medium | 20 | 0.0% | 45.0% |
| archivist | 19 | 0.0% | 73.7% |
| clerk | 19 | 0.0% | 47.4% |
| executor | 18 | 0.0% | 38.9% |
| psychologist | 17 | 0.0% | 52.9% |
| magistrate | 15 | 0.0% | 60.0% |
| augur | 14 | 0.0% | 64.3% |
| monitor | 13 | 0.0% | 30.8% |
| chronicler | 12 | 0.0% | 75.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sexton | 56 | 53.6% | 384 | 71.6% | -18.0 (-31.9 to -4.2) **\*** |
| chronicler | 57 | 57.9% | 383 | 71.0% | -13.1 (-26.7 to +0.5) |
| monitor | 64 | 79.7% | 376 | 67.6% | +12.1 (+1.2 to +23.1) **\*** |
| nightwatch | 199 | 75.4% | 241 | 64.3% | +11.1 (+2.6 to +19.6) **\*** |
| confessor | 175 | 62.9% | 265 | 73.6% | -10.7 (-19.6 to -1.8) **\*** |
| martyr | 61 | 60.7% | 379 | 70.7% | -10.1 (-23.1 to +3.0) |
| registrar | 152 | 75.7% | 288 | 66.0% | +9.7 (+0.9 to +18.4) **\*** |
| augur | 98 | 76.5% | 342 | 67.3% | +9.3 (-0.5 to +19.0) |
| gravedigger | 157 | 65.0% | 283 | 71.7% | -6.8 (-15.9 to +2.4) |
| rumormonger | 263 | 71.5% | 177 | 66.1% | +5.4 (-3.5 to +14.2) |
| executor | 63 | 65.1% | 377 | 70.0% | -4.9 (-17.6 to +7.7) |
| medium | 182 | 66.5% | 258 | 71.3% | -4.8 (-13.6 to +4.0) |
| seer | 105 | 65.7% | 335 | 70.4% | -4.7 (-15.0 to +5.6) |
| dowser | 152 | 72.4% | 288 | 67.7% | +4.7 (-4.3 to +13.6) |
| clerk | 252 | 71.0% | 188 | 67.0% | +4.0 (-4.7 to +12.8) |
| magistrate | 55 | 72.7% | 385 | 68.8% | +3.9 (-8.8 to +16.5) |
| warden | 172 | 71.5% | 268 | 67.9% | +3.6 (-5.2 to +12.4) |
| lamplighter | 176 | 67.6% | 264 | 70.5% | -2.8 (-11.7 to +6.0) |
| veteran | 74 | 71.6% | 366 | 68.9% | +2.8 (-8.5 to +14.1) |
| archivist | 243 | 68.3% | 197 | 70.6% | -2.2 (-10.9 to +6.4) |
| surveyor | 261 | 68.6% | 179 | 70.4% | -1.8 (-10.6 to +6.9) |
| psychologist | 63 | 69.8% | 377 | 69.2% | +0.6 (-11.6 to +12.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 127 | 67.7% | 313 | 70.0% | -2.3 (-11.8 to +7.3) |
| scion | 122 | 70.5% | 318 | 68.9% | +1.6 (-7.9 to +11.2) |
| poisoner | 191 | 69.6% | 249 | 69.1% | +0.6 (-8.1 to +9.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 93 | 64.5% | 347 | 70.6% | -6.1 (-16.9 to +4.8) |
| sleepwalker | 89 | 73.0% | 351 | 68.4% | +4.7 (-5.8 to +15.1) |
| muddler | 88 | 71.6% | 352 | 68.8% | +2.8 (-7.8 to +13.4) |
| lovers | 76 | 68.4% | 364 | 69.5% | -1.1 (-12.6 to +10.4) |
| marked | 94 | 69.1% | 346 | 69.4% | -0.2 (-10.7 to +10.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 31 | 61.3% | 409 | 69.9% | -8.6 (-26.3 to +9.1) |
| 4 night-walkers | 153 | 70.6% | 287 | 68.6% | +1.9 (-7.0 to +10.9) |
| 3 night-walkers | 256 | 69.5% | 184 | 69.0% | +0.5 (-8.2 to +9.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 263 | 3.2 | 15.6% | 9.5% | 92.4% |
| surveyor | 261 | 2.9 | 16.9% | 13.8% | 92.3% |
| clerk | 252 | 3.3 | 11.5% | 10.7% | 94.0% |
| archivist | 243 | 1.8 | 53.5% | 9.1% | 91.8% |
| nightwatch | 199 | 2.4 | 30.7% | 10.6% | 85.9% |
| medium | 182 | 2.7 | 22.0% | 5.5% | 81.3% |
| lamplighter | 176 | 2.8 | 18.2% | 14.2% | 89.2% |
| confessor | 175 | 2.9 | 16.6% | 20.0% | 85.7% |
| warden | 172 | 3.2 | 12.8% | 15.7% | 83.7% |
| gravedigger | 157 | 2.5 | 33.1% | 9.6% | 83.4% |
| registrar | 152 | 2.6 | 28.3% | 3.3% | 79.6% |
| dowser | 152 | 2.2 | 42.8% | 9.9% | 90.1% |
| seer | 105 | 2.3 | 39.0% | 11.4% | 87.6% |
| augur | 98 | 2.6 | 27.6% | 5.1% | 81.6% |
| veteran | 74 | 3.7 | 1.4% | 23.0% | 87.8% |
| monitor | 64 | 2.9 | 14.1% | 7.8% | 76.6% |
| psychologist | 63 | 2.6 | 23.8% | 9.5% | 82.5% |
| executor | 63 | 3.0 | 22.2% | 7.9% | 84.1% |
| martyr | 61 | 4.1 | 4.9% | 13.1% | 90.2% |
| chronicler | 57 | 3.2 | 19.3% | 10.5% | 93.0% |
| sexton | 56 | 3.4 | 7.1% | 28.6% | 75.0% |
| magistrate | 55 | 2.5 | 32.7% | 7.3% | 72.7% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 98 | 0.0% | 49.0% |
| dowser | 87 | 0.0% | 74.7% |
| confessor | 85 | 0.0% | 80.0% |
| gravedigger | 85 | 0.0% | 64.7% |
| archivist | 84 | 0.0% | 63.1% |
| clerk | 80 | 0.0% | 68.8% |
| surveyor | 79 | 0.0% | 63.3% |
| rumormonger | 77 | 0.0% | 61.0% |
| lamplighter | 73 | 0.0% | 68.5% |
| medium | 66 | 0.0% | 65.2% |
| magistrate | 57 | 0.0% | 66.7% |
| monitor | 55 | 0.0% | 50.9% |
| seer | 54 | 0.0% | 50.0% |
| nightwatch | 54 | 0.0% | 64.8% |
| chronicler | 51 | 0.0% | 51.0% |
| executor | 49 | 0.0% | 49.0% |
| psychologist | 49 | 0.0% | 61.2% |
| augur | 43 | 0.0% | 69.8% |
| sexton | 15 | 0.0% | 53.3% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| medium | 183 | 44.8% | 258 | 55.8% | -11.0 (-20.4 to -1.6) **\*** |
| nightwatch | 199 | 56.8% | 242 | 46.7% | +10.1 (+0.8 to +19.4) **\*** |
| dowser | 152 | 57.2% | 289 | 48.1% | +9.1 (-0.6 to +18.9) |
| confessor | 175 | 56.6% | 266 | 47.7% | +8.8 (-0.7 to +18.3) |
| martyr | 61 | 44.3% | 380 | 52.4% | -8.1 (-21.5 to +5.3) |
| gravedigger | 158 | 46.2% | 283 | 54.1% | -7.9 (-17.6 to +1.8) |
| surveyor | 261 | 48.3% | 180 | 55.6% | -7.3 (-16.7 to +2.2) |
| lamplighter | 176 | 47.2% | 265 | 54.0% | -6.8 (-16.3 to +2.7) |
| veteran | 74 | 45.9% | 367 | 52.3% | -6.4 (-18.8 to +6.1) |
| executor | 63 | 55.6% | 378 | 50.5% | +5.0 (-8.2 to +18.3) |
| rumormonger | 264 | 49.2% | 177 | 54.2% | -5.0 (-14.5 to +4.5) |
| clerk | 253 | 53.4% | 188 | 48.4% | +5.0 (-4.5 to +14.4) |
| sexton | 56 | 55.4% | 385 | 50.6% | +4.7 (-9.2 to +18.7) |
| seer | 105 | 54.3% | 336 | 50.3% | +4.0 (-6.9 to +14.9) |
| archivist | 243 | 52.7% | 198 | 49.5% | +3.2 (-6.2 to +12.6) |
| magistrate | 56 | 53.6% | 385 | 50.9% | +2.7 (-11.3 to +16.6) |
| augur | 99 | 49.5% | 342 | 51.8% | -2.3 (-13.4 to +8.9) |
| registrar | 152 | 52.6% | 289 | 50.5% | +2.1 (-7.7 to +11.9) |
| psychologist | 63 | 50.8% | 378 | 51.3% | -0.5 (-13.9 to +12.8) |
| chronicler | 57 | 50.9% | 384 | 51.3% | -0.4 (-14.3 to +13.5) |
| monitor | 64 | 51.6% | 377 | 51.2% | +0.4 (-12.9 to +13.6) |
| warden | 173 | 51.4% | 268 | 51.1% | +0.3 (-9.2 to +9.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner | 191 | 52.4% | 250 | 50.4% | +2.0 (-7.5 to +11.4) |
| revenant | 128 | 50.0% | 313 | 51.8% | -1.8 (-12.0 to +8.5) |
| scion | 122 | 50.8% | 319 | 51.4% | -0.6 (-11.0 to +9.8) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 93 | 46.2% | 348 | 52.6% | -6.3 (-17.8 to +5.1) |
| sleepwalker | 89 | 47.2% | 352 | 52.3% | -5.1 (-16.7 to +6.5) |
| lovers | 76 | 55.3% | 365 | 50.4% | +4.9 (-7.4 to +17.2) |
| muddler | 88 | 54.5% | 353 | 50.4% | +4.1 (-7.5 to +15.8) |
| marked | 95 | 53.7% | 346 | 50.6% | +3.1 (-8.2 to +14.4) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 31 | 64.5% | 410 | 50.2% | +14.3 (-3.3 to +31.8) |
| 4 night-walkers | 153 | 48.4% | 288 | 52.8% | -4.4 (-14.2 to +5.4) |
| 3 night-walkers | 257 | 51.4% | 184 | 51.1% | +0.3 (-9.2 to +9.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 264 | 3.4 | 17.4% | 16.7% | 92.4% |
| surveyor | 261 | 3.2 | 16.5% | 17.2% | 93.1% |
| clerk | 253 | 3.3 | 14.6% | 16.6% | 94.5% |
| archivist | 243 | 2.0 | 54.3% | 11.1% | 90.9% |
| nightwatch | 199 | 2.6 | 30.2% | 15.1% | 89.4% |
| medium | 183 | 2.8 | 24.0% | 16.9% | 83.6% |
| lamplighter | 176 | 3.2 | 18.2% | 18.8% | 92.0% |
| confessor | 175 | 3.0 | 20.6% | 12.6% | 90.9% |
| warden | 173 | 3.3 | 15.6% | 19.7% | 88.4% |
| gravedigger | 158 | 2.8 | 29.7% | 19.0% | 92.4% |
| registrar | 152 | 2.7 | 28.9% | 5.9% | 82.2% |
| dowser | 152 | 2.1 | 50.7% | 6.6% | 90.8% |
| seer | 105 | 2.3 | 38.1% | 11.4% | 84.8% |
| augur | 99 | 3.0 | 21.2% | 10.1% | 88.9% |
| veteran | 74 | 4.2 | 1.4% | 28.4% | 91.9% |
| monitor | 64 | 2.8 | 25.0% | 10.9% | 78.1% |
| psychologist | 63 | 2.9 | 17.5% | 17.5% | 87.3% |
| executor | 63 | 3.1 | 17.5% | 7.9% | 82.5% |
| martyr | 61 | 3.8 | 14.8% | 21.3% | 88.5% |
| chronicler | 57 | 3.2 | 17.5% | 5.3% | 87.7% |
| magistrate | 56 | 2.8 | 26.8% | 8.9% | 82.1% |
| sexton | 56 | 3.7 | 8.9% | 28.6% | 80.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 100 | 0.0% | 53.0% |
| gravedigger | 90 | 0.0% | 63.3% |
| dowser | 89 | 0.0% | 59.6% |
| confessor | 86 | 0.0% | 60.5% |
| archivist | 84 | 0.0% | 60.7% |
| surveyor | 80 | 0.0% | 58.8% |
| clerk | 79 | 0.0% | 49.4% |
| rumormonger | 77 | 0.0% | 51.9% |
| lamplighter | 73 | 0.0% | 50.7% |
| medium | 68 | 0.0% | 50.0% |
| magistrate | 60 | 0.0% | 53.3% |
| nightwatch | 58 | 0.0% | 34.5% |
| monitor | 56 | 0.0% | 23.2% |
| seer | 52 | 0.0% | 50.0% |
| chronicler | 51 | 0.0% | 35.3% |
| executor | 48 | 0.0% | 35.4% |
| psychologist | 46 | 0.0% | 41.3% |
| augur | 43 | 0.0% | 48.8% |
| sexton | 17 | 0.0% | 23.5% |
| veteran | 10 | 0.0% | 50.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 219 | 61 (27.9%) | 16 (7.3%) | 115 | 27 |
| 10 | 10 NPCs, bot insight 1.0 | 440 | 130 (29.5%) | 51 (11.6%) | 175 | 84 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: 7 NPCs, bot insight 1.0: 781 (first 100001, 100002, 100004, 100005, 100006, 100008, 100009, 100010, 100011, 100013); 7 NPCs, passive: 781 (first 100001, 100002, 100004, 100005, 100006, 100008, 100009, 100010, 100011, 100013); 10 NPCs, bot insight 1.0: 559 (first 100000, 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010); 10 NPCs, passive: 559 (first 100000, 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010)
- Failed games (crash or timeout): 1 — seeds 100632 (timeout)
- Games with engine errors: 0
- Shared-model fallbacks: 4 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 63.3 | 119.4 | 217.0 |
| 7 NPCs, passive | 2.8 | 4.5 | 13.4 |
| 10 NPCs, bot insight 1.0 | 327.7 | 758.0 | 1660.1 |
| 10 NPCs, passive | 29.3 | 52.1 | 115.8 |

Slowest seeds: 100157 (10 NPCs bot, 1660 s), 100084 (10 NPCs bot, 1259 s), 100493 (10 NPCs bot, 1229 s), 100855 (10 NPCs bot, 1191 s), 100298 (10 NPCs bot, 1138 s), 100123 (10 NPCs bot, 1125 s), 100252 (10 NPCs bot, 1089 s), 100542 (10 NPCs bot, 1081 s), 100515 (10 NPCs bot, 1063 s), 100287 (10 NPCs bot, 1048 s), 100600 (10 NPCs bot, 1029 s), 100450 (10 NPCs bot, 1029 s), 100861 (10 NPCs bot, 1014 s), 100913 (10 NPCs bot, 984 s), 100506 (10 NPCs bot, 963 s), 100484 (10 NPCs bot, 962 s), 100633 (10 NPCs bot, 950 s), 100330 (10 NPCs bot, 940 s), 100147 (10 NPCs bot, 937 s), 100106 (10 NPCs bot, 936 s)

