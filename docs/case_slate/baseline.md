# Case slate: baseline report

Built on claude/slate-gap (main at 17dd113, with #346, #349, #355 and #357, plus each case presented to
its sources too, Nov 19, Quill). There are 28 cases, 275 in all (two_kills_seer finds 6 deals,
converging_innocent 9, the rest 10), and no listener was blocked. Made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. Town movement is in
points: one point is 0.01 of suspicion, and listeners start at 25.

**Changes since the last baseline (#355, built before #346 and #349 landed).**

- **Sources hear the case.** A case's witnesses, readers and victims used to be left out of
  its presentation, so they voted on the subject without having heard it. A presentation at
  a meeting reaches the whole town, so they hear it now. That was what made Strong look
  barely stronger than Moderate. The juror's strengths are unchanged. The town moves further
  on cases whose sources were left out before: kill_sighting +14.3 → +16.1, double_claim
  +22.8 → +28.2, gravedigger +20.0 → +22.2.
- **The badges are #357's cut points:** Weak from ×1.25, Moderate from ×2, Strong from ×3.5,
  and Damning at a 90% chance. The report now knows the Damning badge, and its town bands gain
  one from +45.
- **A new case, two_kills_seer:** two killings, the vigil and a witness at each, and the Seer's
  "yes" on the Demon on both nights. It's ×8.0 (the average listener's chance about 82%), Strong,
  between stack and the Damning impossible reading.
- **Two new vote columns:** "Heard it" and "Of those, yes".
- **#346 and #349 move nothing here.** Each row matches a run made before they landed, to within
  0.1 of a point.

Votes by badge (true cases). "Before" is the last baseline, regrouped by the same badges:

| Badge | Cases | Good votes swayed (before) | Good yes after | Hangs on good votes alone | Hangs with the player's vote too |
|---|---|---|---|---|---|
| none | 50 | 0.0 (0.0) | 0.1 of 7.0 | 0% | 0% |
| Weak | 59 | 2.0 (1.6) | 2.0 of 6.5 | 12% | 20% |
| Moderate | 21 | 4.2 (3.2) | 4.3 of 7.0 | 38% | 52% |
| Strong | 16 | 5.4 (3.8, stack alone) | 5.6 of 5.6 | 100% | 100% |
| Damning | 10 | 6.9 (6.9) | 7.0 of 7.0 | 100% | 100% |

