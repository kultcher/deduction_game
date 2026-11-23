# Herald: the daily guess uses PortraitFx.square()

- **Agent:** Claude-Herald
- **Base:** main at the merge of #537. UI only, zero drift.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

`ui/daily_guess.gd` had its own copy of the square crop for its circle portraits, kept in its own cache. Limner's `PortraitFx.square()` (#530) does the same crop, from the same spot near the top and with the same 4% offset, and keeps its own cache. `_round_portrait` now calls it, and the copy and its cache are gone. I promised Limner this on #530.

Nothing on screen changes: the crop is the same.

## Measured

test_daily_guess, test_grim_reveal and test_ui_controls pass.
