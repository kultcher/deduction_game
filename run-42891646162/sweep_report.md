# Balance sweep report

Records: 200 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `432bf7b18e`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 100 | 56.0% (46.2%–65.3%) | 4.41 | 1.04 | 1.76 | 2.66 | 5.0% | 0.51 |
| 10 NPCs, bot, no presenting insight 1.0 | 100 | 53.0% (43.3%–62.5%) | 4.35 | 1.16 | 1.54 | 2.67 | 5.0% | 0.49 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 9.70 | 14.2% | 25.4% | 3.94 | 10.7% | 9.2% | 9.2% |
| 10 NPCs, bot, no presenting insight 1.0 | 9.28 | 12.8% | 21.9% | 4.77 | 27.7% | 26.5% | 19.1% |

### End reasons and solvability

**10 NPCs, bot insight 1.0** (n=100)

- The demon's host was executed.: 56 (56.0%)
- Only two townsfolk remain and the demon still walks among them.: 33 (33.0%)
- No good soul remains.: 11 (11.0%)
- Demon evidence on the board: 100.0% of games; good win rate 56.0% of 100
- Demon evidence reachable: 92.0% of games; good win rate 54.3% of 92
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

**10 NPCs, bot, no presenting insight 1.0** (n=100)

- The demon's host was executed.: 53 (53.0%)
- Only two townsfolk remain and the demon still walks among them.: 29 (29.0%)
- No good soul remains.: 18 (18.0%)
- Demon evidence on the board: 100.0% of games; good win rate 53.0% of 100
- Demon evidence reachable: 90.0% of games; good win rate 50.0% of 90
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 10 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 36 | 41.7% | 64 | 64.1% | -22.4 (-42.3 to -2.5) **\*** |
| confessor | 40 | 65.0% | 60 | 50.0% | +15.0 (-4.5 to +34.5) |
| clerk | 54 | 50.0% | 46 | 63.0% | -13.0 (-32.3 to +6.3) |
| archivist | 52 | 61.5% | 48 | 50.0% | +11.5 (-7.8 to +30.9) |
| dowser | 35 | 51.4% | 65 | 58.5% | -7.0 (-27.5 to +13.4) |
| nightwatch | 40 | 52.5% | 60 | 58.3% | -5.8 (-25.7 to +14.0) |
| registrar | 45 | 53.3% | 55 | 58.2% | -4.8 (-24.4 to +14.7) |
| gravedigger | 43 | 53.5% | 57 | 57.9% | -4.4 (-24.1 to +15.3) |
| rumormonger | 64 | 54.7% | 36 | 58.3% | -3.6 (-23.8 to +16.6) |
| warden | 40 | 57.5% | 60 | 55.0% | +2.5 (-17.3 to +22.3) |
| medium | 35 | 57.1% | 65 | 55.4% | +1.8 (-18.6 to +22.1) |
| surveyor | 55 | 56.4% | 45 | 55.6% | +0.8 (-18.8 to +20.4) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 42 | 81.0% | 58 | 37.9% | +43.0 (+25.8 to +60.3) **\*** |
| scion | 49 | 44.9% | 51 | 66.7% | -21.8 (-40.8 to -2.8) **\*** |
| revenant | 49 | 49.0% | 51 | 62.7% | -13.8 (-33.1 to +5.5) |
| poisoner | 60 | 53.3% | 40 | 60.0% | -6.7 (-26.4 to +13.1) |

_One demon type in every game: no demon comparison._

**Secrets**

_Not enough games._

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 58 | 60.3% | 42 | 50.0% | +10.3 (-9.3 to +30.0) |
| 4 night-walkers | 33 | 51.5% | 67 | 58.2% | -6.7 (-27.4 to +14.0) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 64 | 3.2 | 17.2% | 14.1% | 93.8% |
| surveyor | 55 | 2.7 | 21.8% | 18.2% | 92.7% |
| clerk | 54 | 3.2 | 16.7% | 14.8% | 92.6% |
| archivist | 52 | 2.0 | 50.0% | 3.8% | 94.2% |
| registrar | 45 | 3.0 | 13.3% | 8.9% | 91.1% |
| gravedigger | 43 | 2.7 | 27.9% | 14.0% | 79.1% |
| nightwatch | 40 | 2.2 | 40.0% | 25.0% | 92.5% |
| warden | 40 | 3.3 | 15.0% | 20.0% | 90.0% |
| confessor | 40 | 2.7 | 20.0% | 30.0% | 90.0% |
| lamplighter | 36 | 3.2 | 11.1% | 13.9% | 94.4% |
| medium | 35 | 2.9 | 31.4% | 8.6% | 80.0% |
| dowser | 35 | 2.2 | 51.4% | 14.3% | 94.3% |
| seer | 24 | 2.6 | 29.2% | 20.8% | 95.8% |
| chronicler | 21 | 3.3 | 14.3% | 4.8% | 90.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 26 | 0.0% | 76.9% |
| archivist | 24 | 0.0% | 54.2% |
| surveyor | 22 | 0.0% | 54.5% |
| confessor | 21 | 0.0% | 76.2% |
| clerk | 18 | 0.0% | 44.4% |
| magistrate | 17 | 0.0% | 70.6% |
| medium | 17 | 0.0% | 23.5% |
| nightwatch | 17 | 0.0% | 82.4% |
| rumormonger | 17 | 0.0% | 47.1% |
| gravedigger | 17 | 0.0% | 64.7% |
| lamplighter | 16 | 0.0% | 43.8% |
| registrar | 15 | 0.0% | 46.7% |
| augur | 11 | 0.0% | 63.6% |
| psychologist | 11 | 0.0% | 72.7% |
| monitor | 10 | 0.0% | 40.0% |
| chronicler | 10 | 0.0% | 60.0% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

