# Case slate: baseline report

Built on claude/juror-listener (main with #326, Nov 19, Quill): the Test juror hears as an
average listener (juror fix (a)). There are 21 cases on 10 deals each, 209 in all, and no
listener was blocked. A second run on the merged branch reproduced every row. Made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. Town movement is in
points: one point is 0.01 of suspicion, and listeners start at 25.

**Changes since the last baseline (9c5eaf0).** Only the juror's columns changed: its strength
and badge. The town's movement is identical, because no NPC reads the juror. The juror's
strength now tracks the town:

| Case | Average listener, 30% → | Strength | Town |
|---|---|---|---|
| Two sightings | 33% | 1.15 | +5 |
| Alibi caught out | 33% | 1.13 | +5 |
| Warden's guard | 32% | 1.07 | +3 |
| Night Watch "nobody" | 27% | 0.85 | −3 |
| Sighting at the kill | 40% | 1.36 | +14 |
| Vigil at the kill | 42% | 1.47 | +16 |
| Converging readings | 41% | 1.62 | +12 |
| Lamplighter + alibis | 47% | 2.10 | +18 |
| Double claim | 54% | 2.73 | +23 |
| Gravedigger confirms a Minion | 55% | 2.83 | +20 |
| Impossible reading | 99% | 178 | +59 |

The badges below still use the old cut points (1.5 / 3 / 10). New cut points are proposed to
Michael: Weak from ×1.25, Moderate from ×2, Strong from ×5, and Damning / Conclusive at the
premise's chance of 90% or more.

| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |
|---|---|---|---|---|---|---|
| pile | 10 | none 10 | 1.15 | +5.2 (+2.5 to +12.0) | 100% | 10% |
| kill_sighting | 10 | none 10 | 1.36 | +14.3 (+11.6 to +20.3) | 100% | 0% |
| vigil_kill | 10 | none 4, weak 6 | 1.47 | +16.1 (+12.6 to +18.3) | 100% | 0% |
| alibi_sighting | 10 | none 10 | 1.13 | +5.2 (+3.3 to +9.4) | 100% | 0% |
| converging | 10 | weak 10 | 1.62 | +12.1 (+10.1 to +14.6) | 100% | 0% |
| impossible | 10 | strong 10 | 177.50 | +59.1 (+54.7 to +63.5) | 100% | 100% |
| double_claim | 10 | weak 10 | 2.73 | +22.8 (+17.3 to +29.3) | 100% | 0% |
| gravedigger | 10 | weak 10 | 2.83 | +20.0 (+15.0 to +26.6) | 100% | 0% |
| lamp_alibis | 10 | weak 10 | 2.10 | +18.2 (+12.1 to +23.7) | 100% | 0% |
| nw_nobody | 10 | none 10 | 0.85 | -3.0 (-6.1 to +2.7) | 80% | 20% |
| guard | 10 | none 10 | 1.07 | +3.1 (+2.0 to +6.4) | 100% | 50% |
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
| none | 54 | +5.7 | +4.3 | -6.1 to +20.3 | pile 10, kill_sighting 10, vigil_kill 4, alibi_sighting 10, nw_nobody 10, guard 10 |
| weak | 46 | +18.1 | +18.0 | +10.1 to +29.3 | vigil_kill 6, converging 10, double_claim 10, gravedigger 10, lamp_alibis 10 |
| strong | 10 | +59.1 | +59.1 | +54.7 to +63.5 | impossible 10 |

Town movement by the juror's badge, misleading cases (the subject is innocent):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 57 | +6.5 | +5.0 | -7.6 to +21.0 | pile_innocent 10, kill_sighting_innocent 10, vigil_kill_innocent 7, alibi_sighting_innocent 10, nw_nobody_innocent 10, guard_innocent 10 |
| weak | 42 | +17.9 | +18.9 | +7.2 to +30.0 | vigil_kill_innocent 3, converging_innocent 9, double_claim_innocent 10, gravedigger_innocent 10, lamp_alibis_innocent 10 |

Town bands used for category agreement (points): strong from +25, moderate from +10, weak from +3, none from -2, contradicts below.

## What it shows

**True cases** (the first baseline, unchanged):

- At the ends, the badge and the town agree.
  - The impossible reading is the only Strong case, and it moves the town about +59.
  - The Night Watch "nobody" chain gets no badge, and it moves the town slightly away
    from the subject (about −3). But the juror still leans slightly toward the premise
    (1.39), so on direction they agree in only 2 of the 10 cases.
- In the middle, the badge doesn't separate how far the town moves. Weak cases move it
  about +12 on average, Moderate cases about +13, and each spans most of the range.
- The juror rates these lower than the town takes them: the double claim (+23), the
  Lamplighter count with the alibis (+18), the player's own vigil on a kill night (+16),
  and the converging Seer and Dowser readings (+12).
- The juror rates these higher than the town takes them: the alibi caught out (Moderate,
  +5) and the Warden's guard (Weak, +3, up from +2 since #306).
- The control, two sightings, is Weak and moves the town about +5.

**Misleading cases** (the same chains about an innocent):

- **On the same evidence, the town moves as far against an innocent as against the Demon.**
  Weak cases average +12 either way, and Moderate cases +13. No listener holds anything
  that tells the two apart. That's expected: the town goes on what it hears, and a case
  about the wrong person is the player's to avoid. These rows are the reference for
  whether a later change makes the town easier to mislead.
- **A lie from evil carries as much weight as a true account.**
  - A Minion's false sighting that catches an innocent's alibi moves the town +5, the same
    as a true sighting against the Demon's.
  - A Minion bluffing the Gravedigger, with a reading that a hanged innocent was a Minion,
    moves the town +19 (true reading: +20).
  - The Demon's false alibi in the Lamplighter case moves the town +20 against the innocent
    left without one (true case: +18).
- **A double claim cuts both ways.** Filed against the real holder, with the Demon as the
  bluffer, it moves the town +22, as against the bluffer (+23). Two claims alone don't
  show which is the bluff.

Not measured here:

- one build only;
- the 10-NPC town only;
- listeners at a single credibility, 0.7;
- what the town does after a case (votes, nominations).
