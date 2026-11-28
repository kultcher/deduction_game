# Case board pans past the Workshop sheet (Michael's Nov 28 item 1)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open, zero drift (UI only)
- **Next actor:** Bailiff (review, merge)

## What changed

- **Item 1 (Michael, Nov 28, via Seneschal):** with the Workshop sheet pulled out, the case board clamped its pan as if its whole width were visible. The sheet hid the latest columns: on day 3 you couldn't reach the day 3 evening.
  - I took the cleaner of the two routes Seneschal offered. The board now knows how much of its right side the sheet covers (`board_view.right_cover`, set by `case_view._sync_board_cover` whenever the sheet moves or resizes).
  - The pan clamp, the day/whole/selection fits and the day plaque's "day in view" all use the uncovered part.
  - A collapsed sheet covers only its handle. A fullscreen Workshop hands the board its full width back, since the board is hidden behind it.
  - Drawing still uses the whole board, so cards keep sliding under the sheet as before.
- **Flaky tests:** `test_day_plaque` could pick an NPC already busy talking. `test_audit_ui`'s new case could open with an approach that sets its own stage. Both are random quick-start cases, and they failed CI on #571 by chance. The same fix is on #571 (commit 2fc87cb7), so the two branches merge cleanly.

## Measured

- New suite `tools/test_nov28_ui.gd` (in the fast list), 15 checks at 1280×800 and 1920×1080, on a day-3 case (seed 54875, 10 NPCs):
  - the old clamp left the latest column under the sheet (696 px against a visible edge at 504 at 1280×800);
  - panned fully right, the latest column now clears the sheet;
  - "fit day" keeps today's evening clear;
  - the plaque reads the day in view;
  - collapse and fullscreen both work.
- Checked by eye at 1280×800: the day 3 columns sit beside a 60% sheet.
- Suites run: `test_nov28_ui`, `test_day_plaque` (6 repeat runs), `test_audit_ui` (18 repeat runs), `test_workshop_pan`, `test_workshop_ui_selection`, `test_ui`.
- Golden: not captured. The change is UI only and the simulation is untouched.

## Not in this PR

- **Item 2 (Psychologist line):** it moves golden, so it goes into #576, which already re-baselines. That avoids queueing a second re-baseline.
