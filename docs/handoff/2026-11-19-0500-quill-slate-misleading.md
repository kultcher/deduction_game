# Misleading cases on the case slate

**Claude-Quill**, Nov 19. Base: main b856819. Branch `claude/slate-misleading`.
Status: open PR. Next actor: Bailiff (review and merge). Then Quill, who re-runs the slate
after the juror fix and proposes four badge cut points.

## What changed and why

Michael approved misleading cases for the slate on Nov 19, through Seneschal, ideally
before the juror re-run so it covers both kinds. Each true case except the impossible
reading now has a twin, `<case>_innocent`. The twin is the same chain built about an
innocent (the last living good townsperson), as it could really arise:

- an innocent out at night;
- true readings that name them beside the real evil;
- a lie told by evil (a Minion's false sighting, a Minion bluffing the Gravedigger, or the
  Demon's false alibi).

The changes:

- `tools/case_slate.gd`: ten misleading cases. The true cases are built exactly as before,
  and their rows are identical to the first baseline.
- `tools/case_slate_report.py`: lists the twins after the true cases, and gives the
  by-badge table for each kind separately.
- `docs/case_slate/`: the README (the twins, and the one exception to "readings from the
  real holder", which is a Minion's lie), the new `baseline.jsonl` (209 rows) and
  `baseline.md`.
- `BACKLOG.md`: the item, [decided] and marked built. The slate item's "next" now reflects
  Michael's juror decision.

No game code changes, so golden doesn't move.

## Measured

There are 209 cases on main b856819: 110 true and 99 misleading (the converging twin found
9 deals). The true rows are identical to the first baseline. A second run of the
misleading cases reproduced every row.

- **On the same evidence, the town moves as far against an innocent as against the
  Demon:** Weak cases about +12, Moderate cases about +13, either way. The juror judges
  only the board, so each twin usually gets its true case's badge.
- **A lie from evil carries as much weight as a true account.** Examples: a Minion's false
  sighting (+5), a Minion's bluffed Gravedigger reading (+19), and the Demon's false alibi
  in the Lamplighter case (+20).
- **A double claim filed against the real holder** moves the town as much as one filed
  against the bluffer (+22 against +23).

## Proposed for the backlog

None.
