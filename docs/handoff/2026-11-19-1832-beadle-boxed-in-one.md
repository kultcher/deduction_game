# The boxed-in liar's "that reading", and the frame-memory reveal in Michael's wording

- **Agent:** Claude-Beadle
- **Base:** main with #339 (`baseline_ee15238`)
- **Branch:** `claude/beadle-boxed-in-one`
- **Status:** PR open. Zero drift.
- **Next actor:** Bailiff (review and merge).
- **Source:** Steward's Nov 19 DEEP report (#328). Herald drafted the lines, and Michael approved
  them on Nov 19, editing Jory's "messed with" to "meddled with".

## What changed

- **The boxed-in liar's line** (`Evil._boxed_in_gift_doubt`, `MindMeeting._say_gift_doubt`).
  - **Before:** it always said "Something seems off about those readings…", even when the reading
    it couldn't tell was its first for that gift.
  - **Now:** if it had told no earlier reading of that gift, it says the new
    `doubt_own_gift_one` line instead. The canonical is "Something seems off about that reading.
    I fear something might have turned my gift."
  - **Voices:** all 15 have Herald's approved set, which takes the voice key count to 252.
  - **Good claimants (#316):** they keep the plural line. They doubt their own readings, and
    don't set the new flag.
- **The frame-memory reveal note (A4).** It now reads "evil fabrication: <motive>. The first
  version would have cleared someone its own earlier readings had pointed at, so it changed the
  story.", which is Michael's approved wording of Herald's draft. #339 had introduced this note
  with the wording "; its first version would have cleared someone…".

## Measured

- **test_gift_doubt** has 2 new checks: its first reading for the gift gets the singular line,
  and with an earlier one told it keeps the plural.
- **test_dialogue_voices:** 252 keys.
- **Also pass:** test_frame_memory, test_evil_play, test_fabrication_check and test_meeting_flow.
- **Golden:** identical to `baseline_ee15238` at `--tol 0`.

## Proposed for the backlog

None.
