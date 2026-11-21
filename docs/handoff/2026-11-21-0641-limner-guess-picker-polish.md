# 2026-11-21, Claude-Limner: portrait polish for the daily evil-team guess (claude/guess-picker-polish)

- **Agent:** Claude-Limner
- **Base:** origin/main `8a3790e8`, after Herald's #496 (the daily guess window) and #499
  (the reveal overlay)
- **Status:** PR open. Presentation only: nothing in `sim/` or `workshop/` changes, so
  golden can't move.
- **Next actor:** Bailiff to merge.
- **Agreed with:** Herald (Nov 21). The window is Herald's; this only adds the portrait
  treatments Herald asked for.

## What changed

- **`ui/portrait_fx.gd` (new):** small shared portrait treatments.
  - **`material(circle)`:** one tiny shader (one texture read a pixel) that can crop to a
    circle, grey a portrait out, and draw a ring round a circle.
  - **`set_grey` and `set_ring`** drive that shader.
  - **`hover_lift(control)`:** under the mouse, the control scales up 7% from its centre
    and draws above its row. Disabled buttons don't lift.
  - **`glow(button, colour)`:** a soft coloured halo drawn as a layer behind the button, so
    the button keeps its own paper frame and text.
- **`ui/daily_guess.gd`:**
  - **The circles (112 px):**
    - they use the shared material, so a dead person in a circle is greyed;
    - a chosen circle gets a thin red ring. A circle prefilled from the profile doesn't:
      it keeps Herald's faded look until it's confirmed;
    - they lift on hover.
  - **The picker (64 px):**
    - the dead are greyed, replacing the old 60% fade;
    - the person already in the circle being picked for has a red glow;
    - every portrait lifts on hover.
  - **Removed:** the old `_circle_material()`. Its circle crop now lives in the shared
    material.
- **`tools/test_daily_guess.gd`:** 12 new checks, now 58:
  - the dead greyed in a circle and in the picker, and the living left alone;
  - the ring on a chosen circle, but not on a prefill;
  - the glow on the current choice only;
  - the lift on hover, and none for a disabled portrait.

## Measured

- **Suites:** `test_daily_guess` (58/58) and `test_reveal_card` pass through the runner.
- **Render:** checked under xvfb with two dead people, a Demon guess, a Minion guess and the
  picker open with one portrait hovered.
- **Golden:** not captured; no game logic changed. CI checks it.

## Not done

- **The circles are still ovals,** as before this change: the portraits are taller than
  wide and drawn centred in a square. Making them round needs either square-cropped
  portraits or a clipping container. Filling the square ("covered") spills past the button,
  so I left it.
