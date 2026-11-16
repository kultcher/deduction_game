# Balance sweep report

Records: 600 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `c2b8685231`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 61.5% (54.6%–68.0%) | 3.06 | 0.70 | 1.16 | 2.27 | 10.0% | 0.29 |
| 7 NPCs, bot, no cross-checks insight 1.0 | 200 | 62.5% (55.6%–68.9%) | 3.06 | 0.70 | 1.16 | 2.28 | 10.0% | 0.29 |
| 7 NPCs, bot, no declaring insight 1.0 | 200 | 61.5% (54.6%–68.0%) | 3.06 | 0.70 | 1.16 | 2.27 | 10.0% | 0.29 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.92 | 20.8% | 29.1% | 2.08 | 18.2% | 17.3% | 15.8% |
| 7 NPCs, bot, no cross-checks insight 1.0 | 4.90 | 20.7% | 28.9% | 2.10 | 18.4% | 17.4% | 15.9% |
| 7 NPCs, bot, no declaring insight 1.0 | 4.92 | 20.8% | 29.1% | 2.08 | 18.2% | 17.3% | 15.8% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 123 (61.5%)
- Only two townsfolk remain and the demon still walks among them.: 77 (38.5%)
- Demon evidence on the board: 97.0% of games; good win rate 60.3% of 194
- Demon evidence reachable: 81.5% of games; good win rate 59.5% of 163
- Neither: 2.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no cross-checks insight 1.0** (n=200)

- The demon's host was executed.: 125 (62.5%)
- Only two townsfolk remain and the demon still walks among them.: 75 (37.5%)
- Demon evidence on the board: 97.0% of games; good win rate 61.3% of 194
- Demon evidence reachable: 81.5% of games; good win rate 60.7% of 163
- Neither: 2.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no declaring insight 1.0** (n=200)

