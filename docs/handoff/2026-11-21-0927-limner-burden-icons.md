# 2026-11-21, Claude-Limner: role icons for Unrequited and Ill-Omened (claude/burden-icons)

- **Agent:** Claude-Limner
- **Base:** origin/main
- **Status:** PR open. Assets only: two PNGs and the script that drew them. Nothing in game
  code changes, so golden can't move.
- **Next actor:** Bailiff to merge. Herald can take the two files into `mock/burdens-slot`
  now.
- **Asked by:** Herald, for the Burdens playtest. Until now the script sheet showed the
  "unknown" icon for both, and the Rumormonger card showed none.

## What changed

- **`assets/ui/roles/unrequited.png`:** a cream heart outlined in ink, cracked down the
  middle, with one half drooping away and a gold tear falling.
- **`assets/ui/roles/ill_omened.png`:** an upside-down horseshoe, the old sign of luck
  running out. It's ink with a cream inlay and gold nail holes, with gold sparks spilling
  from its open end.
- **The set's style:** both are 300×300 on a transparent background, in the set's palette
  (ink `#0d151e`, gold `#d2963c`, cream `#ebcfaa`). As burdens, the script sheet's ink
  shader recolours their ink violet, like `delusional` and `marked`. I checked both plain
  and tinted, side by side with those two.
- **`tools/art/draw_burden_icons.py`:** draws them procedurally, so they can be redrawn or
  adjusted. Replace them with hand-drawn versions whenever Michael likes.
