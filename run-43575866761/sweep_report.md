# Balance sweep report

Records: 2000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `9b2ca88709`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0, connections on | 1000 | 63.8% (60.8%–66.7%) | 2.99 | 0.63 | 1.16 | 2.22 | 9.6% | 0.27 |
| 7 NPCs, passive, connections on | 1000 | 41.0% (38.0%–44.1%) | 3.54 | 0.77 | 0.86 | 2.50 | 2.4% | 0.21 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0, connections on | 4.66 | 22.0% | 28.4% | 1.92 | 14.3% | 13.5% | 12.1% |
| 7 NPCs, passive, connections on | 6.34 | 17.1% | 41.0% | 2.94 | 24.1% | 22.9% | 21.2% |

### End reasons and solvability

**7 NPCs, bot insight 1.0, connections on** (n=1000)

- The demon's host was executed.: 638 (63.8%)
- Only two townsfolk remain and the demon still walks among them.: 362 (36.2%)
- Demon evidence on the board: 98.4% of games; good win rate 63.3% of 984
- Demon evidence reachable: 79.8% of games; good win rate 58.1% of 798
- Neither: 1.1% of games; good win rate 100.0% of 11
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive, connections on** (n=1000)

- Only two townsfolk remain and the demon still walks among them.: 588 (58.8%)
- The demon's host was executed.: 410 (41.0%)
- Time ran out: the demon survived 6 days.: 2 (0.2%)
- Demon evidence on the board: 60.7% of games; good win rate 49.8% of 607
- Demon evidence reachable: 99.8% of games; good win rate 40.9% of 998
- Neither: 0.2% of games; good win rate 100.0% of 2
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0, connections on

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| archivist | 548 | 58.9% | 452 | 69.7% | -10.7 (-16.7 to -4.8) **\*** |
| chronicler | 76 | 55.3% | 924 | 64.5% | -9.2 (-20.8 to +2.4) |
| dowser | 286 | 69.9% | 714 | 61.3% | +8.6 (+2.2 to +15.0) **\*** |
| confessor | 224 | 57.1% | 776 | 65.7% | -8.6 (-15.9 to -1.3) **\*** |
| sexton | 74 | 71.6% | 926 | 63.2% | +8.4 (-2.3 to +19.2) |
| surveyor | 508 | 67.9% | 492 | 59.6% | +8.4 (+2.4 to +14.3) **\*** |
| martyr | 88 | 56.8% | 912 | 64.5% | -7.7 (-18.5 to +3.1) |
| monitor | 73 | 57.5% | 927 | 64.3% | -6.8 (-18.5 to +5.0) |
| seer | 170 | 68.2% | 830 | 62.9% | +5.3 (-2.4 to +13.1) |
| veteran | 73 | 68.5% | 927 | 63.4% | +5.1 (-6.0 to +16.2) |
| gravedigger | 283 | 60.4% | 717 | 65.1% | -4.7 (-11.4 to +2.0) |
| magistrate | 73 | 67.1% | 927 | 63.5% | +3.6 (-7.6 to +14.8) |
| nightwatch | 238 | 66.4% | 762 | 63.0% | +3.4 (-3.5 to +10.3) |
| warden | 229 | 65.9% | 771 | 63.2% | +2.8 (-4.2 to +9.8) |
| augur | 193 | 61.7% | 807 | 64.3% | -2.7 (-10.3 to +5.0) |
| executor | 87 | 65.5% | 913 | 63.6% | +1.9 (-8.6 to +12.3) |
| medium | 188 | 64.9% | 812 | 63.5% | +1.3 (-6.2 to +8.9) |
| rumormonger | 504 | 63.3% | 496 | 64.3% | -1.0 (-7.0 to +4.9) |
| lamplighter | 203 | 64.5% | 797 | 63.6% | +0.9 (-6.5 to +8.3) |
| psychologist | 67 | 64.2% | 933 | 63.8% | +0.4 (-11.5 to +12.3) |
| registrar | 270 | 64.1% | 730 | 63.7% | +0.4 (-6.3 to +7.1) |
| clerk | 545 | 63.9% | 455 | 63.7% | +0.1 (-5.9 to +6.1) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 77.2% | 781 | 60.1% | +17.1 (+10.6 to +23.7) **\*** |
| revenant | 221 | 56.6% | 779 | 65.9% | -9.3 (-16.6 to -2.0) **\*** |
| poisoner | 325 | 60.6% | 675 | 65.3% | -4.7 (-11.1 to +1.7) |
| scion | 235 | 62.6% | 765 | 64.2% | -1.6 (-8.7 to +5.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 54.7% | 788 | 66.2% | -11.5 (-19.0 to -4.1) **\*** |
| lovers | 208 | 72.1% | 792 | 61.6% | +10.5 (+3.5 to +17.5) **\*** |
| marked | 195 | 65.6% | 805 | 63.4% | +2.3 (-5.2 to +9.7) |
| muddler | 199 | 63.3% | 801 | 63.9% | -0.6 (-8.1 to +6.9) |
| sleepwalker | 186 | 63.4% | 814 | 63.9% | -0.4 (-8.1 to +7.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 55.8% | 957 | 64.2% | -8.3 (-23.5 to +6.8) |
| 2 night-walkers | 636 | 64.9% | 364 | 61.8% | +3.1 (-3.1 to +9.3) |
| 3 night-walkers | 321 | 62.6% | 679 | 64.4% | -1.7 (-8.1 to +4.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.5 | 52.0% | 15.7% | 94.0% |
| clerk | 545 | 2.2 | 21.1% | 10.8% | 91.4% |
| surveyor | 508 | 2.1 | 24.2% | 12.2% | 91.5% |
| rumormonger | 504 | 2.1 | 23.4% | 12.1% | 90.7% |
| dowser | 286 | 1.7 | 48.3% | 6.3% | 87.1% |
| gravedigger | 283 | 2.0 | 40.3% | 11.3% | 83.7% |
| registrar | 270 | 2.1 | 38.1% | 5.6% | 79.6% |
| nightwatch | 238 | 1.9 | 31.9% | 19.3% | 84.0% |
| warden | 229 | 2.2 | 21.8% | 18.3% | 76.9% |
| confessor | 224 | 1.9 | 25.9% | 23.2% | 84.4% |
| lamplighter | 203 | 2.0 | 24.6% | 14.8% | 88.2% |
| augur | 193 | 2.2 | 33.7% | 9.8% | 80.3% |
| medium | 188 | 2.1 | 26.1% | 11.7% | 78.7% |
| seer | 170 | 1.9 | 42.4% | 8.8% | 83.5% |
| martyr | 88 | 2.4 | 14.8% | 6.8% | 81.8% |
| executor | 87 | 2.2 | 20.7% | 5.7% | 79.3% |
| chronicler | 76 | 2.1 | 26.3% | 15.8% | 75.0% |
| sexton | 74 | 2.4 | 9.5% | 14.9% | 71.6% |
| magistrate | 73 | 2.1 | 38.4% | 2.7% | 75.3% |
| veteran | 73 | 2.9 | 2.7% | 13.7% | 90.4% |
| monitor | 73 | 2.1 | 31.5% | 12.3% | 78.1% |
| psychologist | 67 | 2.3 | 29.9% | 13.4% | 89.6% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 146 | 0.0% | 50.7% |
| nightwatch | 141 | 0.0% | 61.7% |
| dowser | 137 | 0.0% | 63.5% |
| confessor | 135 | 0.0% | 71.1% |
| medium | 128 | 0.0% | 57.0% |
| lamplighter | 126 | 0.0% | 77.0% |
| gravedigger | 116 | 0.0% | 54.3% |
| surveyor | 112 | 0.0% | 63.4% |
| rumormonger | 108 | 0.0% | 63.0% |
| clerk | 104 | 0.0% | 57.7% |
| archivist | 100 | 0.0% | 71.0% |
| psychologist | 79 | 0.0% | 62.0% |
| chronicler | 79 | 0.0% | 59.5% |
| magistrate | 79 | 0.0% | 57.0% |
| seer | 77 | 0.0% | 48.1% |
| executor | 74 | 0.0% | 44.6% |
| augur | 73 | 0.0% | 57.5% |
| monitor | 65 | 0.0% | 35.4% |
| martyr | 18 | 0.0% | 33.3% |
| warden | 17 | 0.0% | 70.6% |
| veteran | 16 | 0.0% | 25.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 77.2% | 781 | 60.1% | +17.1 (+10.6 to +23.7) |
| archivist + clerk | 225 | 55.1% | 775 | 66.3% | -11.2 (-18.5 to -3.9) |
| archivist + demon | 548 | 58.9% | 452 | 69.7% | -10.7 (-16.7 to -4.8) |

### 7 NPCs, passive, connections on

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| sexton | 74 | 25.7% | 926 | 42.2% | -16.5 (-27.0 to -6.1) **\*** |
| nightwatch | 238 | 49.2% | 762 | 38.5% | +10.7 (+3.5 to +17.9) **\*** |
| martyr | 88 | 31.8% | 912 | 41.9% | -10.1 (-20.3 to +0.2) |
| medium | 188 | 33.5% | 812 | 42.7% | -9.2 (-16.8 to -1.7) **\*** |
| warden | 229 | 48.0% | 771 | 38.9% | +9.1 (+1.8 to +16.5) **\*** |
| magistrate | 73 | 49.3% | 927 | 40.3% | +9.0 (-2.9 to +20.9) |
| augur | 193 | 34.7% | 807 | 42.5% | -7.8 (-15.3 to -0.3) **\*** |
| psychologist | 67 | 34.3% | 933 | 41.5% | -7.2 (-19.0 to +4.6) |
| dowser | 286 | 45.5% | 714 | 39.2% | +6.2 (-0.6 to +13.0) |
| chronicler | 76 | 35.5% | 924 | 41.5% | -5.9 (-17.1 to +5.3) |
| executor | 87 | 35.6% | 913 | 41.5% | -5.9 (-16.4 to +4.7) |
| gravedigger | 283 | 37.1% | 717 | 42.5% | -5.4 (-12.1 to +1.3) |
| monitor | 73 | 45.2% | 927 | 40.7% | +4.5 (-7.3 to +16.4) |
| archivist | 548 | 39.1% | 452 | 43.4% | -4.3 (-10.4 to +1.8) |
| registrar | 270 | 43.7% | 730 | 40.0% | +3.7 (-3.2 to +10.6) |
| seer | 170 | 38.2% | 830 | 41.6% | -3.3 (-11.4 to +4.7) |
| surveyor | 508 | 42.5% | 492 | 39.4% | +3.1 (-3.0 to +9.2) |
| veteran | 73 | 43.8% | 927 | 40.8% | +3.1 (-8.8 to +14.9) |
| confessor | 224 | 43.3% | 776 | 40.3% | +3.0 (-4.4 to +10.3) |
| lamplighter | 203 | 42.4% | 797 | 40.7% | +1.7 (-5.9 to +9.3) |
| clerk | 545 | 41.3% | 455 | 40.7% | +0.6 (-5.5 to +6.7) |
| rumormonger | 504 | 41.3% | 496 | 40.7% | +0.5 (-5.6 to +6.6) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 219 | 63.5% | 781 | 34.7% | +28.8 (+21.6 to +36.0) **\*** |
| poisoner | 325 | 31.7% | 675 | 45.5% | -13.8 (-20.1 to -7.5) **\*** |
| revenant | 221 | 32.6% | 779 | 43.4% | -10.8 (-17.9 to -3.7) **\*** |
| scion | 235 | 40.9% | 765 | 41.0% | -0.2 (-7.4 to +7.0) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 212 | 33.5% | 788 | 43.0% | -9.5 (-16.8 to -2.3) **\*** |
| muddler | 199 | 48.2% | 801 | 39.2% | +9.0 (+1.3 to +16.8) **\*** |
| marked | 195 | 33.8% | 805 | 42.7% | -8.9 (-16.4 to -1.4) **\*** |
| sleepwalker | 186 | 45.2% | 814 | 40.0% | +5.1 (-2.8 to +13.0) |
| lovers | 208 | 44.7% | 792 | 40.0% | +4.7 (-2.9 to +12.3) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 43 | 46.5% | 957 | 40.8% | +5.8 (-9.5 to +21.0) |
| 3 night-walkers | 321 | 39.3% | 679 | 41.8% | -2.6 (-9.1 to +3.9) |
| 2 night-walkers | 636 | 41.5% | 364 | 40.1% | +1.4 (-4.9 to +7.7) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 548 | 1.7 | 60.8% | 16.1% | 93.4% |
| clerk | 545 | 2.7 | 22.8% | 19.6% | 93.2% |
| surveyor | 508 | 2.5 | 25.6% | 21.5% | 91.5% |
| rumormonger | 504 | 2.7 | 21.8% | 18.7% | 95.6% |
| dowser | 286 | 1.9 | 57.3% | 9.4% | 90.9% |
| gravedigger | 283 | 2.2 | 40.6% | 15.2% | 90.5% |
| registrar | 270 | 2.2 | 42.6% | 4.1% | 84.8% |
| nightwatch | 238 | 2.2 | 40.8% | 9.2% | 87.4% |
| warden | 229 | 2.6 | 25.3% | 10.9% | 81.7% |
| confessor | 224 | 2.3 | 37.9% | 12.9% | 84.4% |
| lamplighter | 203 | 2.4 | 29.1% | 7.9% | 90.1% |
| augur | 193 | 2.6 | 29.5% | 16.6% | 88.1% |
| medium | 188 | 2.4 | 33.5% | 19.1% | 83.5% |
| seer | 170 | 2.0 | 51.8% | 14.7% | 84.1% |
| martyr | 88 | 2.5 | 22.7% | 18.2% | 83.0% |
| executor | 87 | 2.6 | 32.2% | 8.0% | 86.2% |
| chronicler | 76 | 2.5 | 26.3% | 26.3% | 81.6% |
| sexton | 74 | 2.8 | 23.0% | 28.4% | 70.3% |
| magistrate | 73 | 2.4 | 32.9% | 9.6% | 90.4% |
| monitor | 73 | 2.4 | 31.5% | 5.5% | 86.3% |
| veteran | 73 | 3.3 | 8.2% | 26.0% | 87.7% |
| psychologist | 67 | 2.4 | 34.3% | 13.4% | 82.1% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 145 | 0.0% | 37.2% |
| nightwatch | 142 | 0.0% | 26.1% |
| dowser | 139 | 0.0% | 51.8% |
| confessor | 136 | 0.0% | 46.3% |
| medium | 129 | 0.0% | 45.7% |
| lamplighter | 128 | 0.0% | 43.0% |
| gravedigger | 121 | 0.0% | 52.1% |
| surveyor | 112 | 0.0% | 52.7% |
| rumormonger | 109 | 0.0% | 44.0% |
| clerk | 105 | 0.0% | 52.4% |
| archivist | 101 | 0.0% | 56.4% |
| magistrate | 80 | 0.0% | 42.5% |
| psychologist | 79 | 0.0% | 49.4% |
| chronicler | 78 | 0.0% | 53.8% |
| executor | 76 | 0.0% | 34.2% |
| seer | 75 | 0.0% | 36.0% |
| augur | 74 | 0.0% | 45.9% |
| monitor | 66 | 0.0% | 19.7% |
| warden | 19 | 0.0% | 31.6% |
| martyr | 18 | 0.0% | 50.0% |
| veteran | 14 | 0.0% | 21.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 219 | 63.5% | 781 | 34.7% | +28.8 (+21.6 to +36.0) |
| demon + poisoner | 325 | 31.7% | 675 | 45.5% | -13.8 (-20.1 to -7.5) |
| demon + revenant | 221 | 32.6% | 779 | 43.4% | -10.8 (-17.9 to -3.7) |
| demon + nightwatch | 238 | 49.2% | 762 | 38.5% | +10.7 (+3.5 to +17.9) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 0
- Shared-model fallbacks: 5 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0, connections on | 63.3 | 128.4 | 381.2 |
| 7 NPCs, passive, connections on | 12.9 | 21.3 | 53.0 |

Slowest seeds: 100615 (7 NPCs bot_connections, 381 s), 100419 (7 NPCs bot_connections, 362 s), 100590 (7 NPCs bot_connections, 298 s), 100006 (7 NPCs bot_connections, 286 s), 100523 (7 NPCs bot_connections, 273 s), 100015 (7 NPCs bot_connections, 263 s), 100906 (7 NPCs bot_connections, 252 s), 100729 (7 NPCs bot_connections, 244 s), 100555 (7 NPCs bot_connections, 237 s), 100058 (7 NPCs bot_connections, 209 s), 100400 (7 NPCs bot_connections, 208 s), 100104 (7 NPCs bot_connections, 203 s), 100795 (7 NPCs bot_connections, 202 s), 100076 (7 NPCs bot_connections, 200 s), 100546 (7 NPCs bot_connections, 199 s), 100146 (7 NPCs bot_connections, 198 s), 100084 (7 NPCs bot_connections, 195 s), 100441 (7 NPCs bot_connections, 193 s), 100797 (7 NPCs bot_connections, 190 s), 100703 (7 NPCs bot_connections, 187 s)

