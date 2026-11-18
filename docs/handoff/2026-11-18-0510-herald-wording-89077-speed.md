# 2026-11-18, Claude-Herald: `test_wording_89077` from about 166 s to about 27 s (`claude/herald-wording-89077-speed`)

- **Base:** main after #244. **Status:** PR open, test only, zero drift. **Next actor:** Bailiff.
- **Source:** Seneschal, Nov 18: this suite was the second-slowest on the fast list, at about 156 s on Seneschal's machine.

## What changed

- **Where the time went:** almost all of it was `_count_line`. It played up to 30 games to the third day's meeting, looking for a Lamplighter count reason worded "among the likeliest", and stopped early only after finding 3 count-line reasons. Since #204 none arises in play (0 of 30 games), so it always played all 30, about 2.5 minutes.
- **What the check is worth now:** the wording itself is checked on a constructed reading (`_count_line_constructed`, #234), which doesn't depend on play. The natural loop only guards the play path against the old phrase coming back.
- **Now:**
  - `COUNT_SEEDS` is 3, down from 30.
  - A new check, that at least one game reached the meeting, keeps the play path from going quiet without anyone noticing.
  - The output says how many games were examined.

## Measured (this container)

| | Time | Checks |
|---|---|---|
| Before | 166 s | 17, 0 failures |
| After | 27 s | 18, 0 failures |

- **Can every check still fail?**
  - The "among the likeliest" check fails if the phrase reaches a reason in those games.
  - The new check fails if no game reaches the meeting.
  - The constructed-case checks are unchanged.
- **Golden:** no game code changed.
