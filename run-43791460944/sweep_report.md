# Balance sweep report

Records: 441 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `435fb077b1`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 441 | 71.7% (67.3%–75.7%) | 4.10 | 0.81 | 1.80 | 2.56 | 7.7% | 0.39 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 8.45 | 11.7% | 25.5% | 3.99 | 12.9% | 11.2% | 10.2% |

### End reasons and solvability

**10 NPCs, bot insight 1.0** (n=441)

- The demon's host was executed.: 316 (71.7%)
- Only two townsfolk remain and the demon still walks among them.: 97 (22.0%)
- No good soul remains.: 27 (6.1%)
- Time ran out: the demon survived 8 days.: 1 (0.2%)
- Demon evidence on the board: 99.8% of games; good win rate 71.8% of 440
- Demon evidence reachable: 85.5% of games; good win rate 69.5% of 377
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| executor | 63 | 79.4% | 378 | 70.4% | +9.0 (-2.0 to +20.0) |
| seer | 105 | 78.1% | 336 | 69.6% | +8.5 (-0.9 to +17.8) |
| confessor | 175 | 66.9% | 266 | 74.8% | -8.0 (-16.7 to +0.8) |
| nightwatch | 199 | 75.9% | 242 | 68.2% | +7.7 (-0.7 to +16.1) |
| monitor | 64 | 78.1% | 377 | 70.6% | +7.6 (-3.6 to +18.7) |
| gravedigger | 158 | 67.1% | 283 | 74.2% | -7.1 (-16.0 to +1.8) |
| lamplighter | 176 | 67.6% | 265 | 74.3% | -6.7 (-15.4 to +2.0) |
| registrar | 152 | 75.7% | 289 | 69.6% | +6.1 (-2.5 to +14.8) |
| dowser | 152 | 67.8% | 289 | 73.7% | -5.9 (-14.9 to +3.1) |
| chronicler | 57 | 66.7% | 384 | 72.4% | -5.7 (-18.8 to +7.3) |
| medium | 183 | 68.3% | 258 | 74.0% | -5.7 (-14.3 to +2.9) |
| warden | 173 | 74.6% | 268 | 69.8% | +4.8 (-3.7 to +13.3) |
| archivist | 243 | 69.5% | 198 | 74.2% | -4.7 (-13.1 to +3.7) |
| clerk | 253 | 73.5% | 188 | 69.1% | +4.4 (-4.2 to +12.9) |
| augur | 99 | 74.7% | 342 | 70.8% | +4.0 (-5.8 to +13.8) |
| magistrate | 56 | 75.0% | 385 | 71.2% | +3.8 (-8.4 to +16.0) |
| surveyor | 261 | 70.1% | 180 | 73.9% | -3.8 (-12.3 to +4.7) |
| martyr | 61 | 68.9% | 380 | 72.1% | -3.3 (-15.7 to +9.2) |
| veteran | 74 | 74.3% | 367 | 71.1% | +3.2 (-7.8 to +14.2) |
| rumormonger | 264 | 72.7% | 177 | 70.1% | +2.7 (-6.0 to +11.3) |
| sexton | 56 | 69.6% | 385 | 71.9% | -2.3 (-15.2 to +10.5) |
| psychologist | 63 | 71.4% | 378 | 71.7% | -0.3 (-12.3 to +11.8) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| scion | 122 | 67.2% | 319 | 73.4% | -6.1 (-15.8 to +3.5) |
| revenant | 128 | 74.2% | 313 | 70.6% | +3.6 (-5.5 to +12.7) |
| poisoner | 191 | 72.8% | 250 | 70.8% | +2.0 (-6.5 to +10.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| muddler | 88 | 78.4% | 353 | 70.0% | +8.4 (-1.4 to +18.3) |
| delusional | 93 | 65.6% | 348 | 73.3% | -7.7 (-18.4 to +3.0) |
| marked | 95 | 68.4% | 346 | 72.5% | -4.1 (-14.6 to +6.3) |
| lovers | 76 | 75.0% | 365 | 71.0% | +4.0 (-6.8 to +14.8) |
| sleepwalker | 89 | 71.9% | 352 | 71.6% | +0.3 (-10.1 to +10.8) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 31 | 61.3% | 410 | 72.4% | -11.1 (-28.8 to +6.5) |
| 3 night-walkers | 257 | 72.8% | 184 | 70.1% | +2.7 (-5.9 to +11.2) |
| 4 night-walkers | 153 | 71.9% | 288 | 71.5% | +0.4 (-8.5 to +9.2) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 264 | 3.0 | 14.0% | 12.1% | 82.2% |
| surveyor | 261 | 2.8 | 20.7% | 8.8% | 80.5% |
| clerk | 253 | 3.0 | 13.0% | 8.3% | 85.4% |
| archivist | 243 | 1.8 | 52.7% | 9.9% | 85.2% |
| nightwatch | 199 | 2.5 | 26.6% | 13.6% | 78.9% |
| medium | 183 | 2.8 | 23.0% | 9.8% | 70.5% |
| lamplighter | 176 | 2.8 | 14.2% | 16.5% | 80.1% |
| confessor | 175 | 2.9 | 16.6% | 20.6% | 73.1% |
| warden | 173 | 3.2 | 9.2% | 17.3% | 71.7% |
| gravedigger | 158 | 2.3 | 36.1% | 10.1% | 73.4% |
| registrar | 152 | 2.4 | 27.6% | 5.3% | 68.4% |
| dowser | 152 | 2.1 | 38.2% | 7.9% | 78.9% |
| seer | 105 | 2.1 | 35.2% | 11.4% | 80.0% |
| augur | 99 | 2.6 | 27.3% | 11.1% | 68.7% |
| veteran | 74 | 3.9 | 1.4% | 13.5% | 73.0% |
| monitor | 64 | 2.5 | 15.6% | 10.9% | 67.2% |
| psychologist | 63 | 2.4 | 25.4% | 12.7% | 73.0% |
| executor | 63 | 2.6 | 23.8% | 7.9% | 68.3% |
| martyr | 61 | 3.2 | 6.6% | 11.5% | 78.7% |
| chronicler | 57 | 2.9 | 19.3% | 7.0% | 75.4% |
| sexton | 56 | 3.6 | 7.1% | 16.1% | 69.6% |
| magistrate | 56 | 2.5 | 33.9% | 7.1% | 67.9% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 99 | 0.0% | 47.5% |
| dowser | 88 | 0.0% | 76.1% |
| confessor | 85 | 0.0% | 81.2% |
| archivist | 84 | 0.0% | 63.1% |
| gravedigger | 84 | 0.0% | 63.1% |
| clerk | 80 | 0.0% | 58.8% |
| surveyor | 78 | 0.0% | 65.4% |
| rumormonger | 77 | 0.0% | 63.6% |
| lamplighter | 74 | 0.0% | 75.7% |
| medium | 65 | 0.0% | 58.5% |
| magistrate | 57 | 0.0% | 70.2% |
| monitor | 56 | 0.0% | 39.3% |
| nightwatch | 56 | 0.0% | 66.1% |
| seer | 51 | 0.0% | 56.9% |
| psychologist | 51 | 0.0% | 51.0% |
| chronicler | 50 | 0.0% | 54.0% |
| executor | 48 | 0.0% | 52.1% |
| augur | 42 | 0.0% | 57.1% |
| sexton | 16 | 0.0% | 62.5% |
| warden | 10 | 0.0% | 70.0% |
| veteran | 10 | 0.0% | 70.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: 10 NPCs, bot insight 1.0: 558 (first 100002, 100003, 100004, 100005, 100006, 100007, 100008, 100009, 100010, 100013)
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 2 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 263.5 | 566.9 | 1179.7 |

Slowest seeds: 100289 (10 NPCs bot, 1180 s), 100078 (10 NPCs bot, 1179 s), 100156 (10 NPCs bot, 1076 s), 100139 (10 NPCs bot, 1042 s), 100256 (10 NPCs bot, 921 s), 100127 (10 NPCs bot, 912 s), 100274 (10 NPCs bot, 907 s), 100149 (10 NPCs bot, 891 s), 100338 (10 NPCs bot, 867 s), 100363 (10 NPCs bot, 847 s), 100084 (10 NPCs bot, 836 s), 100361 (10 NPCs bot, 826 s), 100099 (10 NPCs bot, 793 s), 100235 (10 NPCs bot, 779 s), 100298 (10 NPCs bot, 779 s), 100297 (10 NPCs bot, 764 s), 100316 (10 NPCs bot, 755 s), 100863 (10 NPCs bot, 739 s), 100024 (10 NPCs bot, 736 s), 100716 (10 NPCs bot, 720 s)

