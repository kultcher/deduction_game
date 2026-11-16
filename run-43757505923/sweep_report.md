# Balance sweep report

Records: 1320 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `88d22cbfc1`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 219 | 65.3% (58.8%–71.3%) | 2.98 | 0.70 | 1.08 | 2.28 | 9.1% | 0.30 |
| 7 NPCs, passive | 219 | 51.1% (44.6%–57.7%) | 3.41 | 0.70 | 0.89 | 2.36 | 4.1% | 0.23 |
| 10 NPCs, bot insight 1.0 | 441 | 63.9% (59.4%–68.3%) | 4.09 | 0.97 | 1.60 | 2.54 | 7.9% | 0.50 |
| 10 NPCs, passive | 441 | 40.4% (35.9%–45.0%) | 4.57 | 1.33 | 1.26 | 2.55 | 4.1% | 0.56 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.74 | 20.2% | 29.5% | 1.94 | 13.9% | 14.1% | 13.1% |
| 7 NPCs, passive | 6.20 | 15.2% | 38.4% | 2.88 | 23.8% | 22.8% | 21.2% |
| 10 NPCs, bot insight 1.0 | 8.84 | 12.2% | 27.0% | 3.75 | 15.3% | 14.7% | 13.5% |
| 10 NPCs, passive | 10.83 | 9.6% | 32.4% | 5.07 | 25.5% | 25.4% | 22.5% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=219)

- The demon's host was executed.: 143 (65.3%)
- Only two townsfolk remain and the demon still walks among them.: 76 (34.7%)
- Demon evidence on the board: 98.2% of games; good win rate 64.7% of 215
- Demon evidence reachable: 83.6% of games; good win rate 62.3% of 183
- Neither: 1.4% of games; good win rate 100.0% of 3
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=219)

- The demon's host was executed.: 112 (51.1%)
- Only two townsfolk remain and the demon still walks among them.: 107 (48.9%)
- Demon evidence on the board: 68.0% of games; good win rate 61.1% of 149
- Demon evidence reachable: 99.1% of games; good win rate 50.7% of 217
- Neither: 0.9% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot insight 1.0** (n=441)

- The demon's host was executed.: 282 (63.9%)
- Only two townsfolk remain and the demon still walks among them.: 110 (24.9%)
- No good soul remains.: 47 (10.7%)
- Time ran out: the demon survived 8 days.: 2 (0.5%)
- Demon evidence on the board: 99.3% of games; good win rate 63.7% of 438
- Demon evidence reachable: 88.0% of games; good win rate 60.8% of 388
- Neither: 0.2% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, passive** (n=441)

- The demon's host was executed.: 178 (40.4%)
- Only two townsfolk remain and the demon still walks among them.: 131 (29.7%)
- No good soul remains.: 130 (29.5%)
- Time ran out: the demon survived 8 days.: 2 (0.5%)
- Demon evidence on the board: 79.8% of games; good win rate 42.3% of 352
- Demon evidence reachable: 100.0% of games; good win rate 40.4% of 441
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| clerk | 127 | 70.9% | 92 | 57.6% | +13.3 (+0.4 to +26.1) **\*** |
| augur | 46 | 56.5% | 173 | 67.6% | -11.1 (-27.0 to +4.8) |
| seer | 31 | 74.2% | 188 | 63.8% | +10.4 (-6.5 to +27.2) |
| surveyor | 103 | 60.2% | 116 | 69.8% | -9.6 (-22.2 to +3.0) |
| rumormonger | 99 | 60.6% | 120 | 69.2% | -8.6 (-21.2 to +4.1) |
| dowser | 53 | 71.7% | 166 | 63.3% | +8.4 (-5.7 to +22.6) |
| nightwatch | 55 | 69.1% | 164 | 64.0% | +5.1 (-9.2 to +19.3) |
| medium | 42 | 69.0% | 177 | 64.4% | +4.6 (-11.0 to +20.3) |
| archivist | 130 | 66.9% | 89 | 62.9% | +4.0 (-8.9 to +16.9) |
| confessor | 53 | 62.3% | 166 | 66.3% | -4.0 (-18.9 to +10.9) |
| warden | 70 | 62.9% | 149 | 66.4% | -3.6 (-17.2 to +10.0) |
| gravedigger | 59 | 64.4% | 160 | 65.6% | -1.2 (-15.5 to +13.0) |
| registrar | 62 | 66.1% | 157 | 65.0% | +1.2 (-12.8 to +15.1) |
| lamplighter | 44 | 65.9% | 175 | 65.1% | +0.8 (-14.9 to +16.5) |

