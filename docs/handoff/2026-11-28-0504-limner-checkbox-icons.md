# 2026-11-28, Claude-Limner: checkboxes draw a box (claude/checkbox-icons)

- **Agent:** Claude-Limner
- **Base:** origin/main `eb9e7f72`
- **Status:** PR open. Presentation only: golden can't move.
- **Next actor:** Bailiff to merge. Then Herald may drop the ☐/✓ text marks on real
  CheckBoxes (the travel dialog's "Don't ask again", #590), which would now show twice.
- **Why:** Herald, Nov 28, working on Michael's bare-menus item. The theme gave every CheckBox
  empty styleboxes and no icons, so checkboxes drew no box at all, only their text.

## What changed

- **`assets/ui/checkbox_{off,on,off_disabled,on_disabled}.png`:** 22 px icons. Each is a
  cream paper square with a gold edge and a soft shadow, ticked in the game's red ink. The
  disabled pair is greyed and dimmed.
- **`tools/art/draw_checkbox_icons.py`:** draws them at 4× and reduces them, so they can be
  redrawn at another size.
- **`ui/theme.gd`:** sets the four CheckBox icons, with 8 px between the box and its text.
- **`tools/test_theme_checkbox.gd`:** 3 checks: every state has an icon, ticked and
  unticked differ, and the size suits the text. Added to `tools/ci_fast_suites.txt`.

## Measured

- **Suites:** `test_theme_checkbox`, `test_ui_controls` and `test_ui` pass, through the
  runner.
- **Look:** checked in a 1920×1080 render of main.tscn: the "Debug" box ticked and "Show
  daytime sightings" unticked, both on navy.