The misleading twins: none 0.0, Weak 1.5 (before 1.1), and Moderate 3.4 (unchanged, with 35%
hanging with the player's vote). None hangs an innocent on good votes alone.

| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |
|---|---|---|---|---|---|---|
| pile | 10 | none 10 | 1.15 | +6.0 (+3.8 to +10.8) | 100% | 0% |
| kill_sighting | 10 | weak 10 | 1.36 | +16.1 (+14.1 to +21.3) | 100% | 0% |
| vigil_kill | 10 | weak 10 | 1.47 | +16.1 (+12.6 to +18.3) | 100% | 0% |
| alibi_sighting | 10 | none 10 | 1.13 | +6.2 (+4.6 to +10.0) | 100% | 0% |
| converging | 10 | weak 10 | 1.62 | +11.8 (+9.9 to +13.8) | 100% | 10% |
| impossible | 10 | damning 10 | 177.50 | +59.0 (+54.6 to +63.3) | 100% | 100% |
| double_claim | 10 | moderate 10 | 2.73 | +28.2 (+24.3 to +33.4) | 100% | 10% |
| gravedigger | 10 | moderate 10 | 2.83 | +22.2 (+18.4 to +27.7) | 100% | 90% |
| lamp_alibis | 10 | weak 10 | 1.74 | +13.9 (+10.4 to +16.1) | 100% | 0% |
| lamp_count | 10 | none 10 | 1.00 | +0.6 (-0.1 to +1.1) | 70% | 100% |
| nw_nobody | 10 | none 10 | 0.85 | -3.3 (-6.8 to +1.0) | 80% | 20% |
| guard | 10 | none 10 | 1.07 | +4.7 (+3.5 to +7.2) | 100% | 0% |
| seer_twice | 10 | weak 10 | 1.38 | +8.5 (+6.6 to +13.5) | 100% | 90% |
| vigil_seer | 10 | weak 9, moderate 1 | 1.85 | +23.3 (+20.9 to +28.5) | 100% | 0% |
| stack | 10 | strong 10 | 3.83 | +41.9 (+38.3 to +50.3) | 100% | 80% |
| two_kills_seer | 6 | strong 6 | 8.02 | +54.3 (+51.4 to +59.8) | 100% | 0% |
| pile_innocent | 10 | none 10 | 1.15 | +6.6 (+3.1 to +12.1) | 100% | 0% |
| kill_sighting_innocent | 10 | weak 10 | 1.36 | +16.7 (+12.6 to +21.7) | 100% | 0% |
| vigil_kill_innocent | 10 | weak 10 | 1.44 | +15.9 (+10.3 to +17.6) | 100% | 0% |
| alibi_sighting_innocent | 10 | none 10 | 1.13 | +5.4 (+3.3 to +10.9) | 100% | 0% |
| converging_innocent | 9 | weak 9 | 1.62 | +11.1 (+8.8 to +13.9) | 100% | 22% |
| double_claim_innocent | 10 | moderate 10 | 2.73 | +21.8 (+18.4 to +29.0) | 100% | 90% |
| gravedigger_innocent | 10 | moderate 10 | 2.84 | +19.1 (+7.2 to +30.0) | 100% | 80% |
| lamp_alibis_innocent | 10 | weak 10 | 1.74 | +15.2 (+9.5 to +21.2) | 100% | 10% |
| lamp_count_innocent | 10 | none 10 | 1.00 | +0.7 (-0.4 to +1.8) | 80% | 100% |
| nw_nobody_innocent | 10 | none 10 | 0.86 | -4.6 (-9.7 to +2.1) | 90% | 20% |
| guard_innocent | 10 | none 10 | 1.08 | +5.1 (+1.8 to +8.3) | 100% | 10% |
| lamp_bluff_innocent | 10 | weak 10 | 1.73 | +10.9 (+4.8 to +17.1) | 100% | 40% |

Town movement by the juror's badge, true cases (the subject is evil):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 50 | +2.8 | +4.4 | -6.8 to +10.8 | pile 10, alibi_sighting 10, lamp_count 10, nw_nobody 10, guard 10 |
| weak | 59 | +14.7 | +14.8 | +6.6 to +25.1 | kill_sighting 10, vigil_kill 10, converging 10, lamp_alibis 10, seer_twice 10, vigil_seer 9 |
| moderate | 21 | +25.4 | +25.4 | +18.4 to +33.4 | double_claim 10, gravedigger 10, vigil_seer 1 |
| strong | 16 | +46.6 | +44.4 | +38.3 to +59.8 | stack 10, two_kills_seer 6 |
| damning | 10 | +59.0 | +59.0 | +54.6 to +63.3 | impossible 10 |

Town movement by the juror's badge, misleading cases (the subject is innocent):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 50 | +2.6 | +3.8 | -9.7 to +12.1 | pile_innocent 10, alibi_sighting_innocent 10, lamp_count_innocent 10, nw_nobody_innocent 10, guard_innocent 10 |
| weak | 49 | +14.0 | +14.7 | +4.8 to +21.7 | kill_sighting_innocent 10, vigil_kill_innocent 10, converging_innocent 9, lamp_alibis_innocent 10, lamp_bluff_innocent 10 |
| moderate | 20 | +20.4 | +21.2 | +7.2 to +30.0 | double_claim_innocent 10, gravedigger_innocent 10 |

Votes: the subject nominated by a neutral nominator, the player's vote left out. Good
voters only (evil voters vote by strategy and are left out). "Reaches" is how often the good
yes votes alone reach the hanging threshold, which counts the player's seat. "Heard it" counts
the good who heard the case: its sources (witnesses, readers, victims) vote without hearing it.

| Case | Good yes before | Good yes after | Share of good voters after | Heard it | Of those, yes | Threshold | Reaches |
|---|---|---|---|---|---|---|---|
| pile | 0.1 | 0.1 | 1% | 7.0 | 1% | 6 | 0% |
| kill_sighting | 0.1 | 2.2 | 37% | 6.0 | 37% | 5 | 0% |
| vigil_kill | 0.0 | 2.6 | 43% | 6.0 | 43% | 5 | 0% |
| alibi_sighting | 0.1 | 0.3 | 4% | 7.0 | 4% | 6 | 0% |
| converging | 0.0 | 1.1 | 16% | 7.0 | 16% | 6 | 0% |
| impossible | 0.1 | 7.0 | 100% | 7.0 | 100% | 6 | 100% |
| double_claim | 0.1 | 5.3 | 76% | 7.0 | 76% | 6 | 60% |
| gravedigger | 0.1 | 3.1 | 44% | 7.0 | 44% | 5 | 10% |
| lamp_alibis | 0.0 | 1.6 | 23% | 7.0 | 23% | 6 | 0% |
| lamp_count | 0.0 | 0.0 | 0% | 7.0 | 0% | 6 | 0% |
| nw_nobody | 0.1 | 0.0 | 0% | 7.0 | 0% | 6 | 0% |
| guard | 0.0 | 0.0 | 0% | 7.0 | 0% | 6 | 0% |
| seer_twice | 0.1 | 0.2 | 3% | 7.0 | 3% | 6 | 0% |
| vigil_seer | 0.0 | 4.9 | 82% | 6.0 | 82% | 5 | 80% |
| stack | 0.1 | 5.9 | 98% | 6.0 | 98% | 5 | 100% |
| two_kills_seer | 0.3 | 5.0 | 100% | 5.0 | 100% | 5 | 100% |
| pile_innocent | 0.1 | 0.1 | 2% | 6.0 | 2% | 6 | 0% |
| kill_sighting_innocent | 0.1 | 1.9 | 38% | 5.0 | 38% | 5 | 0% |
| vigil_kill_innocent | 0.0 | 2.2 | 44% | 5.0 | 44% | 5 | 0% |
| alibi_sighting_innocent | 0.1 | 0.2 | 3% | 6.0 | 3% | 6 | 0% |
| converging_innocent | 0.0 | 0.6 | 9% | 6.0 | 9% | 6 | 0% |
| double_claim_innocent | 0.0 | 4.1 | 68% | 6.0 | 68% | 6 | 0% |
| gravedigger_innocent | 0.1 | 2.8 | 47% | 6.0 | 47% | 5 | 0% |
| lamp_alibis_innocent | 0.0 | 1.8 | 30% | 6.0 | 30% | 6 | 0% |
| lamp_count_innocent | 0.0 | 0.0 | 0% | 6.0 | 0% | 6 | 0% |
| nw_nobody_innocent | 0.1 | 0.0 | 0% | 6.0 | 0% | 6 | 0% |
| guard_innocent | 0.0 | 0.1 | 2% | 6.0 | 2% | 6 | 0% |
| lamp_bluff_innocent | 0.1 | 1.0 | 17% | 6.0 | 17% | 6 | 0% |

Town bands used for category agreement (points): damning from +45, strong from +25, moderate from +10, weak from +3, none from -2, contradicts below.
