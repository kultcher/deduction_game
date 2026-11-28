# Balance sweep report

Records: 4000 games, 0 failed, 0 stuck (left out of the rates). Commit(s): `eef7b69e86`.

## Win rate by cell

| Cell | n | Good wins (95% CI) | Avg days | Wrongful exec/game | Evil exec/game | First evil exec (day) | Evil exec on day 1 | Good walkers hanged/game |
|---|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 2000 | 66.0% (63.8%–68.0%) | 3.11 | 0.52 | 1.25 | 2.33 | 9.2% | 0.12 |
| 7 NPCs, passive | 2000 | 38.6% (36.4%–40.7%) | 3.60 | 0.77 | 0.84 | 2.50 | 3.8% | 0.11 |

### Vote shape

Unanimous: every NPC voter but the nominee voted yes. Evil nominations: by someone evil at case start; carried = put on the block.

| Cell | Votes/game | Unanimous | Only the nominator | Evil noms/game | Evil noms carried | Evil noms on good targets carried | ...hanged |
|---|---|---|---|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 5.24 | 17.1% | 28.7% | 2.10 | 11.7% | 11.3% | 10.5% |
| 7 NPCs, passive | 6.67 | 15.1% | 43.4% | 3.00 | 23.3% | 22.2% | 20.9% |

### End reasons and solvability

**7 NPCs, bot insight 1.0** (n=2000)

- The Demon's host was executed.: 1319 (66.0%)
- Only two townsfolk remain and the Demon still walks among them.: 681 (34.1%)
- Demon evidence on the board: 98.1% of games; good win rate 65.4% of 1962
- Demon evidence reachable: 69.6% of games; good win rate 60.5% of 1392
- Neither: 1.4% of games; good win rate 100.0% of 27
- Deal fallback (guarantees or night-walker band not met): 0 games

**7 NPCs, passive** (n=2000)

- Only two townsfolk remain and the Demon still walks among them.: 1228 (61.4%)
- The Demon's host was executed.: 771 (38.6%)
- Time ran out: the Demon survived 6 days.: 1 (0.1%)
- Demon evidence on the board: 61.8% of games; good win rate 45.4% of 1235
- Demon evidence reachable: 99.6% of games; good win rate 38.3% of 1992
- Neither: 0.3% of games; good win rate 100.0% of 6
- Deal fallback (guarantees or night-walker band not met): 0 games

## Role effects

Good win rate with and without each feature dealt, per cell. Sorted by absolute difference; **\*** marks a 95% interval that excludes zero. Features dealt in fewer than 30 games (or missing from fewer than 30) are left out. These are associations, not causes: roles travel with the deal rules.

