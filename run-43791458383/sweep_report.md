# Balance sweep report

Records: 441 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `59b34792ce`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 441 | 70.5% (66.1%–74.6%) | 3.99 | 0.82 | 1.68 | 2.47 | 9.5% | 0.40 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 8.15 | 12.2% | 26.7% | 3.77 | 13.7% | 12.9% | 11.3% |

### End reasons and solvability

**10 NPCs, bot insight 1.0** (n=441)

- The demon's host was executed.: 311 (70.5%)
- Only two townsfolk remain and the demon still walks among them.: 93 (21.1%)
- No good soul remains.: 37 (8.4%)
- Demon evidence on the board: 99.3% of games; good win rate 70.3% of 438
- Demon evidence reachable: 88.7% of games; good win rate 68.0% of 391
- Neither: 0.2% of games; good win rate 100.0% of 1
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| chronicler | 57 | 52.6% | 384 | 73.2% | -20.5 (-34.2 to -6.8) **\*** |
| sexton | 56 | 57.1% | 385 | 72.5% | -15.3 (-29.0 to -1.6) **\*** |
| martyr | 61 | 78.7% | 380 | 69.2% | +9.5 (-1.8 to +20.8) |
| augur | 99 | 77.8% | 342 | 68.4% | +9.4 (-0.2 to +18.9) |
| gravedigger | 158 | 65.2% | 283 | 73.5% | -8.3 (-17.3 to +0.7) |
| psychologist | 63 | 65.1% | 378 | 71.4% | -6.3 (-19.0 to +6.3) |
| nightwatch | 199 | 73.9% | 242 | 67.8% | +6.1 (-2.4 to +14.6) |
| confessor | 175 | 66.9% | 266 | 72.9% | -6.1 (-14.9 to +2.7) |
| rumormonger | 264 | 72.7% | 177 | 67.2% | +5.5 (-3.3 to +14.3) |
| archivist | 243 | 68.3% | 198 | 73.2% | -4.9 (-13.4 to +3.6) |
| dowser | 152 | 73.7% | 289 | 68.9% | +4.8 (-4.0 to +13.6) |
| veteran | 74 | 74.3% | 367 | 69.8% | +4.6 (-6.4 to +15.6) |
| surveyor | 261 | 72.0% | 180 | 68.3% | +3.7 (-5.0 to +12.4) |
| monitor | 64 | 73.4% | 377 | 70.0% | +3.4 (-8.4 to +15.2) |
| clerk | 253 | 69.2% | 188 | 72.3% | -3.2 (-11.7 to +5.4) |
| executor | 63 | 73.0% | 378 | 70.1% | +2.9 (-9.0 to +14.8) |
| warden | 173 | 72.3% | 268 | 69.4% | +2.9 (-5.8 to +11.5) |
| medium | 183 | 72.1% | 258 | 69.4% | +2.8 (-5.8 to +11.3) |
| lamplighter | 176 | 69.3% | 265 | 71.3% | -2.0 (-10.7 to +6.7) |
| seer | 105 | 71.4% | 336 | 70.2% | +1.2 (-8.7 to +11.1) |
| magistrate | 56 | 69.6% | 385 | 70.6% | -1.0 (-13.9 to +11.9) |
| registrar | 152 | 71.1% | 289 | 70.2% | +0.8 (-8.1 to +9.7) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| poisoner | 191 | 68.6% | 250 | 72.0% | -3.4 (-12.0 to +5.2) |
| revenant | 128 | 72.7% | 313 | 69.6% | +3.0 (-6.2 to +12.3) |
| scion | 122 | 71.3% | 319 | 70.2% | +1.1 (-8.4 to +10.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 93 | 67.7% | 348 | 71.3% | -3.5 (-14.1 to +7.1) |
| sleepwalker | 89 | 73.0% | 352 | 69.9% | +3.1 (-7.2 to +13.5) |
| muddler | 88 | 69.3% | 353 | 70.8% | -1.5 (-12.2 to +9.2) |
| marked | 95 | 71.6% | 346 | 70.2% | +1.3 (-8.9 to +11.6) |
| lovers | 76 | 71.1% | 365 | 70.4% | +0.6 (-10.6 to +11.9) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 5 night-walkers | 31 | 77.4% | 410 | 70.0% | +7.4 (-8.0 to +22.8) |
| 4 night-walkers | 153 | 68.0% | 288 | 71.9% | -3.9 (-12.9 to +5.1) |
| 3 night-walkers | 257 | 71.2% | 184 | 69.6% | +1.6 (-7.0 to +10.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 264 | 2.6 | 22.0% | 10.6% | 90.5% |
| surveyor | 261 | 2.8 | 16.9% | 10.3% | 93.5% |
| clerk | 253 | 3.3 | 10.7% | 11.9% | 94.9% |
| archivist | 243 | 1.9 | 53.9% | 8.6% | 96.7% |
| nightwatch | 199 | 2.4 | 25.1% | 13.6% | 87.9% |
| medium | 183 | 2.5 | 22.4% | 7.1% | 78.7% |
| lamplighter | 176 | 2.8 | 16.5% | 14.2% | 89.2% |
| confessor | 175 | 2.6 | 18.9% | 25.7% | 86.3% |
| warden | 173 | 3.0 | 9.8% | 22.0% | 83.8% |
| gravedigger | 158 | 2.4 | 31.6% | 13.9% | 83.5% |
| registrar | 152 | 2.6 | 24.3% | 2.6% | 80.3% |
| dowser | 152 | 2.0 | 54.6% | 5.9% | 90.8% |
| seer | 105 | 2.4 | 38.1% | 5.7% | 84.8% |
| augur | 99 | 2.6 | 22.2% | 5.1% | 82.8% |
| veteran | 74 | 3.7 | 2.7% | 13.5% | 85.1% |
| monitor | 64 | 2.8 | 15.6% | 9.4% | 73.4% |
| psychologist | 63 | 3.1 | 17.5% | 11.1% | 90.5% |
| executor | 63 | 3.0 | 14.3% | 11.1% | 88.9% |
| martyr | 61 | 3.6 | 6.6% | 6.6% | 86.9% |
| chronicler | 57 | 3.0 | 19.3% | 15.8% | 71.9% |
| sexton | 56 | 3.4 | 10.7% | 32.1% | 73.2% |
| magistrate | 56 | 2.8 | 23.2% | 1.8% | 80.4% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 95 | 0.0% | 56.8% |
| dowser | 89 | 0.0% | 68.5% |
| confessor | 86 | 0.0% | 68.6% |
| archivist | 85 | 0.0% | 60.0% |
| gravedigger | 85 | 0.0% | 60.0% |
| clerk | 80 | 0.0% | 65.0% |
| surveyor | 80 | 0.0% | 51.2% |
| rumormonger | 76 | 0.0% | 59.2% |
| lamplighter | 73 | 0.0% | 72.6% |
| medium | 65 | 0.0% | 60.0% |
| magistrate | 58 | 0.0% | 62.1% |
| nightwatch | 56 | 0.0% | 69.6% |
| chronicler | 50 | 0.0% | 44.0% |
| monitor | 50 | 0.0% | 48.0% |
| seer | 50 | 0.0% | 48.0% |
| executor | 49 | 0.0% | 44.9% |
| psychologist | 46 | 0.0% | 43.5% |
| augur | 42 | 0.0% | 57.1% |
| sexton | 17 | 0.0% | 29.4% |
| veteran | 10 | 0.0% | 40.0% |

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
- Shared-model fallbacks: 1 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 253.4 | 561.3 | 1342.3 |

Slowest seeds: 100863 (10 NPCs bot, 1342 s), 100135 (10 NPCs bot, 1260 s), 100137 (10 NPCs bot, 1092 s), 100190 (10 NPCs bot, 976 s), 100632 (10 NPCs bot, 932 s), 100084 (10 NPCs bot, 906 s), 100590 (10 NPCs bot, 872 s), 100217 (10 NPCs bot, 794 s), 100017 (10 NPCs bot, 773 s), 100430 (10 NPCs bot, 757 s), 100572 (10 NPCs bot, 753 s), 100899 (10 NPCs bot, 750 s), 100239 (10 NPCs bot, 743 s), 100001 (10 NPCs bot, 737 s), 100493 (10 NPCs bot, 729 s), 100476 (10 NPCs bot, 712 s), 100041 (10 NPCs bot, 707 s), 100193 (10 NPCs bot, 706 s), 100592 (10 NPCs bot, 687 s), 100065 (10 NPCs bot, 686 s)