- The demon's host was executed.: 123 (61.5%)
- Only two townsfolk remain and the demon still walks among them.: 77 (38.5%)
- Demon evidence on the board: 97.0% of games; good win rate 60.3% of 194
- Demon evidence reachable: 81.5% of games; good win rate 59.5% of 163
- Neither: 2.5% of games; good win rate 100.0% of 5
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 44 | 47.7% | 156 | 65.4% | -17.7 (-34.2 to -1.1) **\*** |
| medium | 32 | 71.9% | 168 | 59.5% | +12.4 (-4.9 to +29.6) |
| lamplighter | 42 | 52.4% | 158 | 63.9% | -11.5 (-28.4 to +5.3) |
| warden | 53 | 69.8% | 147 | 58.5% | +11.3 (-3.4 to +26.0) |
| rumormonger | 102 | 66.7% | 98 | 56.1% | +10.5 (-2.9 to +24.0) |
| seer | 32 | 53.1% | 168 | 63.1% | -10.0 (-28.7 to +8.8) |
| gravedigger | 53 | 54.7% | 147 | 63.9% | -9.2 (-24.7 to +6.3) |
| dowser | 53 | 67.9% | 147 | 59.2% | +8.7 (-6.1 to +23.6) |
| archivist | 108 | 58.3% | 92 | 65.2% | -6.9 (-20.3 to +6.6) |
| augur | 37 | 64.9% | 163 | 60.7% | +4.1 (-13.0 to +21.2) |
| surveyor | 96 | 59.4% | 104 | 63.5% | -4.1 (-17.6 to +9.4) |
| nightwatch | 50 | 64.0% | 150 | 60.7% | +3.3 (-12.1 to +18.8) |
| registrar | 66 | 63.6% | 134 | 60.4% | +3.2 (-11.1 to +17.4) |
| clerk | 114 | 61.4% | 86 | 61.6% | -0.2 (-13.8 to +13.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 35 | 48.6% | 165 | 64.2% | -15.7 (-33.8 to +2.4) |
| scion | 55 | 69.1% | 145 | 58.6% | +10.5 (-4.1 to +25.1) |
| breathstealer | 51 | 68.6% | 149 | 59.1% | +9.6 (-5.4 to +24.6) |
| poisoner | 59 | 55.9% | 141 | 63.8% | -7.9 (-22.8 to +7.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 34 | 50.0% | 166 | 63.9% | -13.9 (-32.2 to +4.5) |
| lovers | 46 | 67.4% | 154 | 59.7% | +7.7 (-8.0 to +23.3) |
| muddler | 45 | 66.7% | 155 | 60.0% | +6.7 (-9.1 to +22.5) |
| sleepwalker | 37 | 56.8% | 163 | 62.6% | -5.8 (-23.4 to +11.8) |
| marked | 38 | 63.2% | 162 | 61.1% | +2.0 (-15.0 to +19.1) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 63.2% | 75 | 58.7% | +4.5 (-9.5 to +18.5) |
| 3 night-walkers | 70 | 61.4% | 130 | 61.5% | -0.1 (-14.3 to +14.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.0 | 19.3% | 14.9% | 94.7% |
| archivist | 108 | 1.5 | 57.4% | 15.7% | 95.4% |
| rumormonger | 102 | 2.4 | 17.6% | 12.7% | 93.1% |
| surveyor | 96 | 2.0 | 24.0% | 11.5% | 91.7% |
| registrar | 66 | 1.9 | 37.9% | 6.1% | 78.8% |
| warden | 53 | 1.9 | 30.2% | 17.0% | 71.7% |
| gravedigger | 53 | 1.9 | 50.9% | 11.3% | 86.8% |
| dowser | 53 | 1.8 | 47.2% | 9.4% | 86.8% |
| nightwatch | 50 | 2.0 | 30.0% | 18.0% | 90.0% |
| confessor | 44 | 1.8 | 29.5% | 38.6% | 81.8% |
| lamplighter | 42 | 2.2 | 16.7% | 19.0% | 92.9% |
| augur | 37 | 2.5 | 24.3% | 18.9% | 89.2% |
| medium | 32 | 2.3 | 21.9% | 9.4% | 68.8% |
| seer | 32 | 2.0 | 50.0% | 6.2% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 65.7% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 65.5% |
| lamplighter | 24 | 0.0% | 66.7% |
| rumormonger | 24 | 0.0% | 62.5% |
| medium | 24 | 0.0% | 25.0% |
| surveyor | 23 | 0.0% | 60.9% |
| clerk | 22 | 0.0% | 59.1% |
| archivist | 20 | 0.0% | 60.0% |
| gravedigger | 19 | 0.0% | 63.2% |
| psychologist | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 56.2% |
| registrar | 16 | 0.0% | 62.5% |
| chronicler | 16 | 0.0% | 43.8% |
| augur | 16 | 0.0% | 56.2% |
| seer | 15 | 0.0% | 40.0% |
| executor | 13 | 0.0% | 46.2% |
| monitor | 12 | 0.0% | 66.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no cross-checks insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 44 | 50.0% | 156 | 66.0% | -16.0 (-32.6 to +0.5) |
| medium | 32 | 71.9% | 168 | 60.7% | +11.2 (-6.1 to +28.4) |
| gravedigger | 53 | 54.7% | 147 | 65.3% | -10.6 (-26.0 to +4.9) |
| warden | 53 | 69.8% | 147 | 59.9% | +9.9 (-4.7 to +24.6) |
| dowser | 53 | 69.8% | 147 | 59.9% | +9.9 (-4.7 to +24.6) |
| rumormonger | 102 | 66.7% | 98 | 58.2% | +8.5 (-4.9 to +21.9) |
| seer | 32 | 56.2% | 168 | 63.7% | -7.4 (-26.1 to +11.2) |
| lamplighter | 42 | 57.1% | 158 | 63.9% | -6.8 (-23.5 to +10.0) |
| archivist | 108 | 60.2% | 92 | 65.2% | -5.0 (-18.4 to +8.4) |
| surveyor | 96 | 60.4% | 104 | 64.4% | -4.0 (-17.4 to +9.4) |
| augur | 37 | 64.9% | 163 | 62.0% | +2.9 (-14.2 to +20.0) |
| nightwatch | 50 | 64.0% | 150 | 62.0% | +2.0 (-13.4 to +17.4) |
| registrar | 66 | 63.6% | 134 | 61.9% | +1.7 (-12.5 to +15.9) |
| clerk | 114 | 62.3% | 86 | 62.8% | -0.5 (-14.1 to +13.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 35 | 51.4% | 165 | 64.8% | -13.4 (-31.5 to +4.7) |
| scion | 55 | 69.1% | 145 | 60.0% | +9.1 (-5.5 to +23.7) |
| breathstealer | 51 | 68.6% | 149 | 60.4% | +8.2 (-6.7 to +23.2) |
| poisoner | 59 | 57.6% | 141 | 64.5% | -6.9 (-21.8 to +8.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 34 | 52.9% | 166 | 64.5% | -11.5 (-29.8 to +6.8) |
| muddler | 45 | 68.9% | 155 | 60.6% | +8.2 (-7.3 to +23.8) |
| sleepwalker | 37 | 56.8% | 163 | 63.8% | -7.0 (-24.6 to +10.5) |
| lovers | 46 | 67.4% | 154 | 61.0% | +6.4 (-9.2 to +21.9) |
| marked | 38 | 63.2% | 162 | 62.3% | +0.8 (-16.2 to +17.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 64.0% | 75 | 60.0% | +4.0 (-9.9 to +17.9) |
| 3 night-walkers | 70 | 61.4% | 130 | 63.1% | -1.6 (-15.7 to +12.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.0 | 18.4% | 14.9% | 94.7% |
| archivist | 108 | 1.5 | 57.4% | 14.8% | 95.4% |
| rumormonger | 102 | 2.4 | 17.6% | 12.7% | 93.1% |
| surveyor | 96 | 2.0 | 24.0% | 11.5% | 91.7% |
| registrar | 66 | 1.9 | 39.4% | 6.1% | 78.8% |
| warden | 53 | 1.9 | 30.2% | 17.0% | 71.7% |
| dowser | 53 | 1.8 | 47.2% | 9.4% | 86.8% |
| gravedigger | 53 | 1.9 | 50.9% | 11.3% | 86.8% |
| nightwatch | 50 | 2.0 | 30.0% | 18.0% | 90.0% |
| confessor | 44 | 1.8 | 29.5% | 36.4% | 81.8% |
| lamplighter | 42 | 2.2 | 14.3% | 19.0% | 92.9% |
| augur | 37 | 2.5 | 24.3% | 18.9% | 89.2% |
| seer | 32 | 2.0 | 50.0% | 6.2% | 87.5% |
| medium | 32 | 2.3 | 21.9% | 9.4% | 68.8% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 65.7% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 65.5% |
| rumormonger | 24 | 0.0% | 62.5% |
| medium | 24 | 0.0% | 25.0% |
| lamplighter | 24 | 0.0% | 66.7% |
| surveyor | 23 | 0.0% | 60.9% |
| clerk | 22 | 0.0% | 54.5% |
| archivist | 20 | 0.0% | 60.0% |
| gravedigger | 19 | 0.0% | 63.2% |
| psychologist | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 56.2% |
| augur | 16 | 0.0% | 56.2% |
| chronicler | 16 | 0.0% | 50.0% |
| registrar | 16 | 0.0% | 62.5% |
| seer | 15 | 0.0% | 46.7% |
| executor | 13 | 0.0% | 46.2% |
| monitor | 12 | 0.0% | 66.7% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no declaring insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 44 | 47.7% | 156 | 65.4% | -17.7 (-34.2 to -1.1) **\*** |
| medium | 32 | 71.9% | 168 | 59.5% | +12.4 (-4.9 to +29.6) |
| lamplighter | 42 | 52.4% | 158 | 63.9% | -11.5 (-28.4 to +5.3) |
| warden | 53 | 69.8% | 147 | 58.5% | +11.3 (-3.4 to +26.0) |
| rumormonger | 102 | 66.7% | 98 | 56.1% | +10.5 (-2.9 to +24.0) |
| seer | 32 | 53.1% | 168 | 63.1% | -10.0 (-28.7 to +8.8) |
| gravedigger | 53 | 54.7% | 147 | 63.9% | -9.2 (-24.7 to +6.3) |
| dowser | 53 | 67.9% | 147 | 59.2% | +8.7 (-6.1 to +23.6) |
| archivist | 108 | 58.3% | 92 | 65.2% | -6.9 (-20.3 to +6.6) |
| augur | 37 | 64.9% | 163 | 60.7% | +4.1 (-13.0 to +21.2) |
| surveyor | 96 | 59.4% | 104 | 63.5% | -4.1 (-17.6 to +9.4) |
| nightwatch | 50 | 64.0% | 150 | 60.7% | +3.3 (-12.1 to +18.8) |
| registrar | 66 | 63.6% | 134 | 60.4% | +3.2 (-11.1 to +17.4) |
| clerk | 114 | 61.4% | 86 | 61.6% | -0.2 (-13.8 to +13.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| revenant | 35 | 48.6% | 165 | 64.2% | -15.7 (-33.8 to +2.4) |
| scion | 55 | 69.1% | 145 | 58.6% | +10.5 (-4.1 to +25.1) |
| breathstealer | 51 | 68.6% | 149 | 59.1% | +9.6 (-5.4 to +24.6) |
| poisoner | 59 | 55.9% | 141 | 63.8% | -7.9 (-22.8 to +7.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 34 | 50.0% | 166 | 63.9% | -13.9 (-32.2 to +4.5) |
| lovers | 46 | 67.4% | 154 | 59.7% | +7.7 (-8.0 to +23.3) |
| muddler | 45 | 66.7% | 155 | 60.0% | +6.7 (-9.1 to +22.5) |
| sleepwalker | 37 | 56.8% | 163 | 62.6% | -5.8 (-23.4 to +11.8) |
| marked | 38 | 63.2% | 162 | 61.1% | +2.0 (-15.0 to +19.1) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 63.2% | 75 | 58.7% | +4.5 (-9.5 to +18.5) |
| 3 night-walkers | 70 | 61.4% | 130 | 61.5% | -0.1 (-14.3 to +14.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.0 | 19.3% | 14.9% | 94.7% |
| archivist | 108 | 1.5 | 57.4% | 15.7% | 95.4% |
| rumormonger | 102 | 2.4 | 17.6% | 12.7% | 93.1% |
| surveyor | 96 | 2.0 | 24.0% | 11.5% | 91.7% |
| registrar | 66 | 1.9 | 37.9% | 6.1% | 78.8% |
| warden | 53 | 1.9 | 30.2% | 17.0% | 71.7% |
| gravedigger | 53 | 1.9 | 50.9% | 11.3% | 86.8% |
| dowser | 53 | 1.8 | 47.2% | 9.4% | 86.8% |
| nightwatch | 50 | 2.0 | 30.0% | 18.0% | 90.0% |
| confessor | 44 | 1.8 | 29.5% | 38.6% | 81.8% |
| lamplighter | 42 | 2.2 | 16.7% | 19.0% | 92.9% |
| augur | 37 | 2.5 | 24.3% | 18.9% | 89.2% |
| medium | 32 | 2.3 | 21.9% | 9.4% | 68.8% |
| seer | 32 | 2.0 | 50.0% | 6.2% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 65.7% |
| confessor | 33 | 0.0% | 75.8% |
| dowser | 29 | 0.0% | 65.5% |
| lamplighter | 24 | 0.0% | 66.7% |
| rumormonger | 24 | 0.0% | 62.5% |
| medium | 24 | 0.0% | 25.0% |
| surveyor | 23 | 0.0% | 60.9% |
| clerk | 22 | 0.0% | 59.1% |
| archivist | 20 | 0.0% | 60.0% |
| gravedigger | 19 | 0.0% | 63.2% |
| psychologist | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 56.2% |
| registrar | 16 | 0.0% | 62.5% |
| chronicler | 16 | 0.0% | 43.8% |
| augur | 16 | 0.0% | 56.2% |
| seer | 15 | 0.0% | 40.0% |
| executor | 13 | 0.0% | 46.2% |
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
- Shared-model fallbacks: 3 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 50.3 | 95.0 | 156.5 |
| 7 NPCs, bot, no cross-checks insight 1.0 | 74.0 | 142.7 | 228.4 |
| 7 NPCs, bot, no declaring insight 1.0 | 44.1 | 81.7 | 131.5 |

Slowest seeds: 100068 (7 NPCs bot_nocross, 228 s), 100067 (7 NPCs bot_nocross, 220 s), 100135 (7 NPCs bot_nocross, 207 s), 100044 (7 NPCs bot_nocross, 190 s), 100095 (7 NPCs bot_nocross, 180 s), 100169 (7 NPCs bot_nocross, 173 s), 100114 (7 NPCs bot_nocross, 172 s), 100055 (7 NPCs bot_nocross, 167 s), 100150 (7 NPCs bot_nocross, 165 s), 100082 (7 NPCs bot_nocross, 164 s), 100084 (7 NPCs bot_nocross, 162 s), 100076 (7 NPCs bot_nocross, 161 s), 100122 (7 NPCs bot_nocross, 157 s), 100068 (7 NPCs bot, 156 s), 100191 (7 NPCs bot_nocross, 152 s), 100173 (7 NPCs bot_nocross, 152 s), 100057 (7 NPCs bot_nocross, 149 s), 100067 (7 NPCs bot, 149 s), 100124 (7 NPCs bot_nocross, 149 s), 100002 (7 NPCs bot_nocross, 147 s)

