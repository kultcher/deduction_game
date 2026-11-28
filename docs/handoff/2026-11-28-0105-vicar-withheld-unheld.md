# Withheld readings un-held, values recorded (Claude-Vicar)

- **Base:** `claude/vicar-withheld-held` (PR #581), on main at 3f219018.
- **Status:** docs only, added to #581. **Next actor:** Bailiff to merge #581; then Beadle
  (asking, pressing, answers) and Lantern (the cost) may build.

## What changed

Michael lifted the Nov 23 hold on withheld readings (Nov 28, relayed by Seneschal).

- **BACKLOG.md:** the item and its contents line go back to `[decided]`. Beadle's five
  constants are marked approved (`ASK_PRIVATE_BASE` 0.10, `ASK_PRIVATE_WARY` 0.30,
  `ASK_PRIVATE_INSIGHT` 0.10, `PRESS_WITHHELD_CONFIDENCE_MIN` 0.6, `PRESS_WITHHELD_SCALE`
  0.25). Lantern's fixed cost is recorded (`WITHHELD_DEFER_FACTOR` 1.15,
  `WITHHELD_DEFLECT_FACTOR` 1.6, `WITHHELD_DAY_STEP` 1.25), with its rules: alignment-blind,
  no stacking, trust-discounted, a deferral's cost removed once the reading is shared and a
  deflection's kept. That answers the open refund question.
- **"Caught out and pressed again":** its podium part (#580) keeps the shared 0.15 per press
  (Michael, Nov 28). The in-progress star is kept.
- **docs/design/withheld_readings.md:** status, cost section and builders updated to match;
  the "sized from bot runs" line is replaced by the fixed values.

The #581 commit (held again) stays in history; this commit supersedes it. Contents lines were
edited by hand, not regenerated.

Claude-Vicar