**Minions**

_Not enough games._

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lovers | 47 | 72.3% | 172 | 63.4% | +9.0 (-5.7 to +23.6) |
| sleepwalker | 48 | 58.3% | 171 | 67.3% | -8.9 (-24.5 to +6.7) |
| delusional | 42 | 59.5% | 177 | 66.7% | -7.1 (-23.5 to +9.2) |
| marked | 35 | 68.6% | 184 | 64.7% | +3.9 (-13.0 to +20.8) |
| muddler | 47 | 68.1% | 172 | 64.5% | +3.6 (-11.6 to +18.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 174 | 64.9% | 45 | 66.7% | -1.7 (-17.2 to +13.8) |
| 3 night-walkers | 45 | 66.7% | 174 | 64.9% | +1.7 (-13.8 to +17.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 130 | 1.5 | 54.6% | 13.8% | 95.4% |
| clerk | 127 | 2.2 | 20.5% | 9.4% | 92.9% |
| surveyor | 103 | 2.3 | 23.3% | 18.4% | 90.3% |
| rumormonger | 99 | 2.1 | 21.2% | 18.2% | 88.9% |
| warden | 70 | 2.1 | 20.0% | 22.9% | 72.9% |
| registrar | 62 | 2.2 | 33.9% | 4.8% | 71.0% |
| gravedigger | 59 | 1.9 | 33.9% | 10.2% | 81.4% |
| nightwatch | 55 | 1.6 | 36.4% | 16.4% | 78.2% |
| dowser | 53 | 1.8 | 45.3% | 9.4% | 88.7% |
| confessor | 53 | 2.0 | 26.4% | 26.4% | 69.8% |
| augur | 46 | 2.1 | 23.9% | 15.2% | 87.0% |
| lamplighter | 44 | 1.8 | 34.1% | 13.6% | 86.4% |
| medium | 42 | 1.8 | 33.3% | 4.8% | 69.0% |
| seer | 31 | 1.9 | 32.3% | 3.2% | 77.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| surveyor | 34 | 0.0% | 52.9% |
| registrar | 33 | 0.0% | 57.6% |
| gravedigger | 31 | 0.0% | 61.3% |
| nightwatch | 30 | 0.0% | 50.0% |
| lamplighter | 29 | 0.0% | 79.3% |
| rumormonger | 28 | 0.0% | 57.1% |
| confessor | 28 | 0.0% | 71.4% |
| dowser | 27 | 0.0% | 66.7% |
| seer | 20 | 0.0% | 40.0% |
| archivist | 19 | 0.0% | 73.7% |
| clerk | 19 | 0.0% | 47.4% |
| medium | 18 | 0.0% | 55.6% |
| executor | 17 | 0.0% | 41.2% |
| psychologist | 17 | 0.0% | 52.9% |
| magistrate | 15 | 0.0% | 66.7% |
| augur | 14 | 0.0% | 42.9% |
| monitor | 13 | 0.0% | 38.5% |
| chronicler | 12 | 0.0% | 75.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 55 | 67.3% | 164 | 45.7% | +21.5 (+7.0 to +36.1) **\*** |
| medium | 42 | 40.5% | 177 | 53.7% | -13.2 (-29.8 to +3.4) |
| augur | 46 | 41.3% | 173 | 53.8% | -12.5 (-28.5 to +3.6) |
| dowser | 53 | 60.4% | 166 | 48.2% | +12.2 (-3.0 to +27.4) |
| lamplighter | 44 | 43.2% | 175 | 53.1% | -10.0 (-26.4 to +6.4) |
| gravedigger | 59 | 44.1% | 160 | 53.8% | -9.7 (-24.5 to +5.2) |
| registrar | 62 | 58.1% | 157 | 48.4% | +9.7 (-4.9 to +24.2) |
| confessor | 53 | 56.6% | 166 | 49.4% | +7.2 (-8.2 to +22.6) |
| rumormonger | 99 | 48.5% | 120 | 53.3% | -4.8 (-18.1 to +8.4) |
| clerk | 127 | 52.8% | 92 | 48.9% | +3.8 (-9.6 to +17.2) |
| warden | 70 | 48.6% | 149 | 52.3% | -3.8 (-18.0 to +10.4) |
| seer | 31 | 48.4% | 188 | 51.6% | -3.2 (-22.2 to +15.8) |
| surveyor | 103 | 49.5% | 116 | 52.6% | -3.1 (-16.3 to +10.2) |
| archivist | 130 | 51.5% | 89 | 50.6% | +1.0 (-12.5 to +14.5) |

**Minions**

_Not enough games._

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 42 | 31.0% | 177 | 55.9% | -25.0 (-40.8 to -9.2) **\*** |
| muddler | 47 | 66.0% | 172 | 47.1% | +18.9 (+3.4 to +34.3) **\*** |
| lovers | 47 | 61.7% | 172 | 48.3% | +13.4 (-2.3 to +29.2) |
| sleepwalker | 48 | 41.7% | 171 | 53.8% | -12.1 (-28.0 to +3.7) |
| marked | 35 | 54.3% | 184 | 50.5% | +3.7 (-14.3 to +21.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 174 | 50.0% | 45 | 55.6% | -5.6 (-21.9 to +10.8) |
| 3 night-walkers | 45 | 55.6% | 174 | 50.0% | +5.6 (-10.8 to +21.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 130 | 1.6 | 63.1% | 21.5% | 94.6% |
| clerk | 127 | 2.8 | 14.2% | 18.1% | 92.9% |
| surveyor | 103 | 2.6 | 20.4% | 18.4% | 94.2% |
| rumormonger | 99 | 2.3 | 32.3% | 19.2% | 88.9% |
| warden | 70 | 2.8 | 15.7% | 14.3% | 84.3% |
| registrar | 62 | 2.3 | 30.6% | 4.8% | 85.5% |
| gravedigger | 59 | 2.0 | 52.5% | 3.4% | 89.8% |
| nightwatch | 55 | 2.2 | 32.7% | 9.1% | 89.1% |
| confessor | 53 | 2.3 | 39.6% | 5.7% | 83.0% |
| dowser | 53 | 1.8 | 50.9% | 3.8% | 92.5% |
| augur | 46 | 2.3 | 37.0% | 8.7% | 80.4% |
| lamplighter | 44 | 2.5 | 27.3% | 13.6% | 81.8% |
| medium | 42 | 2.5 | 40.5% | 7.1% | 81.0% |
| seer | 31 | 2.0 | 48.4% | 6.5% | 74.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| surveyor | 35 | 0.0% | 45.7% |
| registrar | 34 | 0.0% | 44.1% |
| gravedigger | 34 | 0.0% | 58.8% |
| confessor | 30 | 0.0% | 73.3% |
| nightwatch | 29 | 0.0% | 31.0% |
| rumormonger | 28 | 0.0% | 57.1% |
| lamplighter | 28 | 0.0% | 50.0% |
| dowser | 27 | 0.0% | 44.4% |
| medium | 21 | 0.0% | 23.8% |
| seer | 20 | 0.0% | 40.0% |
| clerk | 19 | 0.0% | 52.6% |
| archivist | 18 | 0.0% | 72.2% |
| psychologist | 17 | 0.0% | 35.3% |
| executor | 16 | 0.0% | 50.0% |
| magistrate | 15 | 0.0% | 33.3% |
| augur | 15 | 0.0% | 33.3% |
| monitor | 13 | 0.0% | 7.7% |
| chronicler | 11 | 0.0% | 72.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 57 | 56.1% | 384 | 65.1% | -9.0 (-22.7 to +4.8) |
| dowser | 152 | 68.4% | 289 | 61.6% | +6.8 (-2.4 to +16.1) |
| archivist | 243 | 66.7% | 198 | 60.6% | +6.1 (-3.0 to +15.1) |
| gravedigger | 158 | 60.8% | 283 | 65.7% | -5.0 (-14.4 to +4.4) |
| magistrate | 56 | 67.9% | 385 | 63.4% | +4.5 (-8.7 to +17.6) |
| executor | 63 | 60.3% | 378 | 64.6% | -4.2 (-17.2 to +8.8) |
| confessor | 175 | 66.3% | 266 | 62.4% | +3.9 (-5.2 to +13.0) |
| martyr | 61 | 60.7% | 380 | 64.5% | -3.8 (-17.0 to +9.4) |
| veteran | 74 | 60.8% | 367 | 64.6% | -3.8 (-15.9 to +8.4) |
| registrar | 152 | 65.8% | 289 | 63.0% | +2.8 (-6.6 to +12.2) |
| clerk | 253 | 62.8% | 188 | 65.4% | -2.6 (-11.6 to +6.5) |
| sexton | 56 | 66.1% | 385 | 63.6% | +2.4 (-10.9 to +15.7) |
| psychologist | 63 | 61.9% | 378 | 64.3% | -2.4 (-15.3 to +10.5) |
| seer | 105 | 65.7% | 336 | 63.4% | +2.3 (-8.1 to +12.8) |
| warden | 173 | 65.3% | 268 | 63.1% | +2.3 (-6.9 to +11.4) |
| nightwatch | 199 | 62.8% | 242 | 64.9% | -2.1 (-11.1 to +7.0) |
| surveyor | 261 | 63.2% | 180 | 65.0% | -1.8 (-10.9 to +7.3) |
| augur | 99 | 62.6% | 342 | 64.3% | -1.7 (-12.5 to +9.1) |
| monitor | 64 | 62.5% | 377 | 64.2% | -1.7 (-14.5 to +11.1) |
| lamplighter | 176 | 63.1% | 265 | 64.5% | -1.5 (-10.6 to +7.7) |
| rumormonger | 264 | 64.0% | 177 | 63.8% | +0.2 (-9.0 to +9.3) |
| medium | 183 | 63.9% | 258 | 64.0% | -0.0 (-9.1 to +9.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| scion | 122 | 57.4% | 319 | 66.5% | -9.1 (-19.3 to +1.1) |
| revenant | 128 | 67.2% | 313 | 62.6% | +4.6 (-5.2 to +14.3) |
| poisoner | 191 | 66.0% | 250 | 62.4% | +3.6 (-5.4 to +12.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| muddler | 88 | 72.7% | 353 | 61.8% | +11.0 (+0.4 to +21.6) **\*** |
| sleepwalker | 89 | 56.2% | 352 | 65.9% | -9.7 (-21.2 to +1.7) |
| delusional | 93 | 66.7% | 348 | 63.2% | +3.4 (-7.4 to +14.3) |
| lovers | 76 | 61.8% | 365 | 64.4% | -2.5 (-14.5 to +9.4) |
| marked | 95 | 62.1% | 346 | 64.5% | -2.3 (-13.3 to +8.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 153 | 68.0% | 288 | 61.8% | +6.2 (-3.1 to +15.4) |
| 3 night-walkers | 257 | 61.5% | 184 | 67.4% | -5.9 (-14.9 to +3.1) |
| 5 night-walkers | 31 | 64.5% | 410 | 63.9% | +0.6 (-16.9 to +18.1) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 264 | 3.0 | 17.4% | 15.5% | 93.9% |
| surveyor | 261 | 3.0 | 14.9% | 14.9% | 95.8% |
| clerk | 253 | 3.3 | 10.7% | 11.9% | 94.5% |
| archivist | 243 | 1.7 | 57.6% | 11.1% | 94.7% |
| nightwatch | 199 | 2.4 | 26.6% | 16.1% | 91.0% |
| medium | 183 | 2.7 | 24.0% | 9.8% | 84.7% |
| lamplighter | 176 | 2.8 | 15.3% | 17.6% | 97.7% |
| confessor | 175 | 2.7 | 20.6% | 26.3% | 89.1% |
| warden | 173 | 3.2 | 12.7% | 23.7% | 90.8% |
| gravedigger | 158 | 2.6 | 27.8% | 10.1% | 91.8% |
| dowser | 152 | 2.1 | 48.7% | 5.3% | 92.1% |
| registrar | 152 | 2.6 | 26.3% | 6.6% | 84.9% |
| seer | 105 | 2.4 | 39.0% | 7.6% | 87.6% |
| augur | 99 | 2.8 | 21.2% | 8.1% | 81.8% |
| veteran | 74 | 3.8 | 1.4% | 21.6% | 93.2% |
| monitor | 64 | 2.5 | 17.2% | 7.8% | 79.7% |
| executor | 63 | 3.1 | 12.7% | 7.9% | 90.5% |
| psychologist | 63 | 2.9 | 11.1% | 25.4% | 87.3% |
| martyr | 61 | 3.6 | 9.8% | 11.5% | 85.2% |
| chronicler | 57 | 3.1 | 17.5% | 10.5% | 78.9% |
| sexton | 56 | 3.0 | 10.7% | 26.8% | 82.1% |
| magistrate | 56 | 2.7 | 28.6% | 5.4% | 82.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 97 | 0.0% | 44.3% |
| dowser | 88 | 0.0% | 64.8% |
| gravedigger | 85 | 0.0% | 61.2% |
| archivist | 84 | 0.0% | 53.6% |
| confessor | 83 | 0.0% | 79.5% |
| surveyor | 80 | 0.0% | 52.5% |
| clerk | 79 | 0.0% | 48.1% |
| lamplighter | 76 | 0.0% | 68.4% |
| rumormonger | 75 | 0.0% | 66.7% |
| medium | 65 | 0.0% | 60.0% |
| nightwatch | 57 | 0.0% | 66.7% |
| magistrate | 56 | 0.0% | 60.7% |
| monitor | 55 | 0.0% | 36.4% |
| psychologist | 51 | 0.0% | 35.3% |
| seer | 51 | 0.0% | 37.3% |
| chronicler | 50 | 0.0% | 38.0% |
| executor | 48 | 0.0% | 35.4% |
| augur | 44 | 0.0% | 56.8% |
| sexton | 15 | 0.0% | 33.3% |
| veteran | 10 | 0.0% | 20.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 57 | 22.8% | 384 | 43.0% | -20.2 (-32.1 to -8.2) **\*** |
| nightwatch | 199 | 47.7% | 242 | 34.3% | +13.4 (+4.3 to +22.6) **\*** |
| magistrate | 56 | 48.2% | 385 | 39.2% | +9.0 (-5.0 to +23.0) |
| monitor | 64 | 32.8% | 377 | 41.6% | -8.8 (-21.4 to +3.7) |
| medium | 183 | 36.6% | 258 | 43.0% | -6.4 (-15.6 to +2.8) |
| lamplighter | 176 | 36.9% | 265 | 42.6% | -5.7 (-15.0 to +3.6) |
| dowser | 152 | 44.1% | 289 | 38.4% | +5.7 (-4.0 to +15.4) |
| archivist | 243 | 42.8% | 198 | 37.4% | +5.4 (-3.7 to +14.6) |
| confessor | 175 | 43.4% | 266 | 38.3% | +5.1 (-4.3 to +14.5) |
| psychologist | 63 | 44.4% | 378 | 39.7% | +4.8 (-8.5 to +18.0) |
| gravedigger | 158 | 37.3% | 283 | 42.0% | -4.7 (-14.2 to +4.8) |
| clerk | 253 | 42.3% | 188 | 37.8% | +4.5 (-4.7 to +13.8) |
| executor | 63 | 36.5% | 378 | 41.0% | -4.5 (-17.4 to +8.4) |
| rumormonger | 264 | 38.6% | 177 | 42.9% | -4.3 (-13.7 to +5.1) |
| warden | 173 | 38.2% | 268 | 41.8% | -3.6 (-13.0 to +5.7) |
| veteran | 74 | 43.2% | 367 | 39.8% | +3.5 (-8.9 to +15.8) |
| seer | 105 | 39.0% | 336 | 40.8% | -1.7 (-12.4 to +9.0) |
| registrar | 152 | 41.4% | 289 | 39.8% | +1.7 (-8.0 to +11.3) |
| augur | 99 | 39.4% | 342 | 40.6% | -1.2 (-12.2 to +9.7) |
| sexton | 56 | 39.3% | 385 | 40.5% | -1.2 (-14.9 to +12.5) |
| martyr | 61 | 39.3% | 380 | 40.5% | -1.2 (-14.4 to +12.0) |
| surveyor | 261 | 40.2% | 180 | 40.6% | -0.3 (-9.6 to +9.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 128 | 43.8% | 313 | 39.0% | +4.8 (-5.4 to +14.9) |
| scion | 122 | 37.7% | 319 | 41.4% | -3.7 (-13.8 to +6.5) |
| poisoner | 191 | 39.8% | 250 | 40.8% | -1.0 (-10.2 to +8.2) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 93 | 32.3% | 348 | 42.5% | -10.3 (-21.1 to +0.6) |
| lovers | 76 | 46.1% | 365 | 39.2% | +6.9 (-5.4 to +19.1) |
| marked | 95 | 43.2% | 346 | 39.6% | +3.6 (-7.7 to +14.8) |
| muddler | 88 | 40.9% | 353 | 40.2% | +0.7 (-10.8 to +12.2) |
| sleepwalker | 89 | 40.4% | 352 | 40.3% | +0.1 (-11.3 to +11.5) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 31 | 45.2% | 410 | 40.0% | +5.2 (-13.0 to +23.3) |
| 4 night-walkers | 153 | 39.9% | 288 | 40.6% | -0.8 (-10.4 to +8.9) |
| 3 night-walkers | 257 | 40.1% | 184 | 40.8% | -0.7 (-10.0 to +8.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 264 | 3.6 | 15.9% | 22.7% | 95.5% |
| surveyor | 261 | 3.4 | 16.1% | 23.4% | 95.8% |
| clerk | 253 | 3.7 | 10.7% | 19.4% | 96.4% |
| archivist | 243 | 2.0 | 56.8% | 12.3% | 97.1% |
| nightwatch | 199 | 2.5 | 32.2% | 20.1% | 89.9% |
| medium | 183 | 2.9 | 23.5% | 19.1% | 93.4% |
| lamplighter | 176 | 3.1 | 17.6% | 21.6% | 93.8% |
| confessor | 175 | 2.8 | 29.1% | 19.4% | 91.4% |
| warden | 173 | 3.6 | 12.7% | 27.7% | 93.1% |
| gravedigger | 158 | 2.6 | 38.6% | 15.2% | 91.8% |
| registrar | 152 | 2.8 | 30.9% | 5.3% | 86.8% |
| dowser | 152 | 2.1 | 50.7% | 13.2% | 96.7% |
| seer | 105 | 2.5 | 38.1% | 13.3% | 90.5% |
| augur | 99 | 3.0 | 22.2% | 14.1% | 85.9% |
| veteran | 74 | 4.5 | 5.4% | 37.8% | 90.5% |
| monitor | 64 | 3.3 | 21.9% | 12.5% | 89.1% |
| psychologist | 63 | 3.2 | 14.3% | 17.5% | 92.1% |
| executor | 63 | 3.2 | 12.7% | 15.9% | 87.3% |
| martyr | 61 | 4.3 | 4.9% | 23.0% | 95.1% |
| chronicler | 57 | 3.0 | 22.8% | 15.8% | 93.0% |
| magistrate | 56 | 2.9 | 26.8% | 8.9% | 82.1% |
| sexton | 56 | 3.7 | 3.6% | 44.6% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 98 | 0.0% | 37.8% |
| dowser | 87 | 0.0% | 60.9% |
| gravedigger | 87 | 0.0% | 49.4% |
| confessor | 87 | 0.0% | 48.3% |
| archivist | 85 | 0.0% | 40.0% |
| clerk | 80 | 0.0% | 52.5% |
| surveyor | 79 | 0.0% | 43.0% |
| rumormonger | 77 | 0.0% | 41.6% |
| lamplighter | 75 | 0.0% | 41.3% |
| medium | 67 | 0.0% | 47.8% |
| magistrate | 61 | 0.0% | 44.3% |
| nightwatch | 56 | 0.0% | 37.5% |
| monitor | 54 | 0.0% | 24.1% |
| seer | 52 | 0.0% | 34.6% |
| executor | 50 | 0.0% | 40.0% |
| chronicler | 49 | 0.0% | 40.8% |
| psychologist | 48 | 0.0% | 39.6% |
| augur | 42 | 0.0% | 50.0% |
| sexton | 17 | 0.0% | 23.5% |
| warden | 10 | 0.0% | 40.0% |
| veteran | 10 | 0.0% | 30.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 219 | 56 (25.6%) | 25 (11.4%) | 87 | 51 |
| 10 | 10 NPCs, bot insight 1.0 | 441 | 155 (35.1%) | 51 (11.6%) | 127 | 108 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: 7 NPCs, bot insight 1.0: 781 (first 100001, 100002, 100004, 100005, 100006, 100008, 100009, 100010, 100011, 100013); 7 NPCs, passive: 781 (first 100001, 100002, 100004, 100005, 100006, 100008, 100009, 100010, 100011, 100013); 10 NPCs, bot insight 1.0: 559 (first 100000, 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010); 10 NPCs, passive: 559 (first 100000, 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010)
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 2 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 56.2 | 107.0 | 304.8 |
| 7 NPCs, passive | 2.5 | 4.3 | 7.0 |
| 10 NPCs, bot insight 1.0 | 282.1 | 666.2 | 1506.7 |
| 10 NPCs, passive | 30.8 | 57.8 | 133.1 |

Slowest seeds: 100263 (10 NPCs bot, 1507 s), 100289 (10 NPCs bot, 1438 s), 100097 (10 NPCs bot, 1300 s), 100572 (10 NPCs bot, 1270 s), 100947 (10 NPCs bot, 1056 s), 100084 (10 NPCs bot, 1050 s), 100329 (10 NPCs bot, 1045 s), 100899 (10 NPCs bot, 1032 s), 100977 (10 NPCs bot, 982 s), 100047 (10 NPCs bot, 965 s), 100294 (10 NPCs bot, 900 s), 100979 (10 NPCs bot, 886 s), 100298 (10 NPCs bot, 881 s), 100169 (10 NPCs bot, 869 s), 100318 (10 NPCs bot, 865 s), 100959 (10 NPCs bot, 848 s), 100473 (10 NPCs bot, 844 s), 100217 (10 NPCs bot, 808 s), 100370 (10 NPCs bot, 797 s), 100939 (10 NPCs bot, 779 s)

