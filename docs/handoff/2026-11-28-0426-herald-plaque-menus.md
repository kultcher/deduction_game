# Menus open as plaque buttons (Michael's Nov 28 item 4)

- **Agent:** Claude-Herald
- **Base:** main at 6770f32e
- **Status:** PR open, zero drift (UI only)
- **Next actor:** Bailiff (review, merge)

## What changed

- **Item 4 (Michael, Nov 28, via Seneschal):** "More ▾" and the case board's Kinds, People and Places filters were raw text on a grey box. Every menu now opens as a panel of buttons in the game's plaque style, like the dialogue options.
  - Before, only menus with more than eight entries became a button panel (`ui/column_menus.gd`). Every menu goes that way now, and past eight entries it still splits into balanced columns.
  - That panel is a window added to the root, so it didn't inherit the screen's theme. That is why its buttons were the engine's grey boxes. It now takes the theme of the control the menu belongs to (`ColumnMenus.theme_for`).
  - A ticked entry (a filter or "Reduced motion") shows as a pressed, red plaque, with its ✓ kept. Section headings are in the accent colour.
  - Card context menus and option dropdowns get the same look.
- **Limner's style notes (Nov 28), all taken:**
  - Toggles show a box, ☐ or ☑, so an unticked one reads as a setting.
  - The panel has a 2 px gold edge and 10 px inside.
  - An untitled separator now leaves a gap in the column.
  - "Write dev log" and "Exit Game" sit apart at the end of More, each after a separator. Ids are fixed per entry, so the reorder changes nothing else.
- **Closing from code:** `PopupMenu.hide()` left the button panel up, which was there before for long menus too. `ColumnMenus.close(menu)` closes both, and the case board's card menu uses it. A menu closed within a frame of opening no longer gets its panel.
- **Flaky tests:** the same `test_day_plaque` / `test_audit_ui` fix as #571 and #587, with identical content, so they merge cleanly in any order.

## Measured

- New suite `tools/test_plaque_menus.gd` (7 checks, in the fast list):
  - More opens as a themed panel with one button per entry, and "Reduced motion" shows its state;
  - the People filter opens as buttons too, pressing one ticks it red, and an unticked one shows ☐.
- Suites run, all passing: `test_plaque_menus`, `test_ui`, `test_ui_controls`, `test_audit_ui`, `test_day_plaque`, `test_playtest_ui_nov22`, `test_workshop_live_ui`, `test_daily_guess`, `test_workshop_ui_selection`, `test_mistake_signpost`.
- Checked by eye at 1280×800 and 1920×1080: More, Kinds and People.

## Not done / for later

- **Art:** Limner looked at it in a real render. It needs no new art.
- **Raw kind ids:** the Kinds filter lists kinds by their internal ids ("scorched_sigil"). I didn't change it here; it's an easy follow-up if wanted.
