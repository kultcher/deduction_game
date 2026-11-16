# Balance sweep report

Records: 800 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `432bf7b18e`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 59.5% (52.6%–66.1%) | 3.10 | 0.62 | 1.12 | 2.20 | 10.5% | 0.25 |
| 7 NPCs, bot, no presenting insight 1.0 | 200 | 53.0% (46.1%–59.8%) | 3.29 | 0.73 | 1.09 | 2.40 | 10.0% | 0.21 |
| 7 NPCs, passive | 200 | 39.5% (33.0%–46.4%) | 3.46 | 0.83 | 0.87 | 2.42 | 7.0% | 0.21 |
| 7 NPCs, bot, present and vote insight 1.0 | 200 | 49.0% (42.2%–55.9%) | 3.21 | 0.76 | 0.99 | 2.32 | 10.0% | 0.30 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 5.22 | 18.0% | 29.0% | 2.08 | 14.5% | 13.8% | 12.3% |
| 7 NPCs, bot, no presenting insight 1.0 | 5.30 | 19.8% | 30.2% | 2.63 | 25.3% | 23.6% | 19.4% |
| 7 NPCs, passive | 6.33 | 18.6% | 39.2% | 2.94 | 26.8% | 25.8% | 23.5% |
| 7 NPCs, bot, present and vote insight 1.0 | 5.45 | 18.0% | 30.9% | 2.04 | 17.2% | 17.0% | 14.4% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 119 (59.5%)
- Only two townsfolk remain and the demon still walks among them.: 81 (40.5%)
- Demon evidence on the board: 96.0% of games; good win rate 57.8% of 192
- Demon evidence reachable: 82.5% of games; good win rate 53.9% of 165
- Neither: 4.0% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no presenting insight 1.0** (n=200)

- The demon's host was executed.: 106 (53.0%)
- Only two townsfolk remain and the demon still walks among them.: 94 (47.0%)
- Demon evidence on the board: 96.0% of games; good win rate 51.0% of 192
- Demon evidence reachable: 84.0% of games; good win rate 50.0% of 168
- Neither: 3.0% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=200)

- Only two townsfolk remain and the demon still walks among them.: 121 (60.5%)
- The demon's host was executed.: 79 (39.5%)
- Demon evidence on the board: 61.5% of games; good win rate 46.3% of 123
- Demon evidence reachable: 99.5% of games; good win rate 39.2% of 199
- Neither: 0.5% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, present and vote insight 1.0** (n=200)

