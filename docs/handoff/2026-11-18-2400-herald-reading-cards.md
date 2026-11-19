# 2026-11-18, Claude-Herald: gift-reading cards, shorthand faces with the teller's portrait (`claude/herald-reading-cards`)

- **Base:** main `678838f` or later. **Status:** PR open, zero drift. **Next actor:** Bailiff. Quill reviews the role files.
- **Source:** Michael's picks of Nov 18, through Seneschal, from the mockups on `mock/herald-reading-cards` (`mock_screens/reading/`, never merge). This finishes the card-text item's last part, the gift readings.

## What changed

- **Card faces (`sim/roles/*.gd`, each role's `short_text`).** Each face shows only the stated facts, in shorthand with symbols, with no teller and no role (the portrait and role icon show those). The wording is Michael's approved table, with Quill's meaning fixes:
  - "Poisoner = Agnes / Bart?"
  - "Agnes / Bart: Demon or Red Herring? YES"
  - "1 evil among Agnes, Bart, Cora"
  - "Docks: a Poisoner walked"
  - "Agnes → Bart: same side"
  - "Day 2: nothing false heard"
  - "Agnes = Seer / Clerk / Monitor? NO"
  - "Late Edda (Seer): …"
  - and so on for every role.

  The hover keeps the full sentence. "Block" stays; street or block is for Michael's final polish.
- **The Chronicler is trimmed** to "Greta / Kiran / Lian: plain, secret, minion". With "At the start" it ran to four lines on a three-line card. The card already sits in the night-0 column, and the hover keeps the full sentence. Seneschal was told.
- **`ui/board_view.gd`:**
  - The speaker's colour is a bar across the top of every card, no longer down the left.
  - A gift reading shows the teller's face in a small gold-ringed circle, cropped like the roster's badge, above the role icon. The generic reading eye is gone.
  - Other cards keep their kind icon.
- **`tools/test_roles_registry.gd`:** the Surveyor check now expects the new form.

## Small calls made on Michael's behalf

- The horizontal bar is on every card kind, so the board stays uniform. The portrait is on readings only.
- The face circle is drawn as a textured polygon with a gold ring line, not the roster's shader node. This keeps the board a single canvas.

## Measured

- **Suites passed:** `test_roles_registry`, all eight `test_roles_*` suites, `test_text_ui`, `test_ui`, `test_workshop_live_canvas` and `test_workshop`. CI runs the fast list.
- **Golden:** identical to `baseline_e287b3d` at `--tol 0` on all 5 seeds. The text is display only.
- **Screenshots:** eight sample readings at two zooms, from an uncommitted probe. The text fits; the Chronicler fit after the trim.

## Later on this PR (Nov 19, Michael's follow-ups)

- **Seer card:** "Lian / Hollis: Demon? YES", with "(Marked or Red Herring?)" beneath it in the small type, only on a YES. A NO reads "Lian / Hollis: Demon? NO". On the Workshop canvas the two parts join into one line.
- **Names in colour:** every card's text draws each townsperson's name in their colour, on the case board and the Workshop canvas, for all card kinds.
  - The colour is the ink-darkened shade the colour bar uses (`UITheme.ink_of`), so pale roster colours stay readable on parchment.
  - On the board, the paragraph is drawn glyph by glyph, keeping wrapping and "…".
  - On the canvas, lines are drawn in segments.
- **Fixes:** the card text sits fully below the top colour bar, and a 1-line "heard" field no longer spills past the card.
- **Screenshots:** board names at both zooms, seed 23973 day 2, sent to Michael. The canvas wasn't screenshotted.
