# Balance sweep report

Records: 300 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `9b2ca88709`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0, connections on | 300 | 69.7% (64.2%–74.6%) | 4.01 | 0.86 | 1.80 | 2.36 | 8.7% | 0.45 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0, connections on | 8.13 | 14.1% | 25.9% | 3.56 | 11.5% | 10.6% | 8.9% |

### End reasons and solvability

**10 NPCs, bot insight 1.0, connections on** (n=300)

- The demon's host was executed.: 209 (69.7%)
- Only two townsfolk remain and the demon still walks among them.: 70 (23.3%)
- No good soul remains.: 20 (6.7%)
- Time ran out: the demon survived 8 days.: 1 (0.3%)
- Demon evidence on the board: 100.0% of games; good win rate 69.7% of 300
- Demon evidence reachable: 85.7% of games; good win rate 66.5% of 257
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 10 NPCs, bot insight 1.0, connections on

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| monitor | 39 | 87.2% | 261 | 67.0% | +20.1 (+8.2 to +32.1) **\*** |
| archivist | 166 | 63.9% | 134 | 76.9% | -13.0 (-23.2 to -2.8) **\*** |
| medium | 103 | 61.2% | 197 | 74.1% | -12.9 (-24.2 to -1.7) **\*** |
| executor | 39 | 59.0% | 261 | 71.3% | -12.3 (-28.7 to +4.1) |
| chronicler | 52 | 59.6% | 248 | 71.8% | -12.2 (-26.6 to +2.3) |
| dowser | 115 | 76.5% | 185 | 65.4% | +11.1 (+0.8 to +21.5) **\*** |
| psychologist | 45 | 77.8% | 255 | 68.2% | +9.5 (-3.9 to +23.0) |
| nightwatch | 127 | 74.8% | 173 | 65.9% | +8.9 (-1.4 to +19.2) |
| clerk | 176 | 73.3% | 124 | 64.5% | +8.8 (-1.9 to +19.4) |
| sexton | 45 | 62.2% | 255 | 71.0% | -8.8 (-24.0 to +6.5) |
| augur | 58 | 63.8% | 242 | 71.1% | -7.3 (-20.9 to +6.3) |
| martyr | 46 | 73.9% | 254 | 68.9% | +5.0 (-8.9 to +18.9) |
| seer | 75 | 66.7% | 225 | 70.7% | -4.0 (-16.2 to +8.2) |
| surveyor | 174 | 71.3% | 126 | 67.5% | +3.8 (-6.8 to +14.4) |
| magistrate | 33 | 72.7% | 267 | 69.3% | +3.4 (-12.7 to +19.6) |
| veteran | 50 | 72.0% | 250 | 69.2% | +2.8 (-10.9 to +16.5) |
| lamplighter | 113 | 68.1% | 187 | 70.6% | -2.4 (-13.2 to +8.3) |
| registrar | 117 | 68.4% | 183 | 70.5% | -2.1 (-12.8 to +8.6) |
| confessor | 120 | 70.8% | 180 | 68.9% | +1.9 (-8.6 to +12.5) |
| gravedigger | 118 | 68.6% | 182 | 70.3% | -1.7 (-12.4 to +9.0) |
| warden | 116 | 70.7% | 184 | 69.0% | +1.7 (-9.0 to +12.3) |
| rumormonger | 173 | 69.9% | 127 | 69.3% | +0.7 (-9.9 to +11.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| scion | 129 | 60.5% | 171 | 76.6% | -16.1 (-26.7 to -5.6) **\*** |
| breathstealer | 136 | 77.9% | 164 | 62.8% | +15.1 (+5.0 to +25.3) **\*** |
| poisoner | 190 | 71.6% | 110 | 66.4% | +5.2 (-5.7 to +16.1) |
| revenant | 145 | 67.6% | 155 | 71.6% | -4.0 (-14.4 to +6.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sleepwalker | 59 | 61.0% | 241 | 71.8% | -10.8 (-24.4 to +2.9) |
| delusional | 60 | 75.0% | 240 | 68.3% | +6.7 (-5.8 to +19.1) |
| muddler | 56 | 71.4% | 244 | 69.3% | +2.2 (-11.0 to +15.3) |
| marked | 62 | 71.0% | 238 | 69.3% | +1.6 (-11.1 to +14.4) |
| lovers | 63 | 69.8% | 237 | 69.6% | +0.2 (-12.5 to +13.0) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 111 | 72.1% | 189 | 68.3% | +3.8 (-6.8 to +14.5) |
| 3 night-walkers | 160 | 68.1% | 140 | 71.4% | -3.3 (-13.7 to +7.1) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| clerk | 176 | 2.9 | 16.5% | 9.1% | 94.9% |
| surveyor | 174 | 3.1 | 14.4% | 13.8% | 94.8% |
| rumormonger | 173 | 3.2 | 11.6% | 11.6% | 97.1% |
| archivist | 166 | 1.9 | 50.6% | 10.2% | 95.2% |
| nightwatch | 127 | 2.1 | 27.6% | 20.5% | 90.6% |
| confessor | 120 | 2.5 | 20.8% | 25.8% | 92.5% |
| gravedigger | 118 | 2.3 | 32.2% | 16.1% | 87.3% |
| registrar | 117 | 2.4 | 25.6% | 6.8% | 88.0% |
| warden | 116 | 3.0 | 14.7% | 15.5% | 87.9% |
| dowser | 115 | 2.1 | 49.6% | 4.3% | 91.3% |
| lamplighter | 113 | 2.6 | 23.9% | 9.7% | 89.4% |
| medium | 103 | 2.8 | 21.4% | 12.6% | 83.5% |
| seer | 75 | 2.3 | 40.0% | 8.0% | 94.7% |
| augur | 58 | 2.4 | 25.9% | 10.3% | 79.3% |
| chronicler | 52 | 2.8 | 19.2% | 15.4% | 88.5% |
| veteran | 50 | 3.2 | 6.0% | 16.0% | 92.0% |
| martyr | 46 | 2.7 | 13.0% | 6.5% | 87.0% |
| psychologist | 45 | 2.5 | 15.6% | 8.9% | 88.9% |
| sexton | 45 | 3.5 | 6.7% | 22.2% | 82.2% |
| monitor | 39 | 2.5 | 17.9% | 0.0% | 76.9% |
| executor | 39 | 3.0 | 23.1% | 2.6% | 92.3% |
| magistrate | 33 | 2.6 | 21.2% | 6.1% | 75.8% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| archivist | 68 | 0.0% | 73.5% |
| dowser | 59 | 0.0% | 66.1% |
| surveyor | 57 | 0.0% | 64.9% |
| clerk | 55 | 0.0% | 50.9% |
| registrar | 53 | 0.0% | 52.8% |
| rumormonger | 53 | 0.0% | 62.3% |
| gravedigger | 52 | 0.0% | 71.2% |
| medium | 51 | 0.0% | 62.7% |
| confessor | 50 | 0.0% | 72.0% |
| lamplighter | 49 | 0.0% | 77.6% |
| magistrate | 48 | 0.0% | 58.3% |
| augur | 42 | 0.0% | 66.7% |
| nightwatch | 38 | 0.0% | 68.4% |
| monitor | 36 | 0.0% | 25.0% |
| psychologist | 33 | 0.0% | 54.5% |
| chronicler | 32 | 0.0% | 65.6% |
| seer | 28 | 0.0% | 42.9% |
| executor | 25 | 0.0% | 48.0% |

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
| 10 NPCs, bot insight 1.0, connections on | 435.5 | 848.6 | 1697.8 |

Slowest seeds: 100093 (10 NPCs bot_connections, 1698 s), 100289 (10 NPCs bot_connections, 1488 s), 100008 (10 NPCs bot_connections, 1415 s), 100197 (10 NPCs bot_connections, 1384 s), 100205 (10 NPCs bot_connections, 1241 s), 100063 (10 NPCs bot_connections, 1211 s), 100284 (10 NPCs bot_connections, 1149 s), 100287 (10 NPCs bot_connections, 1137 s), 100183 (10 NPCs bot_connections, 1127 s), 100044 (10 NPCs bot_connections, 1113 s), 100258 (10 NPCs bot_connections, 1112 s), 100203 (10 NPCs bot_connections, 1099 s), 100181 (10 NPCs bot_connections, 1036 s), 100019 (10 NPCs bot_connections, 1028 s), 100169 (10 NPCs bot_connections, 1023 s), 100012 (10 NPCs bot_connections, 1004 s), 100051 (10 NPCs bot_connections, 1003 s), 100006 (10 NPCs bot_connections, 989 s), 100018 (10 NPCs bot_connections, 982 s), 100142 (10 NPCs bot_connections, 979 s)

