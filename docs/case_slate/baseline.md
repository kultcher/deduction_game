# Case slate: baseline report

Built on claude/lamplighter-count (main at a6b674b with the Lamplighter count mix, Nov 19,
Quill). There are 27 cases on 10 deals each, 269 in all, and no listener was blocked. Made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. Town movement is in
points: one point is 0.01 of suspicion, and listeners start at 25.

**Changes since the last baseline (claude/slate-strong).** A Lamplighter's count is now
weighed as possibly broken (the Lamplighter evil, poisoned or Delusional), and a broken count
says nothing. Three Lamplighter cases were added.

| Case | Average listener's chance after the case (from 30%) | Strength | Town |
|---|---|---|---|
| Lamplighter + everyone else's alibi | 47% → 43% | 2.10 → 1.74 | +18 → +14 |
| The same against an innocent (the Demon's alibi false, or the count false from a poisoned or Delusional Lamplighter) | 47% → 43% | 2.10 → 1.74 | +20 → +16 |
| A Minion bluffing the Lamplighter, against an innocent (new) | 47% → 43% | 2.10 → 1.73 | +18 → +11 |
| The count alone (new; and against an innocent) | 30% → 30% | 1.01 → 1.00 | +1 → +1 |

The "before" figures for the new cases come from the same cases run on main without the
change. The bluff loses the most with the town, likely because a listener who already doubts
the Minion takes its count as more likely broken (not traced). All three Lamplighter-and-alibis cases keep
their Weak badge.

Elsewhere: on one deal (seed 11), which has a real Lamplighter in town, the Night Watch
"nobody" case and its twin move 0.3 and 0.35 of a point further against the subject. The
likely cause is that Lamplighter's own count, which listeners already hold. One Gravedigger
row changes at rounding level. Every other row is identical, though main has moved since
the last baseline (#289 and #344 among others).

Step 2 (the count weighed against each possible world, a Poisson-binomial term) is next. It
is meant to raise the Lamplighter-and-alibis case again, since a count of 1 with everyone else at
home then points at the one without an alibi.

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
| lamp_alibis | 10 | weak 10 | 1.74 | +14.3 (+11.4 to +18.5) | 100% | 0% |
| lamp_count | 10 | none 10 | 1.00 | +0.7 (-0.2 to +1.3) | 60% | 100% |
| nw_nobody | 10 | none 10 | 0.85 | -3.0 (-6.4 to +2.7) | 80% | 20% |
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
| lamp_alibis_innocent | 10 | weak 10 | 1.74 | +15.6 (+10.3 to +20.2) | 100% | 0% |
| lamp_count_innocent | 10 | none 10 | 1.00 | +0.8 (-0.5 to +2.2) | 50% | 100% |
| nw_nobody_innocent | 10 | none 10 | 0.86 | -3.5 (-7.6 to +3.6) | 80% | 10% |
| guard_innocent | 10 | none 10 | 1.08 | +3.1 (+0.8 to +5.7) | 90% | 60% |
| lamp_bluff_innocent | 10 | weak 10 | 1.73 | +10.9 (+4.8 to +17.1) | 100% | 40% |

Town movement by the juror's badge, true cases (the subject is evil):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 74 | +5.4 | +4.3 | -6.4 to +20.3 | pile 10, kill_sighting 10, vigil_kill 4, alibi_sighting 10, lamp_count 10, nw_nobody 10, guard 10, seer_twice 10 |
| weak | 56 | +18.3 | +18.0 | +10.1 to +29.3 | vigil_kill 6, converging 10, double_claim 10, gravedigger 10, lamp_alibis 10, vigil_seer 10 |
| moderate | 10 | +40.7 | +39.5 | +36.1 to +53.6 | stack 10 |
| strong | 10 | +59.0 | +59.0 | +54.6 to +63.3 | impossible 10 |

Town movement by the juror's badge, misleading cases (the subject is innocent):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 67 | +5.6 | +4.6 | -7.6 to +21.0 | pile_innocent 10, kill_sighting_innocent 10, vigil_kill_innocent 7, alibi_sighting_innocent 10, lamp_count_innocent 10, nw_nobody_innocent 10, guard_innocent 10 |
| weak | 52 | +15.7 | +14.6 | +4.8 to +30.0 | vigil_kill_innocent 3, converging_innocent 9, double_claim_innocent 10, gravedigger_innocent 10, lamp_alibis_innocent 10, lamp_bluff_innocent 10 |

Town bands used for category agreement (points): strong from +25, moderate from +10, weak from +3, none from -2, contradicts below.

## What it shows

**True cases:**

- Each tier now moves the town further than the one below it. Under the proposed cuts,
  the means run +2, +14, +22, +41 and +59, though Weak and Moderate overlap across most
  of their ranges. The Lamplighter-and-alibis case (×1.74) now falls in Weak under those
  cuts; it was Moderate (×2.10) before the count mix.
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