_None._

### 10 NPCs, bot, no presenting insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| lamplighter | 36 | 41.7% | 64 | 59.4% | -17.7 (-37.8 to +2.4) |
| rumormonger | 64 | 48.4% | 36 | 61.1% | -12.7 (-32.8 to +7.4) |
| nightwatch | 40 | 57.5% | 60 | 50.0% | +7.5 (-12.4 to +27.4) |
| confessor | 40 | 57.5% | 60 | 50.0% | +7.5 (-12.4 to +27.4) |
| dowser | 35 | 48.6% | 65 | 55.4% | -6.8 (-27.3 to +13.7) |
| gravedigger | 43 | 55.8% | 57 | 50.9% | +4.9 (-14.8 to +24.7) |
| surveyor | 55 | 54.5% | 45 | 51.1% | +3.4 (-16.2 to +23.1) |
| registrar | 45 | 51.1% | 55 | 54.5% | -3.4 (-23.1 to +16.2) |
| warden | 40 | 55.0% | 60 | 51.7% | +3.3 (-16.6 to +23.3) |
| medium | 35 | 51.4% | 65 | 53.8% | -2.4 (-22.9 to +18.1) |
| archivist | 52 | 53.8% | 48 | 52.1% | +1.8 (-17.8 to +21.3) |
| clerk | 54 | 53.7% | 46 | 52.2% | +1.5 (-18.1 to +21.2) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 42 | 69.0% | 58 | 41.4% | +27.7 (+8.8 to +46.5) **\*** |
| scion | 49 | 42.9% | 51 | 62.7% | -19.9 (-39.1 to -0.7) **\*** |
| poisoner | 60 | 50.0% | 40 | 57.5% | -7.5 (-27.4 to +12.4) |
| revenant | 49 | 53.1% | 51 | 52.9% | +0.1 (-19.4 to +19.7) |

_One demon type in every game: no demon comparison._

**Secrets**

_Not enough games._

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 58 | 55.2% | 42 | 50.0% | +5.2 (-14.6 to +25.0) |
| 4 night-walkers | 33 | 51.5% | 67 | 53.7% | -2.2 (-23.0 to +18.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 64 | 3.5 | 12.5% | 17.2% | 92.2% |
| surveyor | 55 | 2.9 | 18.2% | 20.0% | 92.7% |
| clerk | 54 | 3.3 | 13.0% | 20.4% | 90.7% |
| archivist | 52 | 2.0 | 53.8% | 13.5% | 98.1% |
| registrar | 45 | 2.4 | 26.7% | 8.9% | 86.7% |
| gravedigger | 43 | 2.9 | 20.9% | 16.3% | 93.0% |
| confessor | 40 | 3.0 | 17.5% | 22.5% | 90.0% |
| nightwatch | 40 | 2.3 | 40.0% | 20.0% | 92.5% |
| warden | 40 | 3.4 | 12.5% | 15.0% | 90.0% |
| lamplighter | 36 | 3.0 | 19.4% | 11.1% | 83.3% |
| medium | 35 | 3.2 | 17.1% | 20.0% | 82.9% |
| dowser | 35 | 2.0 | 57.1% | 8.6% | 94.3% |
| seer | 24 | 2.2 | 33.3% | 16.7% | 100.0% |
| chronicler | 21 | 3.5 | 9.5% | 14.3% | 90.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| archivist | 24 | 0.0% | 50.0% |
| dowser | 23 | 0.0% | 82.6% |
| surveyor | 23 | 0.0% | 43.5% |
| confessor | 21 | 0.0% | 57.1% |
| clerk | 18 | 0.0% | 55.6% |
| gravedigger | 17 | 0.0% | 76.5% |
| magistrate | 17 | 0.0% | 47.1% |
| medium | 17 | 0.0% | 29.4% |
| rumormonger | 17 | 0.0% | 41.2% |
| registrar | 16 | 0.0% | 37.5% |
| nightwatch | 16 | 0.0% | 56.2% |
| lamplighter | 16 | 0.0% | 37.5% |
| psychologist | 11 | 0.0% | 63.6% |
| augur | 11 | 0.0% | 54.5% |
| monitor | 10 | 0.0% | 30.0% |

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
- Shared-model fallbacks: 0 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 10 NPCs, bot insight 1.0 | 300.4 | 525.0 | 881.8 |
| 10 NPCs, bot, no presenting insight 1.0 | 294.2 | 515.7 | 764.8 |

Slowest seeds: 100004 (10 NPCs bot, 882 s), 100041 (10 NPCs no_present, 765 s), 100088 (10 NPCs bot, 709 s), 100046 (10 NPCs no_present, 693 s), 100098 (10 NPCs no_present, 685 s), 100046 (10 NPCs bot, 670 s), 100044 (10 NPCs no_present, 662 s), 100003 (10 NPCs bot, 637 s), 100032 (10 NPCs bot, 636 s), 100006 (10 NPCs bot, 614 s), 100030 (10 NPCs no_present, 607 s), 100002 (10 NPCs no_present, 596 s), 100062 (10 NPCs no_present, 575 s), 100088 (10 NPCs no_present, 559 s), 100086 (10 NPCs bot, 552 s), 100007 (10 NPCs no_present, 551 s), 100051 (10 NPCs bot, 542 s), 100032 (10 NPCs no_present, 537 s), 100022 (10 NPCs bot, 535 s), 100037 (10 NPCs bot, 527 s)

