# One way around the screens: the breadcrumb row (Michael's Nov 28 item 5)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open, zero drift (UI only)
- **Next actor:** Bailiff (review, merge). Michael has one question (below).

## What changed

- **Item 5 (Michael, Nov 28, via Seneschal):** a row of plaque buttons in the stage's top corner says where you are and lets you step back:
  - **By day:** `Town ▸ <block> ▸ <person>`. The block is the one in close-up, else yours once you've moved, else the conversation's.
  - **At a meeting:** `Town ▸ Meeting ▸ <speaker>`. The speaker crumb shows while someone is on the courtroom stage. Meeting clears the stage, as "Back to the circle" does.
  - The crumb you're on is red and does nothing. The others take you there; in a conversation they show the map and the conversation waits.
  - The row sits top-left of the map or conversation (the day plaque is top centre) and top-right of the meeting circle (the plaque is top-left there). It hides when there's nowhere to step back to, and on the Case board, the New Case screen, cutscenes and the guess window.
- The map's own "◀ Whole town" sign is turned off (`map_view.show_back_sign`). The Town crumb sits where it was.
- **"Speaker":** I built Seneschal's option (a). The crumb marks the speech, and the speech keeps its own pacing. Option (b), leaving a speech paused for the ring, would change the meeting's flow, and Michael hasn't asked for it.
- **Kept for now:** the map's "Return to conversation/meeting" button and the left panel's "Look at the map / Look at conversation" and "Back to the meeting" toggles. They're Michael's earlier controls (`test_map_return`), and they now duplicate a crumb. Retiring them waits for his word.
- Code: `ui/nav_crumbs.gd`, created in `ui/main_layout.gd` and placed each frame by `main._place_nav_crumbs`.
- **Flaky tests:** the same `test_day_plaque` / `test_audit_ui` fix as #571, with identical content.

## Small calls made on Michael's behalf

- The crumbs read "Town" and "Meeting", the block's own name ("Chapel Hill", "Docks"), and the person's name.
- The separator is "▸".
- While someone is speaking, the Town crumb is greyed out with the tooltip "Not while someone is speaking". The meeting keeps the circle up during a speech, so the map can't open then (Codex on #591).
- The duplicates are kept until he says.

## Measured

- New suite `tools/test_nav_crumbs.gd` (15 checks, in the fast list):
  - no row on the whole town before you move;
  - `Town ▸ Docks` in a close-up, and Town zooms out;
  - talking shows `Town ▸ <block> ▸ <person>`; the block crumb shows the block with the talk waiting, the person's crumb brings it back, and Town shows the whole town;
  - the current crumb is pressed;
  - a meeting shows `Town ▸ Meeting`, the map peek marks Town, and a speaker gets their own crumb;
  - during a speech, Town is greyed out and Meeting still works.
- Suites passing: `test_nav_crumbs`, `test_map_return`, `test_day_conversation_view`, `test_conversation_gifts`, `test_control_flow`, `test_ui`, `test_approach_vn`, `test_playtest_ui_nov22`, `test_day_plaque`, `test_audit_ui`.
- Checked by eye at 1280×800 (close-up and conversation) and 1920×1080 (block crumb mid-conversation).
