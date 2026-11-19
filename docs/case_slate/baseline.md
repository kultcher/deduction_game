# Case slate: baseline report

Built from main at a990916 (Nov 19, Quill). It has 11 cases on 10 deals each, 110 in all,
and a second run reproduced every row. It was made with
`python3 tools/case_slate_report.py docs/case_slate/baseline.jsonl`. See the README for
how each case is built and what each column means. Town movement is in points: one point
is 0.01 of suspicion, and listeners start at 25.

| Case | n | Juror's badges | Strength | Town, mean (range) | Sign | Category |
|---|---|---|---|---|---|---|
| pile | 10 | weak 10 | 1.57 | +5.2 (+2.5 to +12.0) | 100% | 80% |
| kill_sighting | 10 | moderate 10 | 3.79 | +14.3 (+11.6 to +20.3) | 100% | 100% |
| vigil_kill | 10 | weak 10 | 2.71 | +15.8 (+12.2 to +18.1) | 100% | 0% |
| alibi_sighting | 10 | moderate 10 | 3.78 | +5.2 (+3.3 to +9.4) | 100% | 0% |
| converging | 10 | weak 10 | 1.93 | +12.1 (+10.1 to +14.6) | 100% | 0% |
| impossible | 10 | strong 10 | 2740.43 | +59.1 (+54.7 to +63.5) | 100% | 100% |
| double_claim | 10 | weak 10 | 2.95 | +22.8 (+17.3 to +29.3) | 100% | 0% |
| gravedigger | 10 | moderate 10 | 3.37 | +20.0 (+15.0 to +26.6) | 100% | 90% |
| lamp_alibis | 10 | weak 10 | 2.23 | +18.2 (+12.1 to +23.7) | 100% | 0% |
| nw_nobody | 10 | none 8, weak 2 | 1.39 | -3.0 (-6.1 to +2.7) | 20% | 0% |
| guard | 10 | weak 10 | 2.23 | +2.3 (+1.2 to +5.1) | 100% | 10% |

Town movement by the juror's badge, across the slate:

| Badge | Cases | Town, mean | Median | Range | Cases by name |
|---|---|---|---|---|---|
| none | 8 | -4.3 | -4.5 | -6.1 to -2.7 | nw_nobody 8 |
| weak | 62 | +12.4 | +13.1 | +1.2 to +29.3 | pile 10, vigil_kill 10, converging 10, double_claim 10, lamp_alibis 10, nw_nobody 2, guard 10 |
| moderate | 30 | +13.2 | +13.6 | +3.3 to +26.6 | kill_sighting 10, alibi_sighting 10, gravedigger 10 |
| strong | 10 | +59.1 | +59.1 | +54.7 to +63.5 | impossible 10 |

Town bands used for category agreement (points): strong from +25, moderate from +10, weak from +3, none from -2, contradicts below.

## What it shows

- **At the ends, the badge and the town agree.**
  - The impossible reading is the only Strong case, and it moves the town about +59.
  - The Night Watch "nobody" chain gets no badge, and it moves the town slightly away
    from the subject (about −3). But the juror still leans slightly toward the premise
    (1.39), so on direction they agree in only 2 of the 10 cases.
- **In the middle, the badge doesn't separate how far the town moves.** Weak cases move it
  about +12 on average, Moderate cases about +13. Each badge spans most of the range:
  Weak from +1 to +29, Moderate from +3 to +27.
- **The juror rates these lower than the town takes them:**
  - the double claim (Weak; the town moves +23)
  - the Lamplighter count with the alibis (Weak, +18)
  - the player's own vigil on a kill night (Weak, +16)
  - the converging Seer and Dowser readings (Weak, +12)

  The Lamplighter case is the under-count the juror fix addresses.
- **The juror rates these higher than the town takes them:**
  - the alibi caught out (Moderate; the town moves +5)
  - the Warden's guard (Weak, +2). The town never joins the guard to the sighting: Warden
    reports aren't among the night gifts the connections read. Lantern is fixing that.
- **The control,** two sightings, is Weak and moves the town about +5.

Not measured here:

- one build only;
- the 10-NPC town only;
- listeners at a single credibility, 0.7;
- cases that mislead (every case here is true);
- what the town does after a case (votes, nominations).
