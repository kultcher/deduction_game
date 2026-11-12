# Balance sweep report

Records: 400 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `c2b8685231`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 52.5% (45.6%–59.3%) | 3.44 | 0.85 | 1.10 | 2.35 | 12.5% | 0.33 |
| 7 NPCs, bot, no declaring insight 1.0 | 200 | 49.0% (42.2%–55.9%) | 3.45 | 0.92 | 1.09 | 2.38 | 12.5% | 0.35 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 5.67 | 18.9% | 32.8% | 2.19 | 16.6% | 16.9% | 14.8% |
| 7 NPCs, bot, no declaring insight 1.0 | 5.56 | 19.2% | 32.2% | 2.17 | 18.5% | 18.6% | 17.2% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 105 (52.5%)
- Only two townsfolk remain and the demon still walks among them.: 94 (47.0%)
- Time ran out: the demon survived 6 days.: 1 (0.5%)
- Demon evidence on the board: 94.0% of games; good win rate 50.0% of 188
- Demon evidence reachable: 61.0% of games; good win rate 40.2% of 122
- Neither: 4.5% of games; good win rate 100.0% of 9
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no declaring insight 1.0** (n=200)

- Only two townsfolk remain and the demon still walks among them.: 99 (49.5%)
- The demon's host was executed.: 98 (49.0%)
- Time ran out: the demon survived 6 days.: 3 (1.5%)
- Demon evidence on the board: 94.0% of games; good win rate 46.3% of 188
- Demon evidence reachable: 60.5% of games; good win rate 41.3% of 121
- Neither: 4.5% of games; good win rate 100.0% of 9
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| medium | 32 | 75.0% | 168 | 48.2% | +26.8 (+10.0 to +43.6) **\*** |
| gravedigger | 53 | 34.0% | 147 | 59.2% | -25.2 (-40.2 to -10.2) **\*** |
| clerk | 114 | 61.4% | 86 | 40.7% | +20.7 (+7.0 to +34.4) **\*** |
| seer | 32 | 68.8% | 168 | 49.4% | +19.3 (+1.6 to +37.1) **\*** |
| warden | 53 | 66.0% | 147 | 47.6% | +18.4 (+3.3 to +33.5) **\*** |
| lamplighter | 42 | 38.1% | 158 | 56.3% | -18.2 (-34.8 to -1.6) **\*** |
| archivist | 108 | 47.2% | 92 | 58.7% | -11.5 (-25.3 to +2.3) |
| nightwatch | 50 | 44.0% | 150 | 55.3% | -11.3 (-27.2 to +4.6) |
| rumormonger | 102 | 47.1% | 98 | 58.2% | -11.1 (-24.9 to +2.7) |
| surveyor | 96 | 56.2% | 104 | 49.0% | +7.2 (-6.6 to +21.0) |
| registrar | 66 | 48.5% | 134 | 54.5% | -6.0 (-20.7 to +8.7) |
| confessor | 44 | 50.0% | 156 | 53.2% | -3.2 (-19.9 to +13.5) |
| dowser | 53 | 54.7% | 147 | 51.7% | +3.0 (-12.6 to +18.7) |
| augur | 37 | 54.1% | 163 | 52.1% | +1.9 (-15.9 to +19.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 74.5% | 149 | 45.0% | +29.5 (+15.2 to +43.9) **\*** |
| poisoner | 59 | 40.7% | 141 | 57.4% | -16.8 (-31.7 to -1.8) **\*** |
| scion | 55 | 43.6% | 145 | 55.9% | -12.2 (-27.6 to +3.2) |
| revenant | 35 | 54.3% | 165 | 52.1% | +2.2 (-16.0 to +20.3) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 38 | 44.7% | 162 | 54.3% | -9.6 (-27.2 to +8.0) |
| delusional | 34 | 55.9% | 166 | 51.8% | +4.1 (-14.3 to +22.4) |
| muddler | 45 | 55.6% | 155 | 51.6% | +3.9 (-12.6 to +20.5) |
| sleepwalker | 37 | 54.1% | 163 | 52.1% | +1.9 (-15.9 to +19.7) |
| lovers | 46 | 52.2% | 154 | 52.6% | -0.4 (-16.9 to +16.0) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 53.6% | 75 | 50.7% | +2.9 (-11.4 to +17.2) |
| 3 night-walkers | 70 | 54.3% | 130 | 51.5% | +2.7 (-11.7 to +17.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.2 | 25.4% | 14.9% | 90.4% |
| archivist | 108 | 2.1 | 36.1% | 19.4% | 92.6% |
| rumormonger | 102 | 2.4 | 27.5% | 16.7% | 89.2% |
| surveyor | 96 | 2.5 | 21.9% | 11.5% | 95.8% |
| registrar | 66 | 2.3 | 28.8% | 10.6% | 80.3% |
| warden | 53 | 2.1 | 32.1% | 20.8% | 67.9% |
| gravedigger | 53 | 2.0 | 39.6% | 30.2% | 81.1% |
| dowser | 53 | 2.1 | 22.6% | 13.2% | 83.0% |
| nightwatch | 50 | 2.0 | 32.0% | 18.0% | 72.0% |
| confessor | 44 | 2.2 | 29.5% | 25.0% | 75.0% |
| lamplighter | 42 | 2.1 | 28.6% | 23.8% | 73.8% |
| augur | 37 | 2.0 | 18.9% | 21.6% | 70.3% |
| medium | 32 | 1.8 | 40.6% | 6.2% | 62.5% |
| seer | 32 | 2.5 | 21.9% | 6.2% | 78.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 74.3% |
| confessor | 32 | 0.0% | 65.6% |
| dowser | 30 | 0.0% | 63.3% |
| lamplighter | 24 | 0.0% | 83.3% |
| rumormonger | 24 | 0.0% | 50.0% |
| medium | 24 | 0.0% | 16.7% |
| surveyor | 23 | 0.0% | 43.5% |
| clerk | 22 | 0.0% | 31.8% |
| archivist | 21 | 0.0% | 71.4% |
| gravedigger | 20 | 0.0% | 70.0% |
| augur | 18 | 0.0% | 55.6% |
| chronicler | 17 | 0.0% | 58.8% |
| psychologist | 17 | 0.0% | 52.9% |
| magistrate | 16 | 0.0% | 43.8% |
| registrar | 15 | 0.0% | 40.0% |
| seer | 15 | 0.0% | 46.7% |
| executor | 13 | 0.0% | 53.8% |
| monitor | 12 | 0.0% | 50.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no declaring insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| gravedigger | 53 | 22.6% | 147 | 58.5% | -35.9 (-49.7 to -22.1) **\*** |
| seer | 32 | 75.0% | 168 | 44.0% | +31.0 (+14.2 to +47.7) **\*** |
| medium | 32 | 71.9% | 168 | 44.6% | +27.2 (+9.9 to +44.5) **\*** |
| archivist | 108 | 40.7% | 92 | 58.7% | -18.0 (-31.6 to -4.3) **\*** |
| clerk | 114 | 56.1% | 86 | 39.5% | +16.6 (+2.8 to +30.4) **\*** |
| nightwatch | 50 | 38.0% | 150 | 52.7% | -14.7 (-30.3 to +1.0) |
| warden | 53 | 58.5% | 147 | 45.6% | +12.9 (-2.6 to +28.4) |
| lamplighter | 42 | 40.5% | 158 | 51.3% | -10.8 (-27.6 to +6.0) |
| surveyor | 96 | 53.1% | 104 | 45.2% | +7.9 (-5.9 to +21.8) |
| dowser | 53 | 54.7% | 147 | 46.9% | +7.8 (-7.9 to +23.4) |
| augur | 37 | 54.1% | 163 | 47.9% | +6.2 (-11.6 to +24.0) |
| rumormonger | 102 | 46.1% | 98 | 52.0% | -6.0 (-19.8 to +7.9) |
| confessor | 44 | 52.3% | 156 | 48.1% | +4.2 (-12.5 to +20.9) |
| registrar | 66 | 47.0% | 134 | 50.0% | -3.0 (-17.7 to +11.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 68.6% | 149 | 42.3% | +26.3 (+11.3 to +41.3) **\*** |
| poisoner | 59 | 33.9% | 141 | 55.3% | -21.4 (-36.0 to -6.8) **\*** |
| scion | 55 | 41.8% | 145 | 51.7% | -9.9 (-25.3 to +5.5) |
| revenant | 35 | 57.1% | 165 | 47.3% | +9.9 (-8.2 to +27.9) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| marked | 38 | 39.5% | 162 | 51.2% | -11.8 (-29.1 to +5.6) |
| muddler | 45 | 55.6% | 155 | 47.1% | +8.5 (-8.0 to +25.0) |
| lovers | 46 | 54.3% | 154 | 47.4% | +6.9 (-9.5 to +23.4) |
| sleepwalker | 37 | 45.9% | 163 | 49.7% | -3.7 (-21.5 to +14.1) |
| delusional | 34 | 47.1% | 166 | 49.4% | -2.3 (-20.8 to +16.1) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 51.2% | 75 | 45.3% | +5.9 (-8.4 to +20.1) |
| 3 night-walkers | 70 | 47.1% | 130 | 50.0% | -2.9 (-17.4 to +11.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.2 | 28.1% | 18.4% | 89.5% |
| archivist | 108 | 2.1 | 35.2% | 21.3% | 93.5% |
| rumormonger | 102 | 2.4 | 27.5% | 18.6% | 89.2% |
| surveyor | 96 | 2.6 | 19.8% | 15.6% | 96.9% |
| registrar | 66 | 2.1 | 28.8% | 7.6% | 80.3% |
| warden | 53 | 2.2 | 30.2% | 26.4% | 69.8% |
| gravedigger | 53 | 2.0 | 41.5% | 32.1% | 81.1% |
| dowser | 53 | 2.2 | 24.5% | 17.0% | 83.0% |
| nightwatch | 50 | 2.1 | 32.0% | 18.0% | 72.0% |
| confessor | 44 | 2.1 | 31.8% | 20.5% | 75.0% |
| lamplighter | 42 | 1.8 | 28.6% | 26.2% | 71.4% |
| augur | 37 | 2.0 | 18.9% | 18.9% | 75.7% |
| medium | 32 | 1.8 | 40.6% | 6.2% | 59.4% |
| seer | 32 | 2.3 | 21.9% | 6.2% | 78.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 35 | 0.0% | 71.4% |
| confessor | 32 | 0.0% | 62.5% |
| dowser | 30 | 0.0% | 60.0% |
| lamplighter | 24 | 0.0% | 87.5% |
| rumormonger | 24 | 0.0% | 58.3% |
| medium | 24 | 0.0% | 20.8% |
| surveyor | 23 | 0.0% | 39.1% |
| clerk | 22 | 0.0% | 36.4% |
| archivist | 21 | 0.0% | 61.9% |
| gravedigger | 20 | 0.0% | 70.0% |
| augur | 18 | 0.0% | 50.0% |
| chronicler | 17 | 0.0% | 47.1% |
| psychologist | 17 | 0.0% | 64.7% |
| magistrate | 16 | 0.0% | 37.5% |
| registrar | 15 | 0.0% | 46.7% |
| seer | 15 | 0.0% | 46.7% |
| executor | 13 | 0.0% | 53.8% |
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
| 7 NPCs, bot insight 1.0 | 64.4 | 139.3 | 230.1 |
| 7 NPCs, bot, no declaring insight 1.0 | 45.9 | 93.8 | 204.8 |

Slowest seeds: 100191 (7 NPCs bot, 230 s), 100140 (7 NPCs bot, 216 s), 100099 (7 NPCs bot, 214 s), 100072 (7 NPCs bot, 210 s), 100088 (7 NPCs bot_nodeclare, 205 s), 100141 (7 NPCs bot, 200 s), 100143 (7 NPCs bot, 199 s), 100005 (7 NPCs bot, 185 s), 100080 (7 NPCs bot, 180 s), 100067 (7 NPCs bot, 180 s), 100004 (7 NPCs bot, 180 s), 100138 (7 NPCs bot, 175 s), 100109 (7 NPCs bot, 174 s), 100008 (7 NPCs bot, 172 s), 100111 (7 NPCs bot_nodeclare, 163 s), 100069 (7 NPCs bot, 161 s), 100060 (7 NPCs bot, 157 s), 100140 (7 NPCs bot_nodeclare, 153 s), 100111 (7 NPCs bot, 149 s), 100061 (7 NPCs bot, 147 s)

