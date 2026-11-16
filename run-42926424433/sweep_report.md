# Balance sweep report

Records: 400 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `da9a993f72`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 200 | 55.0% (48.1%–61.7%) | 3.11 | 0.82 | 1.03 | 2.24 | 11.0% | 0.30 |
| 7 NPCs, bot, no presenting insight 1.0 | 200 | 56.0% (49.1%–62.7%) | 3.12 | 0.78 | 1.03 | 2.29 | 9.5% | 0.27 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 4.91 | 21.0% | 29.5% | 1.96 | 18.6% | 17.1% | 16.0% |
| 7 NPCs, bot, no presenting insight 1.0 | 4.96 | 19.3% | 29.6% | 2.01 | 12.7% | 12.8% | 12.0% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=200)

- The demon's host was executed.: 110 (55.0%)
- Only two townsfolk remain and the demon still walks among them.: 90 (45.0%)
- Demon evidence on the board: 96.5% of games; good win rate 53.9% of 193
- Demon evidence reachable: 84.0% of games; good win rate 51.2% of 168
- Neither: 3.0% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, bot, no presenting insight 1.0** (n=200)

- The demon's host was executed.: 112 (56.0%)
- Only two townsfolk remain and the demon still walks among them.: 88 (44.0%)
- Demon evidence on the board: 96.5% of games; good win rate 54.9% of 193
- Demon evidence reachable: 82.5% of games; good win rate 53.3% of 165
- Neither: 2.0% of games; good win rate 100.0% of 4
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| confessor | 44 | 40.9% | 156 | 59.0% | -18.1 (-34.5 to -1.6) **\*** |
| medium | 32 | 68.8% | 168 | 52.4% | +16.4 (-1.4 to +34.1) |
| dowser | 53 | 66.0% | 147 | 51.0% | +15.0 (-0.1 to +30.1) |
| gravedigger | 53 | 47.2% | 147 | 57.8% | -10.7 (-26.3 to +5.0) |
| augur | 37 | 62.2% | 163 | 53.4% | +8.8 (-8.6 to +26.2) |
| nightwatch | 50 | 60.0% | 150 | 53.3% | +6.7 (-9.1 to +22.4) |
| seer | 32 | 50.0% | 168 | 56.0% | -6.0 (-24.8 to +12.9) |
| surveyor | 96 | 52.1% | 104 | 57.7% | -5.6 (-19.4 to +8.2) |
| registrar | 66 | 56.1% | 134 | 54.5% | +1.6 (-13.1 to +16.2) |
| archivist | 108 | 55.6% | 92 | 54.3% | +1.2 (-12.6 to +15.0) |
| clerk | 114 | 55.3% | 86 | 54.7% | +0.6 (-13.3 to +14.5) |
| warden | 53 | 54.7% | 147 | 55.1% | -0.4 (-16.0 to +15.2) |
| lamplighter | 42 | 54.8% | 158 | 55.1% | -0.3 (-17.2 to +16.6) |
| rumormonger | 102 | 54.9% | 98 | 55.1% | -0.2 (-14.0 to +13.6) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 51 | 62.7% | 149 | 52.3% | +10.4 (-5.1 to +25.9) |
| revenant | 35 | 48.6% | 165 | 56.4% | -7.8 (-26.0 to +10.4) |
| scion | 55 | 52.7% | 145 | 55.9% | -3.1 (-18.6 to +12.3) |
| poisoner | 59 | 54.2% | 141 | 55.3% | -1.1 (-16.2 to +14.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lovers | 46 | 63.0% | 154 | 52.6% | +10.4 (-5.6 to +26.5) |
| marked | 38 | 50.0% | 162 | 56.2% | -6.2 (-23.8 to +11.5) |
| delusional | 34 | 52.9% | 166 | 55.4% | -2.5 (-20.9 to +15.9) |
| muddler | 45 | 53.3% | 155 | 55.5% | -2.2 (-18.7 to +14.4) |
| sleepwalker | 37 | 54.1% | 163 | 55.2% | -1.2 (-18.9 to +16.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 70 | 60.0% | 130 | 52.3% | +7.7 (-6.6 to +22.0) |
| 2 night-walkers | 125 | 53.6% | 75 | 57.3% | -3.7 (-17.9 to +10.5) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.1 | 23.7% | 19.3% | 93.9% |
| archivist | 108 | 1.5 | 54.6% | 14.8% | 95.4% |
| rumormonger | 102 | 2.4 | 21.6% | 15.7% | 94.1% |
| surveyor | 96 | 2.1 | 19.8% | 14.6% | 90.6% |
| registrar | 66 | 2.2 | 34.8% | 10.6% | 78.8% |
| warden | 53 | 2.1 | 28.3% | 17.0% | 71.7% |
| gravedigger | 53 | 1.9 | 52.8% | 18.9% | 86.8% |
| dowser | 53 | 1.7 | 45.3% | 9.4% | 86.8% |
| nightwatch | 50 | 2.1 | 26.0% | 22.0% | 92.0% |
| confessor | 44 | 1.9 | 27.3% | 36.4% | 84.1% |
| lamplighter | 42 | 2.3 | 14.3% | 16.7% | 92.9% |
| augur | 37 | 2.3 | 29.7% | 16.2% | 91.9% |
| medium | 32 | 2.4 | 21.9% | 15.6% | 81.2% |
| seer | 32 | 2.0 | 46.9% | 18.8% | 90.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 52.8% |
| confessor | 33 | 0.0% | 66.7% |
| dowser | 29 | 0.0% | 55.2% |
| rumormonger | 24 | 0.0% | 66.7% |
| medium | 24 | 0.0% | 25.0% |
| lamplighter | 23 | 0.0% | 56.5% |
| surveyor | 23 | 0.0% | 56.5% |
| clerk | 22 | 0.0% | 50.0% |
| archivist | 20 | 0.0% | 55.0% |
| gravedigger | 19 | 0.0% | 73.7% |
| magistrate | 17 | 0.0% | 52.9% |
| augur | 17 | 0.0% | 41.2% |
| psychologist | 17 | 0.0% | 52.9% |
| registrar | 16 | 0.0% | 56.2% |
| chronicler | 16 | 0.0% | 50.0% |
| seer | 14 | 0.0% | 50.0% |
| executor | 13 | 0.0% | 23.1% |
| monitor | 12 | 0.0% | 58.3% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 7 NPCs, bot, no presenting insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| dowser | 53 | 67.9% | 147 | 51.7% | +16.2 (+1.3 to +31.2) **\*** |
| gravedigger | 53 | 45.3% | 147 | 59.9% | -14.6 (-30.1 to +1.0) |
| registrar | 66 | 50.0% | 134 | 59.0% | -9.0 (-23.6 to +5.7) |
| nightwatch | 50 | 62.0% | 150 | 54.0% | +8.0 (-7.6 to +23.6) |
| augur | 37 | 62.2% | 163 | 54.6% | +7.6 (-9.8 to +25.0) |
| archivist | 108 | 52.8% | 92 | 59.8% | -7.0 (-20.8 to +6.7) |
| rumormonger | 102 | 58.8% | 98 | 53.1% | +5.8 (-8.0 to +19.5) |
| surveyor | 96 | 53.1% | 104 | 58.7% | -5.5 (-19.3 to +8.2) |
| lamplighter | 42 | 52.4% | 158 | 57.0% | -4.6 (-21.5 to +12.4) |
| clerk | 114 | 57.9% | 86 | 53.5% | +4.4 (-9.5 to +18.3) |
| seer | 32 | 59.4% | 168 | 55.4% | +4.0 (-14.6 to +22.6) |
| warden | 53 | 58.5% | 147 | 55.1% | +3.4 (-12.1 to +18.9) |
| confessor | 44 | 56.8% | 156 | 55.8% | +1.0 (-15.5 to +17.6) |
| medium | 32 | 56.2% | 168 | 56.0% | +0.3 (-18.5 to +19.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner | 59 | 47.5% | 141 | 59.6% | -12.1 (-27.2 to +3.0) |
| breathstealer | 51 | 64.7% | 149 | 53.0% | +11.7 (-3.7 to +27.1) |
| scion | 55 | 58.2% | 145 | 55.2% | +3.0 (-12.3 to +18.4) |
| revenant | 35 | 54.3% | 165 | 56.4% | -2.1 (-20.2 to +16.1) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lovers | 46 | 67.4% | 154 | 52.6% | +14.8 (-0.9 to +30.5) |
| sleepwalker | 37 | 45.9% | 163 | 58.3% | -12.3 (-30.1 to +5.4) |
| marked | 38 | 52.6% | 162 | 56.8% | -4.2 (-21.8 to +13.5) |
| muddler | 45 | 53.3% | 155 | 56.8% | -3.4 (-20.0 to +13.1) |
| delusional | 34 | 58.8% | 166 | 55.4% | +3.4 (-14.8 to +21.6) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 2 night-walkers | 125 | 56.8% | 75 | 54.7% | +2.1 (-12.1 to +16.4) |
| 3 night-walkers | 70 | 55.7% | 130 | 56.2% | -0.4 (-14.9 to +14.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 114 | 2.3 | 19.3% | 21.9% | 93.0% |
| archivist | 108 | 1.4 | 55.6% | 20.4% | 94.4% |
| rumormonger | 102 | 2.4 | 22.5% | 22.5% | 93.1% |
| surveyor | 96 | 2.3 | 24.0% | 15.6% | 91.7% |
| registrar | 66 | 2.0 | 43.9% | 9.1% | 84.8% |
| warden | 53 | 2.5 | 26.4% | 17.0% | 79.2% |
| gravedigger | 53 | 2.0 | 52.8% | 15.1% | 88.7% |
| dowser | 53 | 1.9 | 41.5% | 5.7% | 92.5% |
| nightwatch | 50 | 2.0 | 28.0% | 16.0% | 84.0% |
| confessor | 44 | 2.1 | 31.8% | 13.6% | 86.4% |
| lamplighter | 42 | 2.4 | 19.0% | 9.5% | 92.9% |
| augur | 37 | 2.2 | 24.3% | 10.8% | 83.8% |
| medium | 32 | 2.4 | 18.8% | 15.6% | 84.4% |
| seer | 32 | 1.8 | 53.1% | 12.5% | 87.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 36 | 0.0% | 55.6% |
| confessor | 33 | 0.0% | 63.6% |
| dowser | 29 | 0.0% | 69.0% |
| rumormonger | 24 | 0.0% | 58.3% |
| medium | 24 | 0.0% | 25.0% |
| lamplighter | 22 | 0.0% | 59.1% |
| surveyor | 22 | 0.0% | 54.5% |
| clerk | 22 | 0.0% | 59.1% |
| archivist | 21 | 0.0% | 57.1% |
| gravedigger | 19 | 0.0% | 68.4% |
| augur | 17 | 0.0% | 52.9% |
| psychologist | 17 | 0.0% | 58.8% |
| magistrate | 16 | 0.0% | 50.0% |
| registrar | 16 | 0.0% | 43.8% |
| chronicler | 16 | 0.0% | 37.5% |
| seer | 14 | 0.0% | 50.0% |
| executor | 13 | 0.0% | 46.2% |
| monitor | 12 | 0.0% | 50.0% |

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
- Shared-model fallbacks: 2 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 39.7 | 79.9 | 236.8 |
| 7 NPCs, bot, no presenting insight 1.0 | 64.0 | 125.4 | 343.2 |

Slowest seeds: 100118 (7 NPCs no_present, 343 s), 100142 (7 NPCs bot, 237 s), 100104 (7 NPCs no_present, 213 s), 100107 (7 NPCs no_present, 196 s), 100188 (7 NPCs no_present, 174 s), 100005 (7 NPCs bot, 171 s), 100062 (7 NPCs no_present, 157 s), 100039 (7 NPCs no_present, 154 s), 100114 (7 NPCs no_present, 153 s), 100117 (7 NPCs no_present, 153 s), 100150 (7 NPCs bot, 152 s), 100197 (7 NPCs no_present, 150 s), 100150 (7 NPCs no_present, 149 s), 100185 (7 NPCs no_present, 144 s), 100094 (7 NPCs no_present, 142 s), 100085 (7 NPCs no_present, 139 s), 100012 (7 NPCs no_present, 138 s), 100076 (7 NPCs no_present, 137 s), 100105 (7 NPCs no_present, 137 s), 100101 (7 NPCs no_present, 134 s)

