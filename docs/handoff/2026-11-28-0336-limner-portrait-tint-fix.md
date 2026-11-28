# 2026-11-28, Claude-Limner: the red cast on portraits in the guess window and the kill wheel (claude/portrait-tint-fix)

- **Agent:** Claude-Limner
- **Base:** origin/main `6770f32e`
- **Status:** PR open. Presentation only: golden can't move.
- **Next actor:** Bailiff to merge.
- **Report:** Michael, Nov 28, through Seneschal. The portraits in the "Your suspicions"
  window had a deep red tint, and so did those on the night's kill wheel.

## Cause

Both screens draw portraits through `PortraitFx.material()` (`ui/portrait_fx.gd`), my shader
from Nov 21. Its fragment() began `vec4 c = texture(TEXTURE, UV) * COLOR;`, but in Godot 4's
canvas_item fragment(), `COLOR` already holds the texture times the modulate. So each
colour was squared: darker, and over-saturated towards red, worst on skin. The same bug drew
the guess circles' ring only where the portrait was opaque (its alpha came from
`COLOR.a`), which is why the rings looked broken at the top and bottom.

## Fix

- **`ui/portrait_fx.gd`:** fragment() starts from `COLOR`. The node's modulate is passed
  through a varying from vertex(), so the ring is a whole circle that still fades with its
  node (the kill wheel fades the slices it isn't keeping).
- **`tools/test_kill_wheel.gd`:** a check that the shader doesn't apply the texture twice.

## Measured

- **Suites:** `test_kill_wheel` (now 42 checks), `test_daily_guess`, `test_reveal_card`
  and `test_pacing` pass, through the runner.
- **Look:** screenshots before and after, at 1920×1080 in main.tscn, of the guess window
  with three picks and of the pacing overlay's kill wheel (spin and isolation). Colours now
  match the portraits elsewhere, the rings are whole, and faded slices leave no ring
  behind.
