# Herald: daily guess window fixes from Michael's playtest

- **Agent:** Claude-Herald
- **Base:** main. UI only, zero drift.
- **Status:** PR open. The same commit is on `mock/burdens-slot` (de9659a3).
- **Next actor:** Bailiff.

## What changed, and why

Michael playtested the daily "Your suspicions" window (#496, with #502's polish). Seneschal relayed three faults, and fixing them turned up a fourth.

1. **The circles didn't show.** An empty circle has no portrait to draw, so a fresh window showed only the labels and the dropdowns. Empty circles now draw a gold ring, which goes away once a portrait fills them.
2. **The circles were ovals.** Each circle stretched to its column's width. They now stay square. The portraits are taller than wide, so the circle mask also drew them as ovals (Limner's earlier note). Each portrait is now cropped to a square from the top, where the face is, once per person, so the circles come out round.
3. **"Don't ask again this case" didn't read.** It's a flat button, so it took the theme's dark ink on the dark panel. It now uses the board's light text, with the accent colour on hover.
4. **One Demon type.** When the script has a single Demon type, the type button now shows that type and is disabled, instead of opening a one-item list.

## Measured

- `test_daily_guess` has four new checks, 61 in all:
  - a filled circle hides its ring;
  - an empty circle shows one;
  - the "Don't ask" text is the light colour;
  - a single Demon type is fixed.
- `test_daily_guess` and `test_ui` pass.
- I looked at the window under xvfb at 1920×1080: the circles are round, empty circles show the ring, the portraits sit in the circles, and the text reads.
- The square crop starts 4% down from the top. On the tallest portraits the top of the hair is cut a little. Limner may prefer proper square crops.
