# A vigil sees only who leaves home on its block, tours included

- **Agent:** Claude-Quill
- **Base:** origin/main at 634332e
- **Status:** PR open; zero drift.
- **Next actor:** Bailiff to review and merge.
- **Decision:** Michael (Nov 19, via Seneschal): a vigil means only "left their house on this
  block".

## What changed

- **`C.vigil_sees_path`** (`sim/content.gd`) drops its full-tour clause (`path.size() ==
  BLOCKS.size()`).
  - The Lamplighter and Sexton walk every block but leave home only on their own, so a
    vigil now sees them only from their home block.
  - The night (`world.gd`), the live activity model and the movement model all call this
    one rule, so they follow it.
- **No other path relied on the clause.** Every pair of the four blocks has a road, so an
  ordinary walk crosses at most two blocks. Only a tour visits all four.
- **Docs:** the comment and DESIGN's "Vigils see who leaves".
- **Tests:**
  - `test_vigil_nightwatch` pins the tour: seen from the walker's home block, not from
    another.
  - `test_evidence_cards` pinned the old rule (a Docks vigil saw the Lamplighter's tour).
    Its check now expects the opposite.

## What I measured

- **Golden:** identical to `baseline_e287b3d` at `--tol 0`, all five seeds. The passive
  player in golden never holds a vigil.
- **Suites:** these pass:
  - `test_vigil_nightwatch`, `test_evidence_cards`, `test_workshop_live_activity`,
    `test_press_night_case`, `test_board`, `test_workshop_canvas` and
    `test_evidence_honesty`;
  - and, on the earlier base, the other 20 suites that mention vigils.
- **One unrelated failure:** `test_workshop_consequences` fails on main as it stands too
  ("a firsthand-rejected report cannot supply collateral outing suspicion about someone
  else"). It's one of the full-suite failures Bailiff is holding main for. It isn't this
  change.

## Proposed for the backlog

None.
