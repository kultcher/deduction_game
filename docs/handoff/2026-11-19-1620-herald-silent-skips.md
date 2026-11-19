# Herald: silent skips in my suites (Steward's Nov 19 sweep, E1b)

- **Signed:** Claude-Herald
- **Base:** main at 4cf1d73.
- **Status:** PR open, test-only.
- **Next actor:** Bailiff.

## What changed
Michael's one-off sweep found places where a check quietly didn't run when a seed stopped giving the situation it needs. These are mine.

- **Two were really being skipped, and now run:**
  - **`test_buildings_tavern_town_hall`:** the dotted-marker, CLI "?" and no-merge checks on a tavern sighting rumour. The evening's draw had no sighting rumour, so they never ran. A stand-in rumour in the gossip's own shape now fills in, as the suite's later Workshop checks already did. All 34 checks pass.
  - **`test_workshop_regressions`:** the Constance reveal checks. Seed 42 no longer deals her. The suite now looks for a deal that does, instead of naming a seed. Running again, one check failed: it expected her old "properly" line, which her voice no longer has. It now reads her current `private_reveal` from the voice pack. `test_evil_play`'s sibling check, which looked for the absence of that same old phrase, now checks for her early reveal instead.
- **Preconditions now asserted,** so a skip fails loudly:
  - test_dialogue_voices (someone out to talk to, seed 5606)
  - test_evil_play (Constance and Greta dealt)
  - test_ui (a townsperson's card on the board)
  - test_playtest_89077 (some voice has a "my own eyes" opener)
  - test_dialogue_fixes_testimony (the living-target hint counts as live; was test_playtest_13910_dialogue)
- **Checks that couldn't fail:**
  - `test_ui`'s "new case button runs … or true" now checks that the seed really changes.
  - `test_day_conversation_view` used 61 bare `assert()`s, so a failure hung the run. They're now counted checks with FAIL lines and a non-zero exit, 228 checks per run.
- **`test_wording_89077`'s empty play path is dropped (Bailiff's call, Nov 19).** It played 3 games on every PR and checked a list that's always empty. The hand-built count-line case stays as the real check. If the play path comes back, it should assert that the situation arose.
- **Not done:** the two suggested suite merges (hint cards with hint families, drag and pan with workshop_pan) are left for another PR.

## Measured
- **Suites:** all the touched suites pass: test_dialogue_voices, test_buildings_tavern_town_hall, test_evil_play, test_workshop_regressions, test_ui, test_playtest_89077, test_dialogue_fixes_testimony, test_day_conversation_view and test_wording_89077.
- **Golden:** no game code changed, so it doesn't move.
