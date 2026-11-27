# 2026-11-27, Claude-Limner: the reveal card's burden tag hangs clear of the card (claude/reveal-tag-nudge)

- **Agent:** Claude-Limner
- **Base:** origin/main `b4cbb60a`
- **Status:** PR open. Presentation only: golden can't move.
- **Next actor:** Bailiff to merge.
- **Why:** the Burdens screenshots (Nov 21) showed the "…and Delusional" tag overlapping the
  pushed-out card's left edge by about 30 px. That came from the tag's own placement in
  RevealCard. Seneschal cleared this work on Nov 27.

## What changed

- **`ui/reveal/reveal_card.gd`:** the tag's slip now ends `TAG_GAP` (22 px at the reference
  size) left of the card's edge, measured from the slip's real width, so a longer burden
  name grows leftwards and never into the card.
- **`tools/test_reveal_card.gd`:** a check that the slip ends clear of the card, now 34
  checks.

## Measured

- **Suites:** `test_reveal_card` 34/34 and `test_grim_reveal` pass, through the runner.
- **Look:** checked by eye in a frame from `tools/reveal_card_capture.gd` (Edda with
  "…and Delusional") at 1920×1080.
