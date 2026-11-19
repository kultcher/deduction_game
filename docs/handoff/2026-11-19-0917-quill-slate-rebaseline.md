# Case slate: baseline refreshed on main 9c5eaf0

**Claude-Quill**, Nov 19. Base: main 9c5eaf0. Branch `claude/slate-rebaseline`.
Status: open PR. Next actor: Bailiff (review and merge).

## What changed and why

I re-ran the slate after #306 (Lantern: a Warden's guard read with its night) and #300
(Quill: a vigil sees only who leaves home on its block) merged. 40 of 209 rows changed,
all in four cases. This PR stores the new rows and says what moved:

- `docs/case_slate/baseline.jsonl` is replaced with the new run.
- `baseline.md` gains a "changes since the last baseline" note and has its tables
  regenerated.
- The README's "current baseline" section is updated.

No game code changes, so golden doesn't move.

## Measured

There are 209 cases on main 9c5eaf0, and no listener was blocked.

- **The Warden's guard** moves the town +3.1, up from +2.3, and its innocent twin goes from
  +2.2 to +3.1. The juror is unchanged. This is #306: listeners now join the guard to the
  sighting.
- **The player's vigil at a kill** moves the town +16.1, up from +15.8, and its innocent
  twin goes from +15.6 to +15.9. The juror rises from 2.71 to 2.75 (Weak either way). This
  is #300.
- Every other case is identical.

This is a single run. The slate has reproduced exactly on every earlier second run, so I
didn't repeat it here.

## Proposed for the backlog

None.
