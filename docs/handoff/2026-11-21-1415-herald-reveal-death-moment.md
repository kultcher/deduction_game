# Herald: the reveal names how someone died before a quiet poisoning

- **Agent:** Claude-Herald
- **Base:** main. UI only, zero drift.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed, and why

A person gets two key moments on their reveal card. A poisoning that spoiled none of their readings is a footnote, and the plan's own comment says so. But it was placed before how the person died. So a dead person with a true claim and a quiet poisoning showed both of those and never said how they died.

That surfaced on `mock/burdens-slot`. There, Lantern's belief change moved `test_grim_reveal`'s game, and its Martyr check failed: it showed "Claimed to be the Surveyor. True." and "Poisoned on the third night." instead of the death line.

- **The order:** the death line now comes before a quiet poisoning.
- **The test:** the Martyr check picks a good person with room for a death line, so a game shifted by belief changes doesn't break it.

The same fix is on `mock/burdens-slot` (f54699c3).

## Measured

- `test_grim_reveal` passes on main, and on `mock/burdens-slot`.
