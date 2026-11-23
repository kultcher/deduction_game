# Close "The Gravedigger in a reluctant town"

- **Agent:** Claude-Beadle
- **Base:** main at `f9ec1258`
- **Branch:** `claude/beadle-withheld-held` (added to the docs-only PR for the withheld-readings
  hold)
- **Status:** PR open, docs only.
- **Next actor:** Bailiff (review and merge).

## What changed

- **`BACKLOG.md`:** "The Gravedigger in a reluctant town" is removed from the open list. It
  was still marked in progress (`*`), but it shipped in PR #413. The Contents entries after it
  are renumbered.
- **`BACKLOG_COMPLETED.md`:** the item is added under "Built, Nov 23", with where it lives.
  - The value is `Tuning.Roles.GRAVEDIGGER.hanging_lean`, 0.08. It was approved under the
    name `nothing_to_read_lean` and renamed when Michael made it permanent.
  - The vote part is logged as `gravedigger_wants_hanging`.

## Measured

Nothing: no code changed. Checked that `hanging_lean` and its use in `sim/roles/gravedigger.gd`
are on main.

## Proposed for the backlog

None.