- Only two townsfolk remain and the demon still walks among them.: 100 (50.0%)
- The demon's host was executed.: 98 (49.0%)
- Time ran out: the demon survived 6 days.: 2 (1.0%)
- Demon evidence on the board: 58.5% of games; good win rate 56.4% of 117
- Demon evidence reachable: 97.5% of games; good win rate 47.7% of 195
- Neither: 2.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| dowser | 53 | 75.5% | 147 | 53.7% | +21.7 (+7.6 to +35.8) **\*** |
| gravedigger | 53 | 47.2% | 147 | 63.9% | -16.8 (-32.3 to -1.3) **\*** |
| confessor | 44 | 50.0% | 156 | 62.2% | -12.2 (-28.8 to +4.4) |
| registrar | 66 | 66.7% | 134 | 56.0% | +10.7 (-3.4 to +24.8) |
| warden | 53 | 66.0% | 147 | 57.1% | +8.9 (-6.2 to +23.9) |
| seer | 32 | 53.1% | 168 | 60.7% | -7.6 (-26.4 to +11.2) |
| medium | 32 | 65.6% | 168 | 58.3% | +7.3 (-10.8 to +25.4) |
| lamplighter | 42 | 57.1% | 158 | 60.1% | -3.0 (-19.8 to +13.8) |
| surveyor | 96 | 58.3% | 104 | 60.6% | -2.2 (-15.9 to +11.4) |
| nightwatch | 50 | 58.0% | 150 | 60.0% | -2.0 (-17.8 to +13.8) |
| rumormonger | 102 | 58.8% | 98 | 60.2% | -1.4 (-15.0 to +12.2) |
| archivist | 108 | 59.3% | 92 | 59.8% | -0.5 (-14.2 to +13.1) |
| clerk | 114 | 59.6% | 86 | 59.3% | +0.3 (-13.4 to +14.1) |
| augur | 37 | 59.5% | 163 | 59.5% | -0.0 (-17.6 to +17.5) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 64.7% | 149 | 57.7% | +7.0 (-8.3 to +22.3) |
| revenant | 35 | 54.3% | 165 | 60.6% | -6.3 (-24.4 to +11.8) |
| poisoner | 59 | 57.6% | 141 | 60.3% | -2.7 (-17.6 to +12.3) |
| scion | 55 | 60.0% | 145 | 59.3% | +0.7 (-14.5 to +15.9) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lovers | 46 | 69.6% | 154 | 56.5% | +13.1 (-2.4 to +28.5) |
| sleepwalker | 37 | 51.4% | 163 | 61.3% | -10.0 (-27.8 to +7.8) |
| marked | 38 | 55.3% | 162 | 60.5% | -5.2 (-22.7 to +12.3) |
| delusional | 34 | 55.9% | 166 | 60.2% | -4.4 (-22.6 to +13.9) |
| muddler | 45 | 62.2% | 155 | 58.7% | +3.5 (-12.6 to +19.7) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 70 | 62.9% | 130 | 57.7% | +5.2 (-9.0 to +19.3) |
| 2 night-walkers | 125 | 59.2% | 75 | 60.0% | -0.8 (-14.8 to +13.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.4 | 18.4% | 17.5% | 94.7% |
| archivist | 108 | 1.5 | 55.6% | 14.8% | 96.3% |
| rumormonger | 102 | 2.4 | 21.6% | 10.8% | 94.1% |
| surveyor | 96 | 2.3 | 21.9% | 9.4% | 90.6% |
| registrar | 66 | 2.2 | 31.8% | 3.0% | 80.3% |
| warden | 53 | 2.3 | 28.3% | 9.4% | 67.9% |
| gravedigger | 53 | 1.9 | 47.2% | 13.2% | 88.7% |
| dowser | 53 | 1.7 | 45.3% | 7.5% | 88.7% |
| nightwatch | 50 | 2.1 | 28.0% | 20.0% | 86.0% |
| confessor | 44 | 1.9 | 31.8% | 27.3% | 84.1% |
| lamplighter | 42 | 2.3 | 19.0% | 9.5% | 85.7% |
| augur | 37 | 2.3 | 35.1% | 10.8% | 81.1% |
| medium | 32 | 2.2 | 15.6% | 9.4% | 78.1% |
| seer | 32 | 1.9 | 53.1% | 9.4% | 90.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 72.2% |
| confessor | 32 | 0.0% | 75.0% |
| dowser | 29 | 0.0% | 65.5% |
| medium | 25 | 0.0% | 28.0% |
| rumormonger | 24 | 0.0% | 58.3% |
| lamplighter | 23 | 0.0% | 60.9% |
| surveyor | 23 | 0.0% | 60.9% |
| clerk | 22 | 0.0% | 45.5% |
| archivist | 20 | 0.0% | 65.0% |
| gravedigger | 19 | 0.0% | 73.7% |
| magistrate | 17 | 0.0% | 76.5% |
| psychologist | 17 | 0.0% | 64.7% |
| registrar | 16 | 0.0% | 37.5% |
| chronicler | 16 | 0.0% | 43.8% |
| augur | 16 | 0.0% | 56.2% |
| executor | 13 | 0.0% | 53.8% |
| seer | 13 | 0.0% | 46.2% |
| monitor | 12 | 0.0% | 41.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no presenting insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 53 | 37.7% | 147 | 58.5% | -20.8 (-36.1 to -5.5) **\*** |
| surveyor | 96 | 46.9% | 104 | 58.7% | -11.8 (-25.5 to +2.0) |
| medium | 32 | 43.8% | 168 | 54.8% | -11.0 (-29.8 to +7.8) |
| nightwatch | 50 | 60.0% | 150 | 50.7% | +9.3 (-6.4 to +25.1) |
| rumormonger | 102 | 55.9% | 98 | 50.0% | +5.9 (-7.9 to +19.7) |
| seer | 32 | 56.2% | 168 | 52.4% | +3.9 (-14.9 to +22.6) |
| clerk | 114 | 54.4% | 86 | 51.2% | +3.2 (-10.7 to +17.2) |
| dowser | 53 | 54.7% | 147 | 52.4% | +2.3 (-13.3 to +18.0) |
| registrar | 66 | 54.5% | 134 | 52.2% | +2.3 (-12.4 to +17.0) |
| lamplighter | 42 | 54.8% | 158 | 52.5% | +2.2 (-14.7 to +19.2) |
| augur | 37 | 54.1% | 163 | 52.8% | +1.3 (-16.5 to +19.1) |
| confessor | 44 | 52.3% | 156 | 53.2% | -0.9 (-17.6 to +15.8) |
| archivist | 108 | 52.8% | 92 | 53.3% | -0.5 (-14.4 to +13.4) |
| warden | 53 | 52.8% | 147 | 53.1% | -0.2 (-15.9 to +15.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 62.7% | 149 | 49.7% | +13.1 (-2.4 to +28.6) |
| poisoner | 59 | 47.5% | 141 | 55.3% | -7.9 (-23.0 to +7.3) |
| scion | 55 | 50.9% | 145 | 53.8% | -2.9 (-18.4 to +12.6) |
| revenant | 35 | 51.4% | 165 | 53.3% | -1.9 (-20.1 to +16.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 34 | 29.4% | 166 | 57.8% | -28.4 (-45.5 to -11.4) **\*** |
| lovers | 46 | 71.7% | 154 | 47.4% | +24.3 (+9.1 to +39.6) **\*** |
| sleepwalker | 37 | 48.6% | 163 | 54.0% | -5.3 (-23.2 to +12.5) |
| muddler | 45 | 55.6% | 155 | 52.3% | +3.3 (-13.2 to +19.8) |
| marked | 38 | 52.6% | 162 | 53.1% | -0.5 (-18.1 to +17.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 70 | 57.1% | 130 | 50.8% | +6.4 (-8.1 to +20.8) |
| 2 night-walkers | 125 | 52.8% | 75 | 53.3% | -0.5 (-14.8 to +13.8) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.3 | 19.3% | 17.5% | 94.7% |
| archivist | 108 | 1.5 | 56.5% | 16.7% | 95.4% |
| rumormonger | 102 | 2.4 | 25.5% | 14.7% | 92.2% |
| surveyor | 96 | 2.4 | 21.9% | 16.7% | 90.6% |
| registrar | 66 | 2.4 | 34.8% | 9.1% | 87.9% |
| warden | 53 | 2.5 | 28.3% | 17.0% | 81.1% |
| gravedigger | 53 | 2.1 | 52.8% | 18.9% | 86.8% |
| dowser | 53 | 2.0 | 45.3% | 9.4% | 90.6% |
| nightwatch | 50 | 2.2 | 30.0% | 12.0% | 82.0% |
| confessor | 44 | 2.1 | 38.6% | 9.1% | 86.4% |
| lamplighter | 42 | 2.4 | 23.8% | 9.5% | 90.5% |
| augur | 37 | 2.1 | 24.3% | 10.8% | 83.8% |
| medium | 32 | 2.3 | 15.6% | 21.9% | 81.2% |
| seer | 32 | 1.8 | 56.2% | 9.4% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 63.9% |
| confessor | 33 | 0.0% | 60.6% |
| dowser | 29 | 0.0% | 62.1% |
| lamplighter | 25 | 0.0% | 52.0% |
| medium | 25 | 0.0% | 36.0% |
| rumormonger | 24 | 0.0% | 54.2% |
| surveyor | 22 | 0.0% | 50.0% |
| clerk | 22 | 0.0% | 68.2% |
| archivist | 21 | 0.0% | 57.1% |
| gravedigger | 20 | 0.0% | 60.0% |
| magistrate | 17 | 0.0% | 64.7% |
| chronicler | 17 | 0.0% | 58.8% |
| augur | 16 | 0.0% | 81.2% |
| psychologist | 16 | 0.0% | 68.8% |
| registrar | 15 | 0.0% | 40.0% |
| executor | 14 | 0.0% | 50.0% |
| seer | 14 | 0.0% | 42.9% |
| monitor | 12 | 0.0% | 41.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 50 | 62.0% | 150 | 32.0% | +30.0 (+14.6 to +45.4) **\*** |
| gravedigger | 53 | 22.6% | 147 | 45.6% | -22.9 (-36.8 to -9.1) **\*** |
| registrar | 66 | 48.5% | 134 | 35.1% | +13.4 (-1.1 to +27.9) |
| lamplighter | 42 | 31.0% | 158 | 41.8% | -10.8 (-26.8 to +5.1) |
| dowser | 53 | 47.2% | 147 | 36.7% | +10.4 (-5.1 to +26.0) |
| archivist | 108 | 35.2% | 92 | 44.6% | -9.4 (-23.0 to +4.2) |
| clerk | 114 | 43.0% | 86 | 34.9% | +8.1 (-5.5 to +21.7) |
| augur | 37 | 35.1% | 163 | 40.5% | -5.4 (-22.5 to +11.8) |
| warden | 53 | 43.4% | 147 | 38.1% | +5.3 (-10.2 to +20.8) |
| surveyor | 96 | 41.7% | 104 | 37.5% | +4.2 (-9.4 to +17.7) |
| seer | 32 | 37.5% | 168 | 39.9% | -2.4 (-20.7 to +16.0) |
| rumormonger | 102 | 40.2% | 98 | 38.8% | +1.4 (-12.1 to +15.0) |
| medium | 32 | 40.6% | 168 | 39.3% | +1.3 (-17.2 to +19.9) |
| confessor | 44 | 38.6% | 156 | 39.7% | -1.1 (-17.4 to +15.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 51.0% | 149 | 35.6% | +15.4 (-0.3 to +31.1) |
| poisoner | 59 | 28.8% | 141 | 44.0% | -15.2 (-29.3 to -1.0) **\*** |
| revenant | 35 | 28.6% | 165 | 41.8% | -13.2 (-30.0 to +3.5) |
| scion | 55 | 47.3% | 145 | 36.6% | +10.7 (-4.6 to +26.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 34 | 26.5% | 166 | 42.2% | -15.7 (-32.3 to +0.9) |
| lovers | 46 | 47.8% | 154 | 37.0% | +10.8 (-5.5 to +27.1) |
| sleepwalker | 37 | 32.4% | 163 | 41.1% | -8.7 (-25.5 to +8.2) |
| muddler | 45 | 44.4% | 155 | 38.1% | +6.4 (-10.0 to +22.8) |
| marked | 38 | 42.1% | 162 | 38.9% | +3.2 (-14.2 to +20.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 70 | 47.1% | 130 | 35.4% | +11.8 (-2.5 to +26.1) |
| 2 night-walkers | 125 | 36.0% | 75 | 45.3% | -9.3 (-23.4 to +4.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.4 | 26.3% | 22.8% | 90.4% |
| archivist | 108 | 1.6 | 63.0% | 17.6% | 94.4% |
| rumormonger | 102 | 2.6 | 21.6% | 25.5% | 94.1% |
| surveyor | 96 | 2.6 | 24.0% | 18.8% | 95.8% |
| registrar | 66 | 2.5 | 33.3% | 6.1% | 92.4% |
| warden | 53 | 2.4 | 30.2% | 15.1% | 79.2% |
| dowser | 53 | 1.9 | 47.2% | 9.4% | 88.7% |
| gravedigger | 53 | 2.2 | 49.1% | 13.2% | 92.5% |
| nightwatch | 50 | 2.1 | 34.0% | 12.0% | 86.0% |
| confessor | 44 | 2.3 | 40.9% | 13.6% | 90.9% |
| lamplighter | 42 | 2.6 | 23.8% | 2.4% | 83.3% |
| augur | 37 | 2.5 | 29.7% | 18.9% | 83.8% |
| seer | 32 | 2.1 | 56.2% | 9.4% | 87.5% |
| medium | 32 | 2.4 | 25.0% | 12.5% | 90.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 25.0% |
| confessor | 33 | 0.0% | 54.5% |
| dowser | 31 | 0.0% | 38.7% |
| medium | 25 | 0.0% | 40.0% |
| lamplighter | 25 | 0.0% | 48.0% |
| rumormonger | 24 | 0.0% | 58.3% |
| surveyor | 23 | 0.0% | 39.1% |
| clerk | 22 | 0.0% | 45.5% |
| archivist | 21 | 0.0% | 76.2% |
| gravedigger | 20 | 0.0% | 60.0% |
| augur | 17 | 0.0% | 47.1% |
| chronicler | 17 | 0.0% | 41.2% |
| psychologist | 17 | 0.0% | 52.9% |
| magistrate | 16 | 0.0% | 50.0% |
| seer | 14 | 0.0% | 21.4% |
| registrar | 14 | 0.0% | 50.0% |
| executor | 13 | 0.0% | 23.1% |
| monitor | 12 | 0.0% | 16.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, present and vote insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 53 | 30.2% | 147 | 55.8% | -25.6 (-40.3 to -10.9) **\*** |
| warden | 53 | 60.4% | 147 | 44.9% | +15.5 (+0.1 to +30.9) **\*** |
| clerk | 114 | 55.3% | 86 | 40.7% | +14.6 (+0.7 to +28.4) **\*** |
| dowser | 53 | 58.5% | 147 | 45.6% | +12.9 (-2.6 to +28.4) |
| confessor | 44 | 40.9% | 156 | 51.3% | -10.4 (-26.9 to +6.1) |
| seer | 32 | 56.2% | 168 | 47.6% | +8.6 (-10.1 to +27.4) |
| surveyor | 96 | 44.8% | 104 | 52.9% | -8.1 (-21.9 to +5.7) |
| archivist | 108 | 45.4% | 92 | 53.3% | -7.9 (-21.8 to +6.0) |
| nightwatch | 50 | 46.0% | 150 | 50.0% | -4.0 (-20.0 to +12.0) |
| augur | 37 | 51.4% | 163 | 48.5% | +2.9 (-15.0 to +20.7) |
| medium | 32 | 46.9% | 168 | 49.4% | -2.5 (-21.4 to +16.3) |
| rumormonger | 102 | 50.0% | 98 | 48.0% | +2.0 (-11.8 to +15.9) |
| lamplighter | 42 | 47.6% | 158 | 49.4% | -1.7 (-18.7 to +15.2) |
| registrar | 66 | 48.5% | 134 | 49.3% | -0.8 (-15.5 to +14.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 70.6% | 149 | 41.6% | +29.0 (+14.2 to +43.8) **\*** |
| scion | 55 | 40.0% | 145 | 52.4% | -12.4 (-27.7 to +2.9) |
| revenant | 35 | 40.0% | 165 | 50.9% | -10.9 (-28.8 to +7.0) |
| poisoner | 59 | 44.1% | 141 | 51.1% | -7.0 (-22.1 to +8.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sleepwalker | 37 | 43.2% | 163 | 50.3% | -7.1 (-24.8 to +10.6) |
| lovers | 46 | 54.3% | 154 | 47.4% | +6.9 (-9.5 to +23.4) |
| delusional | 34 | 44.1% | 166 | 50.0% | -5.9 (-24.2 to +12.5) |
| muddler | 45 | 53.3% | 155 | 47.7% | +5.6 (-11.0 to +22.2) |
| marked | 38 | 47.4% | 162 | 49.4% | -2.0 (-19.7 to +15.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 50.4% | 75 | 46.7% | +3.7 (-10.6 to +18.0) |
| 3 night-walkers | 70 | 48.6% | 130 | 49.2% | -0.7 (-15.2 to +13.9) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.4 | 19.3% | 14.9% | 93.9% |
| archivist | 108 | 1.6 | 56.5% | 14.8% | 97.2% |
| rumormonger | 102 | 2.3 | 21.6% | 12.7% | 95.1% |
| surveyor | 96 | 2.2 | 32.3% | 9.4% | 87.5% |
| registrar | 66 | 2.3 | 40.9% | 7.6% | 89.4% |
| warden | 53 | 2.5 | 20.8% | 20.8% | 69.8% |
| dowser | 53 | 1.8 | 49.1% | 9.4% | 90.6% |
| gravedigger | 53 | 2.0 | 50.9% | 17.0% | 86.8% |
| nightwatch | 50 | 2.1 | 36.0% | 24.0% | 86.0% |
| confessor | 44 | 2.0 | 27.3% | 25.0% | 84.1% |
| lamplighter | 42 | 2.1 | 16.7% | 19.0% | 81.0% |
| augur | 37 | 2.3 | 35.1% | 8.1% | 83.8% |
| seer | 32 | 1.9 | 46.9% | 6.2% | 84.4% |
| medium | 32 | 2.3 | 21.9% | 18.8% | 81.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 61.1% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 55.2% |
| medium | 25 | 0.0% | 32.0% |
| rumormonger | 24 | 0.0% | 41.7% |
| surveyor | 23 | 0.0% | 47.8% |
| lamplighter | 23 | 0.0% | 52.2% |
| clerk | 22 | 0.0% | 36.4% |
| gravedigger | 20 | 0.0% | 55.0% |
| archivist | 20 | 0.0% | 80.0% |
| magistrate | 17 | 0.0% | 47.1% |
| augur | 17 | 0.0% | 47.1% |
| psychologist | 17 | 0.0% | 64.7% |
| chronicler | 16 | 0.0% | 37.5% |
| registrar | 16 | 0.0% | 43.8% |
| seer | 15 | 0.0% | 33.3% |
| executor | 14 | 0.0% | 42.9% |
| monitor | 12 | 0.0% | 16.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 200 | 65 (32.5%) | 25 (12.5%) | 54 | 56 |
| 7 | 7 NPCs, bot, no presenting insight 1.0 | 200 | 53 (26.5%) | 26 (13.0%) | 53 | 68 |
| 7 | 7 NPCs, bot, present and vote insight 1.0 | 200 | 54 (27.0%) | 35 (17.5%) | 44 | 67 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 5 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 70.2 | 139.0 | 397.9 |
| 7 NPCs, bot, no presenting insight 1.0 | 91.3 | 164.1 | 402.6 |
| 7 NPCs, passive | 3.9 | 6.4 | 13.1 |
| 7 NPCs, bot, present and vote insight 1.0 | 40.7 | 74.0 | 288.3 |

Slowest seeds: 100011 (7 NPCs no_present, 403 s), 100142 (7 NPCs bot, 398 s), 100105 (7 NPCs bot, 313 s), 100142 (7 NPCs present_vote, 288 s), 100076 (7 NPCs bot, 272 s), 100135 (7 NPCs no_present, 240 s), 100155 (7 NPCs no_present, 224 s), 100157 (7 NPCs no_present, 215 s), 100010 (7 NPCs bot, 215 s), 100032 (7 NPCs no_present, 214 s), 100044 (7 NPCs bot, 202 s), 100105 (7 NPCs present_vote, 196 s), 100150 (7 NPCs no_present, 194 s), 100005 (7 NPCs no_present, 190 s), 100189 (7 NPCs no_present, 188 s), 100123 (7 NPCs no_present, 188 s), 100139 (7 NPCs no_present, 187 s), 100056 (7 NPCs no_present, 185 s), 100131 (7 NPCs no_present, 180 s), 100079 (7 NPCs no_present, 178 s)

