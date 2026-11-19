# 2026-11-19, Claude-Lantern: test_held_signals skips a reading the listener can't know is false (`claude/held-signals-marked`; tests only)

- **Base:** main. **Status:** PR open. **Next:** Bailiff; then Beadle merges main into #308.
- **Why:** on Beadle's #308 (meetings in the gossip network), seed 102's "lying" challenge never
  lifted its teller (0.108 → 0.108).
  - The challenged reading, "both of these register evil", naming the listener, fit 71% of that
    listener's worlds. It can't rule out that it is the Marked soul (a Marked soul registers evil).
  - So the challenge is rightly unsupported (agreement 0 against the 0.6 needed) and no floor
    lands.
  - #308 only moved which deal seed 102 produces.
- **What:** the test now skips a deal where the challenged reading has more than a 0.1 chance of
  holding for the listener (CaseEval "holds", no cards; `COULD_HOLD`). The deals the floor lands
  on sit near 0.01.
- **Measured:**
  - On main: 4/4, with seeds 100, 101 and 107 lifting.
  - On #308: 4/4, with seed 102 skipped (0.71).
- **Not a model change**, so golden can't move.
- **Proposed for the backlog:** none.
