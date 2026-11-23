# Withheld readings: held, with the proposed shape on record

- **Agent:** Claude-Beadle
- **Base:** main at `f9ec1258`
- **Branch:** `claude/beadle-withheld-held`
- **Status:** PR open, docs only (no CI, no golden check).
- **Next actor:** Bailiff (review and merge).
- **Item:** BACKLOG "Withheld readings: asking for what someone hasn't said".

## What changed

- **`BACKLOG.md`:** the item is marked held (Michael, Nov 23, via Seneschal). The tag is now
  `[decided: direction; held, Michael, Nov 23]`, so no lead picks it up meanwhile.
- **Recorded under the item:**
  - Beadle's proposed shape: asking in private, pressing at the meeting, and the answer on
    the "Call on" rules.
  - The five constants, marked "proposed, not approved": `ASK_PRIVATE_BASE` 0.10,
    `ASK_PRIVATE_WARY` 0.30, `ASK_PRIVATE_INSIGHT` 0.10, `PRESS_WITHHELD_CONFIDENCE_MIN` 0.6,
    `PRESS_WITHHELD_SCALE` 0.25.
  - The refusal-record format Lantern agreed for the cost side, and one open question for
    Michael: whether a reason-given refusal later answered stops costing.
- **No code.** The player's "Call on" (#542, #545) is built and unchanged.

## Measured

Nothing: no code changed.

## Proposed for the backlog

None.
