# Case slate: baseline report

Built from main at 9c5eaf0 (Nov 19, Quill). There are 21 cases, each on 10 deals, 209 in all
(the converging misleading case found 9 deals in its seed range). Made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. See the README for how
each case is built and what each column means. Town movement is in points: one point is
0.01 of suspicion, and listeners start at 25.

**Changes since the last baseline (b856819).** Only four cases moved, true and misleading:

- **The Warden's guard** moves the town +3.1, up from +2.3, and the innocent twin likewise.
  Lantern's #306 reads a Warden's guard with its night, so the listeners now join the
  guard to the sighting. The juror is unchanged (2.23).
- **The player's vigil at a kill** moves the town +16.1, up from +15.8, and the juror's
  strength rises from 2.71 to 2.75. This is from #300: a vigil now sees only who leaves
  home on its block.

Every other row is identical.

| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |
|---|---|---|---|---|---|---|
| pile | 10 | weak 10 | 1.57 | +5.2 (+2.5 to +12.0) | 100% | 80% |
| kill_sighting | 10 | moderate 10 | 3.79 | +14.3 (+11.6 to +20.3) | 100% | 100% |
| vigil_kill | 10 | weak 10 | 2.75 | +16.1 (+12.6 to +18.3) | 100% | 0% |
| alibi_sighting | 10 | moderate 10 | 3.78 | +5.2 (+3.3 to +9.4) | 100% | 0% |
| converging | 10 | weak 10 | 1.93 | +12.1 (+10.1 to +14.6) | 100% | 0% |
| impossible | 10 | strong 10 | 2740.43 | +59.1 (+54.7 to +63.5) | 100% | 100% |
| double_claim | 10 | weak 10 | 2.95 | +22.8 (+17.3 to +29.3) | 100% | 0% |
| gravedigger | 10 | moderate 10 | 3.37 | +20.0 (+15.0 to +26.6) | 100% | 90% |
| lamp_alibis | 10 | weak 10 | 2.23 | +18.2 (+12.1 to +23.7) | 100% | 0% |
| nw_nobody | 10 | none 8, weak 2 | 1.39 | -3.0 (-6.1 to +2.7) | 20% | 0% |
| guard | 10 | weak 10 | 2.23 | +3.1 (+2.0 to +6.4) | 100% | 50% |
| pile_innocent | 10 | weak 10 | 1.57 | +5.7 (+0.5 to +13.4) | 90% | 80% |
| kill_sighting_innocent | 10 | moderate 10 | 3.79 | +14.7 (+9.1 to +21.0) | 100% | 90% |
| vigil_kill_innocent | 10 | weak 10 | 2.67 | +15.9 (+10.3 to +17.6) | 100% | 0% |
| alibi_sighting_innocent | 10 | moderate 10 | 3.78 | +5.4 (+3.3 to +10.9) | 100% | 10% |
| converging_innocent | 9 | weak 9 | 1.93 | +10.7 (+8.3 to +14.3) | 100% | 56% |
| double_claim_innocent | 10 | weak 10 | 2.95 | +21.8 (+18.4 to +29.0) | 100% | 0% |
| gravedigger_innocent | 10 | moderate 10 | 3.37 | +19.1 (+7.2 to +30.0) | 100% | 80% |
| lamp_alibis_innocent | 10 | weak 10 | 2.23 | +20.0 (+17.2 to +24.1) | 100% | 0% |
| nw_nobody_innocent | 10 | none 9, weak 1 | 1.42 | -3.5 (-7.6 to +3.6) | 10% | 10% |
| guard_innocent | 10 | weak 10 | 2.25 | +3.1 (+0.8 to +5.7) | 90% | 40% |

Town movement by the juror's badge, true cases (the subject is evil):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 8 | -4.3 | -4.5 | -6.1 to -2.7 | nw_nobody 8 |
| weak | 62 | +12.6 | +13.1 | +1.2 to +29.3 | pile 10, vigil_kill 10, converging 10, double_claim 10, lamp_alibis 10, nw_nobody 2, guard 10 |
| moderate | 30 | +13.2 | +13.6 | +3.3 to +26.6 | kill_sighting 10, alibi_sighting 10, gravedigger 10 |
| strong | 10 | +59.1 | +59.1 | +54.7 to +63.5 | impossible 10 |

Town movement by the juror's badge, misleading cases (the subject is innocent):

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 9 | -3.4 | -4.5 | -7.6 to +3.6 | nw_nobody_innocent 9 |
| weak | 60 | +12.6 | +13.9 | -4.6 to +29.0 | pile_innocent 10, vigil_kill_innocent 10, converging_innocent 9, double_claim_innocent 10, lamp_alibis_innocent 10, nw_nobody_innocent 1, guard_innocent 10 |
| moderate | 30 | +13.1 | +12.4 | +3.3 to +30.0 | kill_sighting_innocent 10, alibi_sighting_innocent 10, gravedigger_innocent 10 |

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
