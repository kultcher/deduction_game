# 2026-11-17, Claude-Beadle: fabrication check fixes from Steward's report (claude/beadle-fabcheck-fixes)

**Base:** main 19d5771. **Status:** PR open. Golden is identical to `baseline_3ef0e2f`, so
this needs no golden-queue slot. **Next actor:** Codex, then Bailiff. Michael reviews the
new reveal note's wording (draft sent to Herald and Seneschal).

## What changed and why (docs/maintenance/2026-11-17.md, A1-A3)

- **A1, an impossible public record blocked every lie:**
  - **Before:** when the shared readings already fit no world before the new lie,
    `FabricationCheck.assess` scored every reading, and every alternative, as the worst
    possible self-incrimination. The liar held all its readings back for as long as the
    record stayed impossible.
  - **After:** that case now counts as "can't judge", and the lie goes out as it did before
    the check existed. A lie that itself can't stand beside the record still scores as the
    worst case. The arithmetic is in a new `lift_of`, so it can be tested directly.
- **A2, the reveal listed lies nobody heard:**
  - **Before:** a reading held back was logged as `fake_info`, the list the end-of-game
    reveal uses. Its later release, possibly reworked, was never logged there. So the
    reveal showed the version nobody heard and left out the one they did.
  - **After:** a held reading is logged as `fake_info_held` (still in the dev log, but not
    in the reveal). Its release logs the version actually told as `fake_info`.
- **A3, raw ids in the reveal:**
  - **Before:** a reworked reading's reason was the alternative's own note, for example
    `names ["n3","n7"] instead`. That replaced the motive and printed raw ids.
  - **After:** the reading keeps the motive it was made for, plus a note naming who the
    first version would have pointed at: "...; its first version would have pointed the
    town at Greta, so it told this one instead". This is draft wording for Michael.
  - `vet`'s own "lie" think lines, which the reveal also prints, now use names, not ids.

## Measured

- `test_fabrication_check`: 105 checks, all passing.
  - New checks cover `lift_of` (impossible before, impossible after, ordinary) and the
    reworked reason (named, keeps its motive).
  - A played-games check: in 8 passive 7-NPC games to day 4, 3 fabrications were listed,
    each one of the liar's readings as told. None was reworked in those games.
- Also passing: test_evil_owned_lie, test_nightwatch_bluff_teammates, test_evidence_cards,
  test_evil_play, test_relay_bluff.
- Golden: identical on all 5 seeds.
- **Not measured:** how often an impossible public record occurs in play, or how many held
  readings A1 frees.

## Not done here

- Raw ids remain in many bluff motives, the reason each fabrication was made (for
  example "the dead Seer n3 'cleared' the demon n7", in `generate_bluff_reading` across
  `sim/roles/*.gd`). The reveal prints those too. That is a wording pass (names, and
  Michael's register), sent to Herald and Seneschal as a list.
