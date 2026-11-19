# Herald: finding your way on the Workshop canvas

- **Signed:** Claude-Herald
- **Base:** main at 68e4f85.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed
These are items 5 to 7 of Michael's Nov 19 batch, relayed by Seneschal.

- **Adding a card centres the view on it.** It glows softly until first moved: a faint gold ring, drawn with the selection marks (`canvas.fresh`). This applies to any add, whether from the board, a drop or a menu. It used to fit the whole case. The zoom stays unless the card wouldn't fit. Adding several at once (`add_evidence_many`) centres on the group, and that includes several cards dropped from the board together (Codex, #323).
- **Markers for off-screen cards.** Cards wholly out of view are gathered into eight directions from the view's centre. Each direction gets one small gold arrow at the canvas edge, with a count when there's more than one card, rather than one marker per card. Hovering says "N cards this way. Click to look." Clicking brings those cards into view. Markers take the click before any card beneath them.
- **Right-click on empty canvas.** A right-click that isn't a drag (it still pans when dragged) opens a menu with two submenus, each listing everyone in town with a count. Names with nothing to add are greyed out.
  - "Add readings FROM ▸ <person>" adds every gift reading on the board that this person read: card `source`, whoever relayed it.
  - "Add all readings ABOUT ▸ <person>" adds every reading that names them, including as one of a pair or a group: card `subject`.
  - Only cards the Workshop accepts are added. The view centres on them, and the status line says how many were added.

## Small calls made on Michael's behalf
- **FROM means the reader.** A reading the player heard second-hand still counts as the reader's. Seneschal has my question for Michael. If he wants second-hand left out, it's a one-line change in `readings_for`.
- **Eight directions** for gathering markers, with the count shown only when it's more than one.

## Measured
- **New suite:** `tools/test_workshop_nav.gd`, 12 checks, on seed 692 with 10 townsfolk.
  - FROM and ABOUT pick the right readings.
  - An added card is centred and glows, and moving it ends the glow.
  - Cards off to one side share one marker, and clicking it brings them back.
  - The menus list everyone, and ABOUT adds each reading.
  - A drop of several cards brings them all into view.
- **Suites:** test_workshop_live_ui, test_workshop_ui, test_workshop_remaining, test_workshop_ui_1110, test_ui and test_board pass.
- **Screenshots:** under xvfb at 1920×1080, showing the glow and the edge marker.
- **Golden:** not run. This is UI only.
