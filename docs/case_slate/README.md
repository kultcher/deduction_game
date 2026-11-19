# The case benchmark slate

A kept set of standard constructed cases. Each case is judged by the Test juror (the
canvas's Strong / Moderate / Weak badge) and then presented to the town. Michael asked for
it on Nov 19; Quill owns it, with Lantern. It works like golden: a script, plus a stored
baseline that a later run is compared against. It runs on demand and is not a CI suite.

Run it after any change to the judge, to how listeners weigh a filed case, or to the badge
cut points. Then compare the run with the baseline:

```sh
godot --headless --path . --script res://tools/case_slate.gd -- --out /tmp/slate.jsonl
python3 tools/case_slate_report.py /tmp/slate.jsonl docs/case_slate/baseline.jsonl
```

A full run takes about 30 minutes. `--cases N` sets how many deals each case gets (10 by
default). `--only a,b` runs only the named cases. `--from S` sets the first seed to try.
The run is deterministic: on the same build, it reproduces the baseline exactly.

## How a case is built

- Each case uses a real deal: 10 NPCs, trying seeds from 1 upward.
- Every listener's trust and credibility are set to 0.7, every suspicion is reset to 0.25,
  and the day is set to 3.
- The case's cards are added to the board. The player files the case about its subject,
  citing them, and presents it to every good listener who isn't one of its sources.
- Every gift reading comes from that gift's real, good holder. A deal without one is
  skipped for that case. The one exception is a misleading case's lie, told by a Minion.
- In a true case, the subject is the Demon unless the case says otherwise.
- Each true case has a misleading twin, `<case>_innocent`, except the impossible reading
  and the three Seer cases (seer_twice, vigil_seer, stack), which are built on the real
  Seer's true readings of the Demon and so have no innocent version.
  It's the same chain built about an innocent (the last living good townsperson), as it
  could really arise: an innocent out at night, true readings that name them beside the
  real evil, or a lie told by evil. The juror judges only what's on the board, so a twin
  usually gets its true case's badge. What it measures is how far the town moves against an
  innocent (Michael, Nov 19).

| Case | What the player holds |
|---|---|
| pile | Two sightings of the Demon, by two witnesses, on two nights (the control) |
| kill_sighting | A night-1 killing, plus a witness who saw the Demon on the victim's block that night |
| vigil_kill | A night-1 killing, plus the player's own vigil, which saw the Demon go out from home that night |
| alibi_sighting | The Demon's own "at home on night 1", plus a sighting of them out that night |
| converging | The Seer's "yes" on the Demon and one other, plus the Dowser's "1 evil" among the Demon and a third |
| impossible | The Demon's Gravedigger reading of a hanging that never happened |
| double_claim | The Demon claims a gift its real holder also claims |
| gravedigger | A Minion hanged on day 2, plus the real Gravedigger's reading of the Minion's role (the subject is the Minion) |
| lamp_alibis | The Lamplighter's "1 other out", plus a home alibi from everyone else alive (premise: suspicious) |
| nw_nobody | The Night Watch "saw nobody" on the Demon's block, plus a sighting of the Demon there |
| guard | A quiet night: a sighting of the Demon near a guarded door, plus the Warden's guard report |
| seer_twice | The Seer's "yes" on the Demon and one other on night 1, and on the Demon and a second other on night 2 |
| vigil_seer | A night-1 killing, the player's vigil seeing the Demon go out that night, plus the Seer's "yes" on the Demon and one other |
| stack | The vigil at the kill, a witness's sighting of the Demon on the victim's block, plus the Seer's "yes" twice (built to reach the Strong tier) |

The misleading twins (the subject is the innocent):

| Case | What the player holds |
|---|---|
| pile_innocent | Two sightings of the innocent out at night |
| kill_sighting_innocent | A night-1 killing, plus a sighting of the innocent on the victim's block |
| vigil_kill_innocent | A night-1 killing, plus the player's vigil, which saw the innocent go out |
| alibi_sighting_innocent | The innocent's own "at home", plus a Minion's false sighting of them out |
| converging_innocent | The Seer's "yes" on the innocent and the Demon, plus the Dowser's "1 evil" among the innocent and a Minion |
| double_claim_innocent | The innocent, the real holder, and the Demon both claim the innocent's gift |
| gravedigger_innocent | The innocent hanged on day 2, plus a Minion's claimed Gravedigger reading that they were a Minion |
| lamp_alibis_innocent | The Lamplighter's "1 other out", plus everyone else's home alibi, the Demon's false (premise: suspicious) |
| nw_nobody_innocent | The Night Watch "saw nobody" on the innocent's block, plus a Minion's false sighting of them there |
| guard_innocent | A quiet night: a sighting of the innocent near a guarded door, plus the Warden's guard report |

## What the report shows

Town movement is in points: one point is 0.01 of a listener's suspicion of the subject,
averaged over the listeners.

- **Juror's badges:** the badge each case got, and how often.
- **Strength:** the juror's strength, as a geometric mean. Since the juror fix (Nov 19), it
  is how far an average listener's chance of the premise moves, as an odds ratio, against
  a town that hasn't heard the case's cards. The badge is set by this number: Weak from 1.5,
  Moderate from 3, Strong from 10, until Michael sets the new cut points.
- **Chance before → after** (the rows' `chance_before` and `chance`): that listener's
  chance of the premise, and whether the subject becomes their top suspect (`top`,
  `margin`). These feed the fourth tier's measure.
- **Town:** the mean movement, and its range across the deals.
- **Sign:** how often the juror and the town point the same way.
- **Category:** how often the badge matches the town's own band. The bands are the
  report's own provisional reading of how far the town moved, not game numbers: Strong
  from +25, Moderate from +10, Weak from +3, none from −2.
- **By badge:** the town's movement for each badge, for the true cases and the misleading
  ones separately. These are the tables for revisiting the cut points.

A case the juror can't judge is reported as "not ready", and the row carries the juror's
issues. On the slate, that means the case or the judge is broken.

## Adding a case

Add a case to `CASES` and to the `match` in `tools/case_slate.gd`, and to `ORDER` in the
report script. Add its row to the table above. Then re-run and commit the new baseline,
saying what changed. Keep each case to evidence a player could really hold, with each
card in its real shape and timing. For example, the Dowser reads by day, so a night-timed
Dowser card is "not ready".

## Current baseline

`baseline.jsonl`: built on claude/slate-strong (main at 4cf1d73, Nov 19, Quill). It adds
seer_twice, vigil_seer and stack, 30 new rows. Of the 209 earlier rows, 22 changed, and
only in the town's movement, by at most 0.3 of a point; no badge, strength or category
moved. See `baseline.md`.
