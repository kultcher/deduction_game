# Case slate: baseline report

Built on claude/slate-strong (main at 4cf1d73, Nov 19, Quill). There are 24 cases on 10
deals each, 239 in all, and no listener was blocked. Made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. Town movement is in
points: one point is 0.01 of suspicion, and listeners start at 25.

**Changes since the last baseline (claude/juror-listener).**

- Three true cases were added to reach the upper tiers: seer_twice, vigil_seer and stack.
  None has a misleading twin.
- 22 of the 209 earlier rows changed, across 13 cases, and only in the town's movement:
  the largest change is 0.26 of a point. The juror's strength, its badges and every
  category are unchanged. Main moved under it: the likely cause is the NPC trust
  changes merged since (#319, #321, #330), not checked case by case. The impossible reading's mean moved from +59.1 to +59.0; every other mean is
  the same to the decimal.

Where the new cases land (average listener, premise's chance before → after):

| Case | Average listener | Strength | Town | Badge now (1.5 / 3 / 10) | Proposed cuts (1.25 / 2 / 3.5, 90%) |
|---|---|---|---|---|---|
| seer_twice | 30% → 37% | 1.38 | +8 | none | Weak |
| vigil_seer | 33% → 48% | 1.85 | +23 | Weak | Weak (1 deal Moderate) |
| stack | 33% → 65% | 3.83 | +41 | Moderate | Strong |

Under the proposed cut points (Weak ×1.25, Moderate ×2, Strong ×3.5, Damning /
Conclusive at a premise chance of 90% or more), the true cases sort like this:

| Tier | Cases | Town, mean | Range | Cases by name |
|---|---|---|---|---|
| none | 40 | +2.6 | −6.1 to +12.0 | pile, alibi_sighting, nw_nobody, guard |
| Weak | 49 | +14.5 | +6.5 to +24.6 | kill_sighting, vigil_kill, converging, seer_twice, vigil_seer 9 |
| Moderate | 31 | +20.6 | +12.1 to +29.3 | double_claim, gravedigger, lamp_alibis, vigil_seer 1 |
| Strong | 10 | +40.7 | +36.1 to +53.6 | stack |
| Damning | 10 | +59.0 | +54.6 to +63.3 | impossible |

And the misleading twins: none 40 (+2.7), Weak 29 (+13.9), Moderate 30 (+20.3).

The tables below still use the cut points in the code (1.5 / 3 / 10).

| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |
|---|---|---|---|---|---|---|
| pile | 10 | none 10 | 1.15 | +5.2 (+2.5 to +12.0) | 100% | 10% |
| kill_sighting | 10 | none 10 | 1.36 | +14.3 (+11.6 to +20.3) | 100% | 0% |
| vigil_kill | 10 | none 4, weak 6 | 1.47 | +16.1 (+12.6 to +18.3) | 100% | 0% |
| alibi_sighting | 10 | none 10 | 1.13 | +5.2 (+3.3 to +9.4) | 100% | 0% |
| converging | 10 | weak 10 | 1.62 | +12.1 (+10.1 to +14.6) | 100% | 0% |
| impossible | 10 | strong 10 | 177.50 | +59.0 (+54.6 to +63.3) | 100% | 100% |
| double_claim | 10 | weak 10 | 2.73 | +22.8 (+17.3 to +29.3) | 100% | 0% |
| gravedigger | 10 | weak 10 | 2.83 | +20.0 (+15.0 to +26.6) | 100% | 0% |
| lamp_alibis | 10 | weak 10 | 2.10 | +18.2 (+12.1 to +23.7) | 100% | 0% |
| nw_nobody | 10 | none 10 | 0.85 | -3.0 (-6.1 to +2.7) | 80% | 20% |
| guard | 10 | none 10 | 1.07 | +3.1 (+2.0 to +6.4) | 100% | 50% |
| seer_twice | 10 | none 10 | 1.38 | +8.2 (+6.5 to +13.8) | 100% | 0% |
| vigil_seer | 10 | weak 10 | 1.85 | +22.8 (+18.8 to +27.5) | 100% | 0% |
| stack | 10 | moderate 10 | 3.83 | +40.7 (+36.1 to +53.6) | 100% | 0% |
| pile_innocent | 10 | none 10 | 1.15 | +5.7 (+0.5 to +13.4) | 90% | 10% |
| kill_sighting_innocent | 10 | none 10 | 1.36 | +14.7 (+9.1 to +21.0) | 100% | 0% |
| vigil_kill_innocent | 10 | none 7, weak 3 | 1.44 | +15.9 (+10.3 to +17.6) | 100% | 0% |
| alibi_sighting_innocent | 10 | none 10 | 1.13 | +5.4 (+3.3 to +10.9) | 100% | 0% |
| converging_innocent | 9 | weak 9 | 1.62 | +10.7 (+8.3 to +14.3) | 100% | 56% |
| double_claim_innocent | 10 | weak 10 | 2.73 | +21.8 (+18.4 to +29.0) | 100% | 0% |
| gravedigger_innocent | 10 | weak 10 | 2.84 | +19.1 (+7.2 to +30.0) | 100% | 10% |
| lamp_alibis_innocent | 10 | weak 10 | 2.10 | +20.0 (+17.2 to +24.1) | 100% | 0% |
| nw_nobody_innocent | 10 | none 10 | 0.86 | -3.5 (-7.6 to +3.6) | 80% | 10% |
| guard_innocent | 10 | none 10 | 1.08 | +3.1 (+0.8 to +5.7) | 90% | 60% |

Town movement by the juror's badge, true cases (the subject is evil):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 64 | +6.1 | +5.0 | -6.1 to +20.3 | pile 10, kill_sighting 10, vigil_kill 4, alibi_sighting 10, nw_nobody 10, guard 10, seer_twice 10 |
| weak | 56 | +19.0 | +18.9 | +10.1 to +29.3 | vigil_kill 6, converging 10, double_claim 10, gravedigger 10, lamp_alibis 10, vigil_seer 10 |
| moderate | 10 | +40.7 | +39.5 | +36.1 to +53.6 | stack 10 |
| strong | 10 | +59.0 | +59.0 | +54.6 to +63.3 | impossible 10 |

Town movement by the juror's badge, misleading cases (the subject is innocent):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 57 | +6.5 | +5.0 | -7.6 to +21.0 | pile_innocent 10, kill_sighting_innocent 10, vigil_kill_innocent 7, alibi_sighting_innocent 10, nw_nobody_innocent 10, guard_innocent 10 |
| weak | 42 | +17.9 | +18.9 | +7.2 to +30.0 | vigil_kill_innocent 3, converging_innocent 9, double_claim_innocent 10, gravedigger_innocent 10, lamp_alibis_innocent 10 |

Town bands used for category agreement (points): strong from +25, moderate from +10, weak from +3, none from -2, contradicts below.

## What it shows

**True cases:**

- Each tier now moves the town further than the one below it. Under the proposed cuts,
  the means run +3, +15, +21, +41 and +59, though Weak and Moderate overlap across most
  of their ranges.
- The stack is the first constructed case in the Strong tier. It's the kind of case a
  player builds over two nights: their own vigil at a kill, a witness at the scene, and
  two Seer readings. It moves the town about +41, between the Moderate cases and the
  impossible reading.
- Two Seer "yes" readings alone are a gentle case (+8). The vigil plus one Seer reading moves
  the town +23, more than the vigil at a kill alone (+16) or the two readings alone.
- The impossible reading is still the only case past 90%, and it moves the town about +59.
- The Night Watch "nobody" chain still gets no badge and moves the town slightly away
  from the subject (about −3).

**Misleading cases** (the same chains about an innocent):

- On the same evidence, the town moves as far against an innocent as against the Demon,
  and a lie from evil carries as much weight as a true account. Nothing here changed
  since the last baseline; these rows are the reference for whether a later change makes
  the town easier to mislead.

Not measured here:

- one build only;
- the 10-NPC town only;
- listeners at a single credibility, 0.7;
- what the town does after a case (votes, nominations).
