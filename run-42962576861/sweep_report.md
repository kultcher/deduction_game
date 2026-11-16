# Balance sweep report

Records: 400 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `db7c900ce7`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 59.5% (52.6%–66.1%) | 3.10 | 0.62 | 1.12 | 2.20 | 10.5% | 0.25 |
| 7 NPCs, bot, no presenting insight 1.0 | 200 | 62.5% (55.6%–68.9%) | 3.10 | 0.58 | 1.17 | 2.26 | 10.0% | 0.21 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 5.22 | 18.0% | 29.0% | 2.08 | 14.5% | 13.8% | 12.3% |
| 7 NPCs, bot, no presenting insight 1.0 | 5.14 | 17.9% | 28.6% | 2.21 | 12.0% | 11.1% | 10.6% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 119 (59.5%)
- Only two townsfolk remain and the demon still walks among them.: 81 (40.5%)
- Demon evidence on the board: 96.0% of games; good win rate 57.8% of 192
- Demon evidence reachable: 82.5% of games; good win rate 53.9% of 165
- Neither: 4.0% of games; good win rate 100.0% of 8
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no presenting insight 1.0** (n=200)

- The demon's host was executed.: 125 (62.5%)
- Only two townsfolk remain and the demon still walks among them.: 75 (37.5%)
- Demon evidence on the board: 95.5% of games; good win rate 61.3% of 191
- Demon evidence reachable: 80.0% of games; good win rate 56.9% of 160
- Neither: 3.0% of games; good win rate 100.0% of 6
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
| gravedigger | 53 | 49.1% | 147 | 67.3% | -18.3 (-33.7 to -2.8) **\*** |
| registrar | 66 | 71.2% | 134 | 58.2% | +13.0 (-0.7 to +26.8) |
| dowser | 53 | 71.7% | 147 | 59.2% | +12.5 (-2.0 to +27.0) |
| surveyor | 96 | 58.3% | 104 | 66.3% | -8.0 (-21.4 to +5.4) |
| clerk | 114 | 64.9% | 86 | 59.3% | +5.6 (-8.0 to +19.2) |
| medium | 32 | 65.6% | 168 | 61.9% | +3.7 (-14.3 to +21.7) |
| seer | 32 | 59.4% | 168 | 63.1% | -3.7 (-22.2 to +14.8) |
| nightwatch | 50 | 60.0% | 150 | 63.3% | -3.3 (-18.9 to +12.3) |
| lamplighter | 42 | 64.3% | 158 | 62.0% | +2.3 (-14.1 to +18.6) |
| warden | 53 | 64.2% | 147 | 61.9% | +2.2 (-12.9 to +17.4) |
| confessor | 44 | 61.4% | 156 | 62.8% | -1.5 (-17.7 to +14.8) |
| archivist | 108 | 62.0% | 92 | 63.0% | -1.0 (-14.5 to +12.4) |
| rumormonger | 102 | 62.7% | 98 | 62.2% | +0.5 (-12.9 to +13.9) |
| augur | 37 | 62.2% | 163 | 62.6% | -0.4 (-17.7 to +16.9) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 70.6% | 149 | 59.7% | +10.9 (-3.9 to +25.6) |
| revenant | 35 | 57.1% | 165 | 63.6% | -6.5 (-24.5 to +11.5) |
| scion | 55 | 58.2% | 145 | 64.1% | -6.0 (-21.2 to +9.2) |
| poisoner | 59 | 62.7% | 141 | 62.4% | +0.3 (-14.4 to +15.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lovers | 46 | 73.9% | 154 | 59.1% | +14.8 (-0.1 to +29.7) |
| sleepwalker | 37 | 56.8% | 163 | 63.8% | -7.0 (-24.6 to +10.5) |
| delusional | 34 | 58.8% | 166 | 63.3% | -4.4 (-22.5 to +13.7) |
| muddler | 45 | 60.0% | 155 | 63.2% | -3.2 (-19.4 to +13.0) |
| marked | 38 | 60.5% | 162 | 63.0% | -2.4 (-19.7 to +14.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 70 | 67.1% | 130 | 60.0% | +7.1 (-6.7 to +21.0) |
| 2 night-walkers | 125 | 60.8% | 75 | 65.3% | -4.5 (-18.3 to +9.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.2 | 17.5% | 14.0% | 93.9% |
| archivist | 108 | 1.4 | 55.6% | 15.7% | 95.4% |
| rumormonger | 102 | 2.3 | 23.5% | 10.8% | 93.1% |
| surveyor | 96 | 2.2 | 21.9% | 12.5% | 90.6% |
| registrar | 66 | 2.0 | 34.8% | 4.5% | 84.8% |
| warden | 53 | 2.4 | 22.6% | 17.0% | 79.2% |
| gravedigger | 53 | 2.0 | 50.9% | 11.3% | 84.9% |
| dowser | 53 | 1.9 | 47.2% | 7.5% | 88.7% |
| nightwatch | 50 | 2.1 | 26.0% | 20.0% | 80.0% |
| confessor | 44 | 2.1 | 34.1% | 15.9% | 86.4% |
| lamplighter | 42 | 2.3 | 23.8% | 2.4% | 88.1% |
| augur | 37 | 2.4 | 27.0% | 8.1% | 81.1% |
| medium | 32 | 2.3 | 18.8% | 12.5% | 78.1% |
| seer | 32 | 1.8 | 53.1% | 3.1% | 93.8% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 69.4% |
| confessor | 32 | 0.0% | 71.9% |
| dowser | 29 | 0.0% | 65.5% |
| medium | 25 | 0.0% | 40.0% |
| lamplighter | 24 | 0.0% | 66.7% |
| rumormonger | 24 | 0.0% | 50.0% |
| surveyor | 22 | 0.0% | 68.2% |
| clerk | 22 | 0.0% | 68.2% |
| archivist | 21 | 0.0% | 52.4% |
| gravedigger | 19 | 0.0% | 73.7% |
| magistrate | 17 | 0.0% | 64.7% |
| chronicler | 16 | 0.0% | 56.2% |
| augur | 16 | 0.0% | 62.5% |
| psychologist | 16 | 0.0% | 81.2% |
| registrar | 15 | 0.0% | 33.3% |
| executor | 13 | 0.0% | 53.8% |
| seer | 13 | 0.0% | 53.8% |
| monitor | 12 | 0.0% | 41.7% |

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
| 7 NPCs, bot insight 1.0 | 47.8 | 95.8 | 264.9 |
| 7 NPCs, bot, no presenting insight 1.0 | 68.1 | 137.7 | 252.6 |

Slowest seeds: 100142 (7 NPCs bot, 265 s), 100185 (7 NPCs no_present, 253 s), 100139 (7 NPCs no_present, 239 s), 100010 (7 NPCs no_present, 216 s), 100105 (7 NPCs bot, 213 s), 100023 (7 NPCs no_present, 201 s), 100076 (7 NPCs bot, 188 s), 100105 (7 NPCs no_present, 187 s), 100032 (7 NPCs no_present, 178 s), 100002 (7 NPCs no_present, 176 s), 100044 (7 NPCs bot, 166 s), 100169 (7 NPCs no_present, 166 s), 100050 (7 NPCs no_present, 155 s), 100039 (7 NPCs no_present, 154 s), 100150 (7 NPCs no_present, 150 s), 100136 (7 NPCs no_present, 149 s), 100058 (7 NPCs no_present, 148 s), 100010 (7 NPCs bot, 147 s), 100062 (7 NPCs no_present, 147 s), 100082 (7 NPCs no_present, 147 s)

