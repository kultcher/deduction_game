# Balance sweep report

Records: 100 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `ac4582cfb8`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 10 NPCs, bot, no presenting insight 1.0 | 100 | 56.0% (46.2%–65.3%) | 4.26 | 1.13 | 1.65 | 2.68 | 5.0% | 0.50 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 10 NPCs, bot, no presenting insight 1.0 | 9.48 | 13.5% | 23.2% | 4.15 | 17.1% | 17.0% | 15.3% |

### End reasons and solvability

**10 NPCs, bot, no presenting insight 1.0** (n=100)

- The demon's host was executed.: 56 (56.0%)
- Only two townsfolk remain and the demon still walks among them.: 27 (27.0%)
- No good soul remains.: 17 (17.0%)
- Demon evidence on the board: 100.0% of games; good win rate 56.0% of 100
- Demon evidence reachable: 88.0% of games; good win rate 55.7% of 88
- Neither: 0.0% of games; good win rate –
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 10 NPCs, bot, no presenting insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| archivist | 52 | 69.2% | 48 | 41.7% | +27.6 (+8.8 to +46.3) **\*** |
| lamplighter | 36 | 47.2% | 64 | 60.9% | -13.7 (-33.9 to +6.5) |
| clerk | 54 | 50.0% | 46 | 63.0% | -13.0 (-32.3 to +6.3) |
| confessor | 40 | 62.5% | 60 | 51.7% | +10.8 (-8.8 to +30.5) |
| warden | 40 | 50.0% | 60 | 60.0% | -10.0 (-29.8 to +9.8) |
| nightwatch | 40 | 50.0% | 60 | 60.0% | -10.0 (-29.8 to +9.8) |
| surveyor | 55 | 52.7% | 45 | 60.0% | -7.3 (-26.7 to +12.2) |
| medium | 35 | 60.0% | 65 | 53.8% | +6.2 (-14.1 to +26.4) |
| registrar | 45 | 57.8% | 55 | 54.5% | +3.2 (-16.3 to +22.8) |
| dowser | 35 | 54.3% | 65 | 56.9% | -2.6 (-23.1 to +17.8) |
| rumormonger | 64 | 56.2% | 36 | 55.6% | +0.7 (-19.6 to +21.0) |
| gravedigger | 43 | 55.8% | 57 | 56.1% | -0.3 (-20.0 to +19.3) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 42 | 71.4% | 58 | 44.8% | +26.6 (+7.9 to +45.3) **\*** |
| scion | 49 | 46.9% | 51 | 64.7% | -17.8 (-36.9 to +1.4) |
| revenant | 49 | 53.1% | 51 | 58.8% | -5.8 (-25.2 to +13.7) |
| poisoner | 60 | 55.0% | 40 | 57.5% | -2.5 (-22.3 to +17.3) |

_One demon type in every game: no demon comparison._

**Secrets**

_Not enough games._

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 3 night-walkers | 58 | 60.3% | 42 | 50.0% | +10.3 (-9.3 to +30.0) |
| 4 night-walkers | 33 | 54.5% | 67 | 56.7% | -2.2 (-22.9 to +18.6) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| rumormonger | 64 | 3.0 | 15.6% | 10.9% | 92.2% |
| surveyor | 55 | 2.8 | 18.2% | 18.2% | 92.7% |
| clerk | 54 | 3.2 | 16.7% | 20.4% | 94.4% |
| archivist | 52 | 2.1 | 50.0% | 9.6% | 96.2% |
| registrar | 45 | 2.8 | 22.2% | 11.1% | 86.7% |
| gravedigger | 43 | 2.8 | 25.6% | 23.3% | 88.4% |
| confessor | 40 | 2.9 | 20.0% | 25.0% | 90.0% |
| nightwatch | 40 | 2.1 | 40.0% | 25.0% | 92.5% |
| warden | 40 | 3.4 | 12.5% | 27.5% | 92.5% |
| lamplighter | 36 | 2.8 | 22.2% | 11.1% | 86.1% |
| medium | 35 | 2.8 | 20.0% | 5.7% | 82.9% |
| dowser | 35 | 1.8 | 57.1% | 11.4% | 97.1% |
| seer | 24 | 2.3 | 37.5% | 16.7% | 95.8% |
| chronicler | 21 | 3.1 | 14.3% | 9.5% | 76.2% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| dowser | 25 | 0.0% | 76.0% |
| archivist | 24 | 0.0% | 50.0% |
| surveyor | 23 | 0.0% | 56.5% |
| confessor | 21 | 0.0% | 66.7% |
| clerk | 18 | 0.0% | 50.0% |
| gravedigger | 17 | 0.0% | 70.6% |
| magistrate | 17 | 0.0% | 52.9% |
| medium | 17 | 0.0% | 17.6% |
| rumormonger | 17 | 0.0% | 23.5% |
| registrar | 16 | 0.0% | 62.5% |
| nightwatch | 16 | 0.0% | 75.0% |
| lamplighter | 16 | 0.0% | 50.0% |
| psychologist | 11 | 0.0% | 63.6% |
| augur | 11 | 0.0% | 63.6% |
| chronicler | 10 | 0.0% | 40.0% |
| executor | 10 | 0.0% | 40.0% |
| monitor | 10 | 0.0% | 50.0% |

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
| 10 NPCs, bot, no presenting insight 1.0 | 273.3 | 425.0 | 721.3 |

Slowest seeds: 100088 (10 NPCs no_present, 721 s), 100089 (10 NPCs no_present, 683 s), 100041 (10 NPCs no_present, 627 s), 100013 (10 NPCs no_present, 597 s), 100032 (10 NPCs no_present, 594 s), 100007 (10 NPCs no_present, 500 s), 100046 (10 NPCs no_present, 499 s), 100006 (10 NPCs no_present, 491 s), 100039 (10 NPCs no_present, 484 s), 100054 (10 NPCs no_present, 433 s), 100019 (10 NPCs no_present, 425 s), 100082 (10 NPCs no_present, 420 s), 100086 (10 NPCs no_present, 419 s), 100044 (10 NPCs no_present, 414 s), 100061 (10 NPCs no_present, 404 s), 100052 (10 NPCs no_present, 392 s), 100058 (10 NPCs no_present, 391 s), 100008 (10 NPCs no_present, 389 s), 100002 (10 NPCs no_present, 385 s), 100009 (10 NPCs no_present, 380 s)

