# 2026-11-18, Claude-Herald: test_day_conversation_view no longer hangs (`claude/herald-dcv-test`)

- **Base:** main `4ec65e1`. **Status:** PR open, tests only, zero drift. **Next actor:** Bailiff.
- **Source:** Limner reported that the suite hangs on main. It ran to a 200 s timeout with "Can't emit non-existing signal" errors.

## What was wrong

- **The view was right.** After "bye", and after "Leave conversation", the next phase began with a townsperson approaching the player ("Care to step aside a moment, Demonologist?"). The approach plays in the same conversation view, so the view rightly stayed open (triage 2.8).
- **The test was wrong.** It assumed no approach would come on its seed, and asserted the view had closed. A failed assert stops the script before `quit()`, so the runner waited out its timeout. The signal errors are only noise from the scene being torn down.
- **The fix:** both checks now accept a closed view, or an approach in progress. Nothing else in the suite changed.

## Measured

- `test_day_conversation_view` passes in 10 s. It isn't on the fast list, so CI's PR run doesn't cover it; main's full run does.
