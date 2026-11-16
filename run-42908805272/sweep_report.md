# Balance sweep report

Records: 200 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `ac4582cfb8`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot, no presenting insight 1.0 | 200 | 62.5% (55.6%–68.9%) | 3.10 | 0.58 | 1.17 | 2.26 | 10.0% | 0.21 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot, no presenting insight 1.0 | 5.14 | 17.9% | 28.6% | 2.21 | 12.0% | 11.1% | 10.6% |

### End reasons and solvability

**7 NPCs, bot, no presenting insight 1.0** (n=200)

- The demon's host was executed.: 125 (62.5%)
- Only two townsfolk remain and the demon still walks among them.: 75 (37.5%)
- Demon evidence on the board: 95.5% of games; good win rate 61.3% of 191
- Demon evidence reachable: 80.0% of games; good win rate 56.9% of 160
- Neither: 3.0% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

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
- Shared-model fallbacks: 1 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot, no presenting insight 1.0 | 46.5 | 92.9 | 170.8 |

Slowest seeds: 100185 (7 NPCs no_present, 171 s), 100139 (7 NPCs no_present, 158 s), 100010 (7 NPCs no_present, 148 s), 100023 (7 NPCs no_present, 136 s), 100105 (7 NPCs no_present, 128 s), 100032 (7 NPCs no_present, 119 s), 100002 (7 NPCs no_present, 118 s), 100169 (7 NPCs no_present, 112 s), 100039 (7 NPCs no_present, 106 s), 100050 (7 NPCs no_present, 104 s), 100149 (7 NPCs no_present, 104 s), 100136 (7 NPCs no_present, 103 s), 100058 (7 NPCs no_present, 101 s), 100150 (7 NPCs no_present, 101 s), 100082 (7 NPCs no_present, 100 s), 100062 (7 NPCs no_present, 100 s), 100187 (7 NPCs no_present, 98 s), 100183 (7 NPCs no_present, 98 s), 100120 (7 NPCs no_present, 96 s), 100117 (7 NPCs no_present, 94 s)

