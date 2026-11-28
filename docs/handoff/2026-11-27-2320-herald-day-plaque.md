# Herald: the Day/Phase plaque on every screen, and the shorter whole-town hint

- **Agent:** Claude-Herald
- **Base:** main after #556. UI only, zero drift.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

These are Michael's answers on my look at Argon's #556 (Nov 27, via Seneschal).

- **The Day/Phase plaque is on every screen.** #556 drew it inside the map stage, so it vanished at the town meeting (whose meeting circle replaces the map), behind conversations, and on the Case board. Its "Town meeting" text was never seen.
  - **Where it lives now:** on the main screen, above the Case board, with no new art and no new text.
  - **Placement:** `main.gd` `_place_day_panel()` sets its position each frame, so it can't cover anything:
    - **The map:** top centre, as #556 had it. A conversation keeps it in the same place: it sits clear of the portrait and the dialogue box.
    - **The meeting:** the circle's top-left corner, because the top seat holds the top centre.
    - **The Case board:** beside "◀ Back to town", because the board's title holds the top centre. `case_view.back_button` is now kept for this.
  - **Hidden:** behind the New Case screen, and before a case exists. The pacing overlay and the headlines still draw above it.
- **The whole-town hint** is now Michael's shorter one: "Examine a block to look closer." In #556's whole-town view, people can't be clicked until you zoom into a block, so the old hint's "or click a person to inspect their profile" was wrong.

## Checked by eye

Screenshots under xvfb at 1920×1080 of the map, a conversation, the Case board and the meeting. The plaque covers nothing on any of them. Probe deleted.

## Measured

- **New suite:** `test_day_plaque`, 9 checks, in the fast list. It covers where the plaque lives, that it shows on all four screens and where, the meeting's "Town meeting", and the hint.
  - It passed 3 times on its own and 5 times under the runner. Its one failure was the first run straight after importing the new script, and I couldn't reproduce it.
- **Also passing:** test_ui, test_ui_controls, test_control_flow, test_map_lighting, test_town_ui, test_meeting_stage, test_playtest_ui_nov22, test_pacing, test_call_on, test_day_conversation_view and test_map_return.
