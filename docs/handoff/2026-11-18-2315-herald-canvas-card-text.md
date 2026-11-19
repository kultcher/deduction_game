# 2026-11-18, Claude-Herald: the Workshop canvas's cards in the fewest words (`claude/herald-canvas-card-text`)

- **Base:** main `4ec65e1` or later. **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** BACKLOG "Card text: the fewest words on the card, the full sentence on hover" [decided, Herald]. This covers the part left over after #256: the Workshop canvas.

## What changed

- **`game/workshop_canvas.gd`:** each canvas card in `view()` carries `short`, the board's short form (`CardModel.short_text`) of the board card it came from. It is display only: no judge or solver reads it.
- **`ui/workshop_canvas_view.gd`:** an evidence card's body text uses `short`, so the canvas reads like the board: "Kiran accused Greta" rather than the whole sentence. The hover tooltip still shows the full sentence, as it did before.
- **Kinds without a short form** fall back to the sentence, exactly as on the board.
- **BACKLOG:** the item's note now says the canvas is done. The pass over gift readings' short forms is what remains.
- **New suite:** `tools/test_canvas_card_text.gd`, 4 checks.

## Measured

- **Suites passed:** `test_canvas_card_text` (new), `test_workshop_live_canvas`, `test_workshop_canvas`, `test_workshop`, `test_workshop_ui_1110`, `test_carried_answers`, `test_public_revisions` and `test_ui`.
- **Golden:** identical to `baseline_e287b3d` at `--tol 0` on all 5 seeds.
- **Not measured:** no screenshot of the canvas.
