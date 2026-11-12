# Balance sweep report

Records: 400 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `12cd656964`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 64.5% (57.7%–70.8%) | 3.06 | 0.69 | 1.17 | 2.28 | 10.0% | 0.29 |
| 7 NPCs, bot, no presenting insight 1.0 | 200 | 62.5% (55.6%–68.9%) | 3.10 | 0.67 | 1.16 | 2.29 | 9.5% | 0.28 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.92 | 20.7% | 29.4% | 2.09 | 17.9% | 17.0% | 15.8% |
| 7 NPCs, bot, no presenting insight 1.0 | 5.05 | 19.5% | 30.3% | 2.12 | 14.4% | 13.8% | 12.8% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 129 (64.5%)
- Only two townsfolk remain and the demon still walks among them.: 71 (35.5%)
- Demon evidence on the board: 97.0% of games; good win rate 63.4% of 194
- Demon evidence reachable: 81.0% of games; good win rate 63.0% of 162
- Neither: 2.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no presenting insight 1.0** (n=200)

- The demon's host was executed.: 125 (62.5%)
- Only two townsfolk remain and the demon still walks among them.: 75 (37.5%)
- Demon evidence on the board: 96.5% of games; good win rate 61.7% of 193
- Demon evidence reachable: 82.5% of games; good win rate 58.2% of 165
- Neither: 1.5% of games; good win rate 100.0% of 3
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 44 | 52.3% | 156 | 67.9% | -15.7 (-32.2 to +0.8) |
| gravedigger | 53 | 54.7% | 147 | 68.0% | -13.3 (-28.7 to +2.1) |
| dowser | 53 | 71.7% | 147 | 61.9% | +9.8 (-4.7 to +24.2) |
| warden | 53 | 71.7% | 147 | 61.9% | +9.8 (-4.7 to +24.2) |
| medium | 32 | 71.9% | 168 | 63.1% | +8.8 (-8.4 to +26.0) |
| rumormonger | 102 | 67.6% | 98 | 61.2% | +6.4 (-6.8 to +19.7) |
| lamplighter | 42 | 59.5% | 158 | 65.8% | -6.3 (-22.9 to +10.3) |
| archivist | 108 | 62.0% | 92 | 67.4% | -5.4 (-18.6 to +7.9) |
| nightwatch | 50 | 68.0% | 150 | 63.3% | +4.7 (-10.4 to +19.7) |
| seer | 32 | 62.5% | 168 | 64.9% | -2.4 (-20.6 to +15.9) |
| surveyor | 96 | 63.5% | 104 | 65.4% | -1.8 (-15.1 to +11.4) |
| clerk | 114 | 64.0% | 86 | 65.1% | -1.1 (-14.5 to +12.3) |
| registrar | 66 | 65.2% | 134 | 64.2% | +1.0 (-13.1 to +15.0) |
| augur | 37 | 64.9% | 163 | 64.4% | +0.4 (-16.6 to +17.5) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 35 | 54.3% | 165 | 66.7% | -12.4 (-30.4 to +5.6) |
| scion | 55 | 70.9% | 145 | 62.1% | +8.8 (-5.5 to +23.2) |
| breathstealer | 51 | 68.6% | 149 | 63.1% | +5.5 (-9.4 to +20.4) |
| poisoner | 59 | 61.0% | 141 | 66.0% | -4.9 (-19.6 to +9.8) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sleepwalker | 37 | 56.8% | 163 | 66.3% | -9.5 (-27.0 to +8.0) |
| delusional | 34 | 58.8% | 166 | 65.7% | -6.8 (-24.9 to +11.2) |
| muddler | 45 | 68.9% | 155 | 63.2% | +5.7 (-9.8 to +21.2) |
| marked | 38 | 68.4% | 162 | 63.6% | +4.8 (-11.7 to +21.4) |
| lovers | 46 | 67.4% | 154 | 63.6% | +3.8 (-11.8 to +19.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 65.6% | 75 | 62.7% | +2.9 (-10.8 to +16.7) |
| 3 night-walkers | 70 | 62.9% | 130 | 65.4% | -2.5 (-16.5 to +11.4) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.0 | 19.3% | 14.9% | 94.7% |
| archivist | 108 | 1.5 | 57.4% | 14.8% | 95.4% |
| rumormonger | 102 | 2.4 | 17.6% | 12.7% | 93.1% |
| surveyor | 96 | 2.0 | 24.0% | 11.5% | 91.7% |
| registrar | 66 | 1.9 | 39.4% | 6.1% | 78.8% |
| warden | 53 | 1.9 | 30.2% | 17.0% | 71.7% |
| gravedigger | 53 | 1.9 | 50.9% | 11.3% | 86.8% |
| dowser | 53 | 1.7 | 45.3% | 9.4% | 86.8% |
| nightwatch | 50 | 2.0 | 30.0% | 18.0% | 92.0% |
| confessor | 44 | 1.8 | 29.5% | 36.4% | 81.8% |
| lamplighter | 42 | 2.2 | 14.3% | 19.0% | 92.9% |
| augur | 37 | 2.5 | 24.3% | 18.9% | 89.2% |
| medium | 32 | 2.3 | 21.9% | 9.4% | 68.8% |
| seer | 32 | 2.0 | 46.9% | 6.2% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 65.7% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 65.5% |
| lamplighter | 24 | 0.0% | 66.7% |
| rumormonger | 24 | 0.0% | 66.7% |
| medium | 24 | 0.0% | 29.2% |
| surveyor | 23 | 0.0% | 60.9% |
| clerk | 22 | 0.0% | 54.5% |
| archivist | 20 | 0.0% | 60.0% |
| gravedigger | 19 | 0.0% | 78.9% |
| psychologist | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 56.2% |
| registrar | 16 | 0.0% | 56.2% |
| chronicler | 16 | 0.0% | 50.0% |
| augur | 16 | 0.0% | 50.0% |
| seer | 15 | 0.0% | 46.7% |
| executor | 13 | 0.0% | 46.2% |
| monitor | 12 | 0.0% | 66.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no presenting insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 53 | 52.8% | 147 | 66.0% | -13.2 (-28.6 to +2.3) |
| augur | 37 | 73.0% | 163 | 60.1% | +12.9 (-3.3 to +29.0) |
| nightwatch | 50 | 72.0% | 150 | 59.3% | +12.7 (-2.1 to +27.4) |
| medium | 32 | 56.2% | 168 | 63.7% | -7.4 (-26.1 to +11.2) |
| dowser | 53 | 67.9% | 147 | 60.5% | +7.4 (-7.5 to +22.2) |
| confessor | 44 | 56.8% | 156 | 64.1% | -7.3 (-23.7 to +9.2) |
| surveyor | 96 | 60.4% | 104 | 64.4% | -4.0 (-17.4 to +9.4) |
| seer | 32 | 59.4% | 168 | 63.1% | -3.7 (-22.2 to +14.8) |
| clerk | 114 | 64.0% | 86 | 60.5% | +3.6 (-10.0 to +17.1) |
| archivist | 108 | 61.1% | 92 | 64.1% | -3.0 (-16.5 to +10.4) |
| warden | 53 | 60.4% | 147 | 63.3% | -2.9 (-18.2 to +12.4) |
| registrar | 66 | 60.6% | 134 | 63.4% | -2.8 (-17.2 to +11.5) |
| lamplighter | 42 | 64.3% | 158 | 62.0% | +2.3 (-14.1 to +18.6) |
| rumormonger | 102 | 62.7% | 98 | 62.2% | +0.5 (-12.9 to +13.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 76.5% | 149 | 57.7% | +18.8 (+4.7 to +32.8) **\*** |
| revenant | 35 | 54.3% | 165 | 64.2% | -10.0 (-28.0 to +8.1) |
| scion | 55 | 58.2% | 145 | 64.1% | -6.0 (-21.2 to +9.2) |
| poisoner | 59 | 59.3% | 141 | 63.8% | -4.5 (-19.3 to +10.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sleepwalker | 37 | 51.4% | 163 | 65.0% | -13.7 (-31.4 to +4.0) |
| lovers | 46 | 69.6% | 154 | 60.4% | +9.2 (-6.2 to +24.6) |
| muddler | 45 | 68.9% | 155 | 60.6% | +8.2 (-7.3 to +23.8) |
| delusional | 34 | 58.8% | 166 | 63.3% | -4.4 (-22.5 to +13.7) |
| marked | 38 | 60.5% | 162 | 63.0% | -2.4 (-19.7 to +14.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 64.0% | 75 | 60.0% | +4.0 (-9.9 to +17.9) |
| 3 night-walkers | 70 | 60.0% | 130 | 63.8% | -3.8 (-18.0 to +10.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.2 | 17.5% | 15.8% | 93.0% |
| archivist | 108 | 1.4 | 55.6% | 15.7% | 92.6% |
| rumormonger | 102 | 2.3 | 25.5% | 16.7% | 92.2% |
| surveyor | 96 | 2.1 | 27.1% | 14.6% | 91.7% |
| registrar | 66 | 2.0 | 42.4% | 9.1% | 84.8% |
| warden | 53 | 2.4 | 28.3% | 22.6% | 79.2% |
| gravedigger | 53 | 1.9 | 49.1% | 11.3% | 86.8% |
| dowser | 53 | 1.8 | 41.5% | 9.4% | 90.6% |
| nightwatch | 50 | 1.9 | 34.0% | 14.0% | 84.0% |
| confessor | 44 | 2.0 | 31.8% | 25.0% | 81.8% |
| lamplighter | 42 | 2.2 | 21.4% | 7.1% | 92.9% |
| augur | 37 | 2.3 | 21.6% | 8.1% | 83.8% |
| medium | 32 | 2.5 | 28.1% | 6.2% | 81.2% |
| seer | 32 | 1.6 | 53.1% | 3.1% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 58.3% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 75.9% |
| lamplighter | 25 | 0.0% | 64.0% |
| rumormonger | 24 | 0.0% | 58.3% |
| medium | 24 | 0.0% | 29.2% |
| surveyor | 22 | 0.0% | 63.6% |
| clerk | 22 | 0.0% | 63.6% |
| archivist | 21 | 0.0% | 71.4% |
| gravedigger | 19 | 0.0% | 63.2% |
| augur | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 50.0% |
| registrar | 16 | 0.0% | 50.0% |
| chronicler | 16 | 0.0% | 37.5% |
| psychologist | 16 | 0.0% | 75.0% |
| seer | 15 | 0.0% | 53.3% |
| executor | 13 | 0.0% | 38.5% |
| monitor | 12 | 0.0% | 66.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 1 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 72.4 | 136.7 | 213.0 |
| 7 NPCs, bot, no presenting insight 1.0 | 68.1 | 125.0 | 303.0 |

Slowest seeds: 100006 (7 NPCs no_present, 303 s), 100128 (7 NPCs no_present, 220 s), 100067 (7 NPCs bot, 213 s), 100135 (7 NPCs bot, 197 s), 100013 (7 NPCs no_present, 188 s), 100044 (7 NPCs bot, 183 s), 100008 (7 NPCs no_present, 180 s), 100095 (7 NPCs bot, 175 s), 100169 (7 NPCs bot, 168 s), 100104 (7 NPCs no_present, 167 s), 100084 (7 NPCs no_present, 164 s), 100150 (7 NPCs bot, 164 s), 100114 (7 NPCs bot, 163 s), 100055 (7 NPCs bot, 162 s), 100062 (7 NPCs no_present, 161 s), 100114 (7 NPCs no_present, 159 s), 100197 (7 NPCs no_present, 158 s), 100082 (7 NPCs bot, 157 s), 100084 (7 NPCs bot, 156 s), 100076 (7 NPCs bot, 154 s)