### 7 NPCs, bot insight 1.0

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 464 | 74.4% | 1536 | 63.4% | +10.9 (+6.3 to +15.6) **\*** |
| sexton | 155 | 59.4% | 1845 | 66.5% | -7.1 (-15.2 to +0.9) |
| archivist | 1099 | 63.5% | 901 | 68.9% | -5.4 (-9.6 to -1.3) **\*** |
| executor | 149 | 61.1% | 1851 | 66.3% | -5.3 (-13.4 to +2.9) |
| martyr | 161 | 61.5% | 1839 | 66.3% | -4.8 (-12.7 to +3.0) |
| chronicler | 135 | 61.5% | 1865 | 66.3% | -4.8 (-13.3 to +3.7) |
| medium | 377 | 62.3% | 1623 | 66.8% | -4.5 (-9.9 to +0.9) |
| monitor | 152 | 61.8% | 1848 | 66.3% | -4.4 (-12.5 to +3.6) |
| dowser | 591 | 69.0% | 1409 | 64.7% | +4.4 (-0.1 to +8.9) |
| warden | 476 | 69.1% | 1524 | 65.0% | +4.2 (-0.6 to +8.9) |
| magistrate | 138 | 69.6% | 1862 | 65.7% | +3.9 (-4.1 to +11.9) |
| confessor | 433 | 63.0% | 1567 | 66.8% | -3.7 (-8.8 to +1.4) |
| veteran | 147 | 62.6% | 1853 | 66.2% | -3.6 (-11.7 to +4.5) |
| gravedigger | 583 | 63.5% | 1417 | 67.0% | -3.5 (-8.1 to +1.1) |
| psychologist | 126 | 69.0% | 1874 | 65.7% | +3.3 (-5.0 to +11.7) |
| surveyor | 1003 | 67.5% | 997 | 64.4% | +3.1 (-1.0 to +7.3) |
| clerk | 1076 | 67.3% | 924 | 64.4% | +2.9 (-1.3 to +7.1) |
| rumormonger | 1069 | 64.8% | 931 | 67.2% | -2.4 (-6.6 to +1.7) |
| lamplighter | 419 | 66.8% | 1581 | 65.7% | +1.1 (-4.0 to +6.2) |
| augur | 357 | 66.7% | 1643 | 65.8% | +0.9 (-4.5 to +6.3) |
| registrar | 539 | 66.4% | 1461 | 65.8% | +0.6 (-4.0 to +5.3) |
| seer | 351 | 66.4% | 1649 | 65.9% | +0.5 (-4.9 to +6.0) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 82.6% | 1540 | 61.0% | +21.6 (+17.4 to +25.9) **\*** |
| poisoner | 658 | 57.3% | 1342 | 70.2% | -12.9 (-17.4 to -8.4) **\*** |
| revenant | 447 | 61.3% | 1553 | 67.3% | -6.0 (-11.1 to -0.9) **\*** |
| scion | 435 | 66.2% | 1565 | 65.9% | +0.3 (-4.7 to +5.4) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 519 | 57.2% | 1481 | 69.0% | -11.8 (-16.6 to -6.9) **\*** |
| unrequited | 475 | 70.7% | 1525 | 64.5% | +6.3 (+1.5 to +11.0) **\*** |
| ill_omened | 522 | 68.6% | 1478 | 65.0% | +3.6 (-1.1 to +8.2) |
| marked | 484 | 67.8% | 1516 | 65.4% | +2.4 (-2.4 to +7.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 57.7% | 1903 | 66.4% | -8.6 (-18.7 to +1.4) |
| 2 night-walkers | 1270 | 67.3% | 730 | 63.6% | +3.8 (-0.6 to +8.1) |
| 3 night-walkers | 633 | 64.5% | 1367 | 66.6% | -2.2 (-6.7 to +2.3) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 1.9 | 31.8% | 15.6% | 94.3% |
| clerk | 1076 | 2.4 | 15.3% | 8.9% | 94.2% |
| rumormonger | 1069 | 2.3 | 18.7% | 11.7% | 94.5% |
| surveyor | 1003 | 2.3 | 18.5% | 12.8% | 94.6% |
| dowser | 591 | 1.6 | 61.9% | 4.4% | 84.6% |
| gravedigger | 583 | 1.8 | 49.1% | 8.6% | 82.5% |
| registrar | 539 | 1.9 | 46.0% | 3.7% | 78.7% |
| warden | 476 | 1.9 | 45.2% | 9.0% | 78.6% |
| nightwatch | 464 | 1.9 | 34.9% | 10.1% | 88.4% |
| confessor | 433 | 1.9 | 40.0% | 18.2% | 83.6% |
| lamplighter | 419 | 1.9 | 30.8% | 8.6% | 79.5% |
| medium | 377 | 2.1 | 38.7% | 9.5% | 78.5% |
| augur | 357 | 2.0 | 41.7% | 7.3% | 76.5% |
| seer | 351 | 1.9 | 46.4% | 5.7% | 79.2% |
| martyr | 161 | 2.2 | 20.5% | 10.6% | 78.3% |
| sexton | 155 | 2.2 | 25.8% | 18.1% | 71.0% |
| monitor | 152 | 2.1 | 35.5% | 2.6% | 78.9% |
| executor | 149 | 2.3 | 25.5% | 7.4% | 81.2% |
| veteran | 147 | 2.8 | 4.1% | 19.0% | 89.1% |
| magistrate | 138 | 2.0 | 41.3% | 7.2% | 84.1% |
| chronicler | 135 | 2.0 | 37.0% | 9.6% | 76.3% |
| psychologist | 126 | 2.1 | 32.5% | 11.9% | 77.8% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| nightwatch | 273 | 0.4% | 66.7% |
| registrar | 272 | 0.7% | 55.9% |
| confessor | 269 | 0.0% | 73.2% |
| lamplighter | 265 | 0.8% | 66.8% |
| dowser | 250 | 0.8% | 69.2% |
| medium | 247 | 0.0% | 72.1% |
| clerk | 234 | 4.3% | 59.0% |
| surveyor | 234 | 5.1% | 61.5% |
| gravedigger | 223 | 0.9% | 65.9% |
| rumormonger | 222 | 5.4% | 67.1% |
| archivist | 210 | 3.8% | 71.9% |
| chronicler | 172 | 0.0% | 66.9% |
| executor | 161 | 0.0% | 44.1% |
| psychologist | 154 | 0.0% | 61.0% |
| magistrate | 152 | 0.0% | 63.8% |
| monitor | 150 | 0.0% | 46.0% |
| seer | 145 | 0.7% | 49.0% |
| augur | 132 | 0.8% | 61.4% |
| warden | 37 | 0.0% | 78.4% |
| veteran | 30 | 0.0% | 63.3% |
| martyr | 25 | 4.0% | 36.0% |
| sexton | 21 | 0.0% | 61.9% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 460 | 82.6% | 1540 | 61.0% | +21.6 (+17.4 to +25.9) |
| breathstealer + surveyor | 220 | 84.5% | 1780 | 63.7% | +20.9 (+15.6 to +26.2) |
| breathstealer + clerk | 252 | 82.1% | 1748 | 63.6% | +18.5 (+13.3 to +23.8) |
| archivist + breathstealer | 254 | 81.9% | 1746 | 63.6% | +18.3 (+13.0 to +23.5) |
| breathstealer + rumormonger | 251 | 80.5% | 1749 | 63.9% | +16.6 (+11.2 to +22.0) |
| clerk + nightwatch | 238 | 77.7% | 1762 | 64.4% | +13.4 (+7.6 to +19.1) |
| archivist + revenant | 256 | 54.3% | 1744 | 67.7% | -13.4 (-19.8 to -6.9) |
| demon + poisoner | 658 | 57.3% | 1342 | 70.2% | -12.9 (-17.4 to -8.4) |
| poisoner + rumormonger | 372 | 55.6% | 1628 | 68.3% | -12.7 (-18.2 to -7.1) |
| archivist + poisoner | 356 | 55.6% | 1644 | 68.2% | -12.6 (-18.2 to -6.9) |
| nightwatch + surveyor | 230 | 75.7% | 1770 | 64.7% | +11.0 (+5.0 to +16.9) |
| demon + nightwatch | 464 | 74.4% | 1536 | 63.4% | +10.9 (+6.3 to +15.6) |

### 7 NPCs, passive

**Town gifts**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| nightwatch | 464 | 52.6% | 1536 | 34.3% | +18.3 (+13.1 to +23.4) **\*** |
| chronicler | 135 | 25.9% | 1865 | 39.5% | -13.5 (-21.3 to -5.8) **\*** |
| dowser | 591 | 46.7% | 1409 | 35.1% | +11.6 (+6.8 to +16.3) **\*** |
| psychologist | 126 | 29.4% | 1874 | 39.2% | -9.8 (-18.1 to -1.5) **\*** |
| executor | 149 | 30.2% | 1851 | 39.2% | -9.0 (-16.7 to -1.3) **\*** |
| medium | 377 | 31.8% | 1623 | 40.1% | -8.3 (-13.6 to -3.0) **\*** |
| martyr | 161 | 31.1% | 1839 | 39.2% | -8.2 (-15.6 to -0.7) **\*** |
| augur | 357 | 33.3% | 1643 | 39.7% | -6.4 (-11.8 to -0.9) **\*** |
| veteran | 147 | 34.0% | 1853 | 38.9% | -4.9 (-12.9 to +3.1) |
| seer | 351 | 34.8% | 1649 | 39.4% | -4.6 (-10.1 to +0.9) |
| gravedigger | 583 | 35.5% | 1417 | 39.8% | -4.3 (-8.9 to +0.3) |
| warden | 476 | 41.4% | 1524 | 37.7% | +3.7 (-1.3 to +8.8) |
| lamplighter | 419 | 41.1% | 1581 | 37.9% | +3.2 (-2.1 to +8.4) |
| rumormonger | 1069 | 37.4% | 931 | 39.8% | -2.4 (-6.7 to +1.8) |
| clerk | 1076 | 39.2% | 924 | 37.8% | +1.4 (-2.8 to +5.7) |
| registrar | 539 | 39.5% | 1461 | 38.2% | +1.3 (-3.5 to +6.1) |
| confessor | 433 | 37.9% | 1567 | 38.7% | -0.9 (-6.0 to +4.3) |
| archivist | 1099 | 38.2% | 901 | 39.0% | -0.7 (-5.0 to +3.5) |
| surveyor | 1003 | 38.9% | 997 | 38.2% | +0.7 (-3.6 to +4.9) |
| magistrate | 138 | 39.1% | 1862 | 38.5% | +0.6 (-7.8 to +9.1) |
| sexton | 155 | 38.1% | 1845 | 38.6% | -0.5 (-8.5 to +7.4) |
| monitor | 152 | 38.8% | 1848 | 38.5% | +0.3 (-7.8 to +8.3) |

**Minions**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer | 460 | 62.6% | 1540 | 31.4% | +31.2 (+26.3 to +36.2) **\*** |
| poisoner | 658 | 28.9% | 1342 | 43.3% | -14.4 (-18.8 to -10.1) **\*** |
| revenant | 447 | 27.7% | 1553 | 41.7% | -13.9 (-18.7 to -9.1) **\*** |
| scion | 435 | 38.9% | 1565 | 38.5% | +0.4 (-4.8 to +5.6) |

_One demon type in every game: no demon comparison._

**Secrets**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| delusional | 519 | 26.4% | 1481 | 42.8% | -16.4 (-21.0 to -11.9) **\*** |
| unrequited | 475 | 45.9% | 1525 | 36.3% | +9.6 (+4.5 to +14.7) **\*** |
| ill_omened | 522 | 45.2% | 1478 | 36.2% | +9.0 (+4.1 to +13.9) **\*** |
| marked | 484 | 37.2% | 1516 | 39.0% | -1.8 (-6.8 to +3.2) |

**Night-walkers dealt (including the Demon)**

| | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| 4 night-walkers | 97 | 34.0% | 1903 | 38.8% | -4.8 (-14.4 to +4.9) |
| 3 night-walkers | 633 | 39.5% | 1367 | 38.1% | +1.4 (-3.2 to +6.0) |
| 2 night-walkers | 1270 | 38.4% | 730 | 38.8% | -0.3 (-4.8 to +4.1) |

**Town gifts in play: fate**

| Gift | Dealt | Avg death day | Killed by the Demon nights 1–2 | Executed while good | Claimed publicly |
|---|---|---|---|---|---|
| archivist | 1099 | 2.3 | 34.3% | 21.7% | 94.3% |
| clerk | 1076 | 2.9 | 16.8% | 18.8% | 94.5% |
| rumormonger | 1069 | 2.8 | 18.0% | 24.7% | 94.9% |
| surveyor | 1003 | 2.8 | 19.1% | 25.0% | 95.3% |
| dowser | 591 | 1.7 | 67.3% | 4.2% | 87.1% |
| gravedigger | 583 | 1.9 | 58.1% | 9.6% | 84.7% |
| registrar | 539 | 2.2 | 46.2% | 4.5% | 83.5% |
| warden | 476 | 2.2 | 44.5% | 11.6% | 82.4% |
| nightwatch | 464 | 2.0 | 46.6% | 9.1% | 90.5% |
| confessor | 433 | 2.1 | 50.6% | 9.5% | 88.0% |
| lamplighter | 419 | 2.3 | 31.3% | 10.3% | 87.8% |
| medium | 377 | 2.2 | 41.4% | 12.2% | 83.6% |
| augur | 357 | 2.2 | 48.2% | 10.6% | 79.6% |
| seer | 351 | 2.0 | 56.4% | 10.5% | 85.5% |
| martyr | 161 | 2.9 | 21.1% | 16.1% | 85.1% |
| sexton | 155 | 2.5 | 29.0% | 16.1% | 74.2% |
| monitor | 152 | 2.3 | 42.1% | 3.3% | 80.3% |
| executor | 149 | 2.5 | 32.2% | 11.4% | 83.2% |
| veteran | 147 | 3.3 | 5.4% | 34.7% | 94.6% |
| magistrate | 138 | 2.1 | 45.7% | 8.7% | 85.5% |
| chronicler | 135 | 2.4 | 36.3% | 11.9% | 77.8% |
| psychologist | 126 | 2.3 | 39.7% | 14.3% | 86.5% |

**Evil bluffs claimed**

| Bluff | Times claimed | Contested | Bluffer executed |
|---|---|---|---|
| registrar | 279 | 0.4% | 35.5% |
| nightwatch | 276 | 0.4% | 32.2% |
| confessor | 269 | 0.0% | 45.7% |
| lamplighter | 267 | 1.1% | 46.1% |
| medium | 252 | 0.0% | 51.2% |
| dowser | 248 | 0.0% | 44.0% |
| clerk | 239 | 6.3% | 41.0% |
| surveyor | 229 | 3.5% | 45.4% |
| rumormonger | 225 | 7.1% | 52.0% |
| gravedigger | 225 | 0.9% | 48.9% |
| archivist | 212 | 5.2% | 57.5% |
| chronicler | 169 | 0.0% | 48.5% |
| executor | 161 | 0.0% | 28.0% |
| psychologist | 158 | 0.0% | 41.8% |
| magistrate | 152 | 0.7% | 46.1% |
| monitor | 151 | 0.7% | 22.5% |
| seer | 150 | 0.0% | 26.7% |
| augur | 138 | 0.7% | 37.7% |
| warden | 38 | 2.6% | 52.6% |
| veteran | 30 | 0.0% | 23.3% |
| martyr | 25 | 0.0% | 52.0% |
| sexton | 22 | 9.1% | 36.4% |

**Role pairs** (n ≥ 200 both ways, |difference| ≥ 10 points)

| Pair | With (n) | Win with | Without (n) | Win without | Difference (95% CI) |
|---|---|---|---|---|---|
| breathstealer + demon | 460 | 62.6% | 1540 | 31.4% | +31.2 (+26.3 to +36.2) |
| breathstealer + clerk | 252 | 64.3% | 1748 | 34.8% | +29.4 (+23.1 to +35.8) |
| breathstealer + surveyor | 220 | 64.5% | 1780 | 35.3% | +29.2 (+22.5 to +35.9) |
| breathstealer + rumormonger | 251 | 61.8% | 1749 | 35.2% | +26.5 (+20.1 to +32.9) |
| archivist + breathstealer | 254 | 61.0% | 1746 | 35.3% | +25.7 (+19.3 to +32.1) |
| demon + nightwatch | 464 | 52.6% | 1536 | 34.3% | +18.3 (+13.1 to +23.4) |
| clerk + nightwatch | 238 | 53.8% | 1762 | 36.5% | +17.3 (+10.6 to +24.0) |
| archivist + nightwatch | 249 | 53.4% | 1751 | 36.4% | +17.0 (+10.4 to +23.6) |
| gravedigger + poisoner | 218 | 24.8% | 1782 | 40.2% | -15.5 (-21.6 to -9.3) |
| nightwatch + rumormonger | 251 | 51.8% | 1749 | 36.6% | +15.1 (+8.6 to +21.7) |
| poisoner + rumormonger | 372 | 26.6% | 1628 | 41.3% | -14.7 (-19.8 to -9.6) |
| demon + poisoner | 658 | 28.9% | 1342 | 43.3% | -14.4 (-18.8 to -10.1) |
| demon + revenant | 447 | 27.7% | 1553 | 41.7% | -13.9 (-18.7 to -9.1) |
| nightwatch + surveyor | 230 | 50.9% | 1770 | 36.9% | +13.9 (+7.1 to +20.8) |
| clerk + revenant | 226 | 26.5% | 1774 | 40.1% | -13.5 (-19.7 to -7.3) |
| archivist + revenant | 256 | 27.0% | 1744 | 40.3% | -13.3 (-19.2 to -7.4) |
| clerk + dowser | 311 | 49.5% | 1689 | 36.5% | +13.0 (+7.0 to +19.0) |
| revenant + rumormonger | 221 | 27.1% | 1779 | 40.0% | -12.8 (-19.1 to -6.5) |
| clerk + poisoner | 361 | 28.5% | 1639 | 40.8% | -12.2 (-17.5 to -7.0) |
| demon + dowser | 591 | 46.7% | 1409 | 35.1% | +11.6 (+6.8 to +16.3) |
| archivist + poisoner | 356 | 29.2% | 1644 | 40.6% | -11.4 (-16.6 to -6.1) |
| revenant + surveyor | 231 | 29.0% | 1769 | 39.8% | -10.8 (-17.1 to -4.5) |
| poisoner + surveyor | 334 | 29.9% | 1666 | 40.3% | -10.3 (-15.8 to -4.9) |

## Does the player matter? Paired seeds

Same seed and size means the same script and deal, so each bot game has a passive twin.

| Size | Bot cell | Paired games | Bot wins, passive loses | Passive wins, bot loses | Both win | Both lose |
|---|---|---|---|---|---|---|
| 7 | 7 NPCs, bot insight 1.0 | 2000 | 702 (35.1%) | 154 (7.7%) | 617 | 527 |

## Health

- Stuck games (guard exhausted): 0
- Seeds with no record: none
- Failed games (crash or timeout): 0
- Games with engine errors: 77
  - Most common lines:
    - 77× `SCRIPT ERROR: Invalid access to property or key 'broken_chance' on a base object of type 'Dictionary'.`
    - 77× `SCRIPT ERROR: Invalid access to property or key 'target' on a base object of type 'Dictionary'.`
    - 77× `SCRIPT ERROR: Invalid access to property or key 'input' on a base object of type 'Dictionary'.`
- Unprepared refreshes: 6 games with any

| Cell | Median wall (s) | p90 | Max |
|---|---|---|---|
| 7 NPCs, bot insight 1.0 | 71.3 | 147.4 | 423.5 |
| 7 NPCs, passive | 15.4 | 30.1 | 129.5 |

Slowest seeds: 100954 (7 NPCs bot, 423 s), 101426 (7 NPCs bot, 392 s), 101789 (7 NPCs bot, 382 s), 101694 (7 NPCs bot, 362 s), 101660 (7 NPCs bot, 356 s), 101555 (7 NPCs bot, 345 s), 101675 (7 NPCs bot, 343 s), 101842 (7 NPCs bot, 321 s), 101773 (7 NPCs bot, 317 s), 100792 (7 NPCs bot, 315 s), 100720 (7 NPCs bot, 309 s), 100801 (7 NPCs bot, 302 s), 100834 (7 NPCs bot, 300 s), 100701 (7 NPCs bot, 283 s), 101733 (7 NPCs bot, 283 s), 100837 (7 NPCs bot, 282 s), 100787 (7 NPCs bot, 275 s), 101871 (7 NPCs bot, 267 s), 101035 (7 NPCs bot, 265 s), 101814 (7 NPCs bot, 258 s)

