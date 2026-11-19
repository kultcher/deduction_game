# The case benchmark slate

**Claude-Quill**, Nov 19. Base: main a990916. Branch `claude/case-slate`.
Status: open PR. Next actor: Bailiff (review and merge), then Quill (the juror fix plan,
measured against this slate).

## What changed and why

Michael (Nov 19, via Seneschal) asked for the chain probe to become a kept, reusable
slate of standard constructed cases: "like golden: a script plus a stored baseline
report, NOT a CI suite". It should cover the common evidence combinations and several
cases that are "strong on paper". This PR adds:

- `tools/case_slate.gd`: builds 11 cases on real deals (10 NPCs), each judged by the Test
  juror and then presented to the town. It writes one row per case: the badge, its
  strength, and how far the town moved.
- `tools/case_slate_report.py`: the report. It shows each case's badges, strength, the
  town's mean and range, and sign and category agreement, plus the town's movement by
  badge across the slate. Given a second file, it compares the run against that baseline.
- `docs/case_slate/`:
  - `README.md`: how to run it, what each case is, and how to add one.
  - `baseline.jsonl`: the raw rows.
  - `baseline.md`: the first report, and what it shows.
- `BACKLOG.md`: the item, as Michael asked. It is marked built.

There is no game code change, so golden doesn't move. The slate is not in CI.

## Measured

There are 110 cases: 11 kinds on 10 deals each. A second full run reproduced every row.
The full report is in `docs/case_slate/baseline.md`. In short:

- The impossible reading is Strong and moves the town about +59. The Night Watch "nobody"
  chain gets no badge and moves the town slightly away from the subject.
- In between, Weak and Moderate cases move the town about the same: +12 and +13 points on
  average, each spanning most of the range.
- The juror rates the double claim, the Lamplighter count, the player's own vigil at a kill
  and the converging readings lower than the town takes them.
- It rates the caught-out alibi and the Warden's guard higher than the town takes them.
  The guard is Lantern's fix: Warden reports aren't joined in the connections.

## Notes for whoever runs it next

- Keep each card in its real shape and timing. The first run had the Dowser reading at
  night, and the juror reported the case as "not ready" (the Dowser reads by day). The
  slate now prints and records the juror's issues for any case that isn't ready.
- Every case here is true. A slate of misleading cases (the same chains about an innocent
  bystander) would be the natural next set.

## Proposed for the backlog

- Misleading cases on the slate: the same chains about an innocent subject, so a change can
  be checked for making the town easier to mislead as well as easier to convince.
  Suggested owner Quill, with Lantern; tag [open]. Sent to Seneschal.
