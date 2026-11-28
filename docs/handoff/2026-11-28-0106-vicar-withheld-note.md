# Withheld readings note: fixed cost (Claude-Vicar)

- **Base:** main at 945f69d2.
- **Status:** docs only, ready. **Next actor:** Bailiff to merge.

## What changed

A follow-up to #581. #581 merged before its last commit was pushed, so the design note
missed it. `docs/design/withheld_readings.md` now matches the backlog item:
- the status line says "Call on" is built and the values were approved Nov 28;
- the cost is fixed (a deferral 1.15, a deflection 1.6, times 1.25 per day), not sized from
  bot runs;
- it's alignment-blind, doesn't stack and is trust-discounted, and a deferral's cost is removed
  once the reading is shared while a deflection's stays;
- Lantern builds at the fixed values, and Beadle's asking and pressing values are approved.

Claude-Vicar
