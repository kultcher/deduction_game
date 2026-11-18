# 2026-11-18, Claude-Herald: card text, the fewest words on the card and the full sentence on hover (`claude/herald-card-text`)

- **Base:** main `42663c3` (after #250). **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** Michael, Nov 18, through Seneschal: "Cards show the fewest words. The full verbose text moves to a hover tooltip." The BACKLOG item for it is added in #253. Card nights stay numbered.

## What changed

- **`ui/board_view.gd`:** every reading zoom now shows the card's short form (`CardModel.short_text`). Before, the detail zoom showed the full sentence ("Kiran publicly accused Greta."). The full sentence was already in the hover tooltip with the card number, and still is.
- **`game/card_model.gd`:**
  - **New short forms for hints and secrets:**
    - hints: "Lian hints: reading people", "…: the dead", "…: night sight", "…: records", "…: shelter";
    - secrets: "Hollis sleepwalks", "Merrin meets Kiran in secret", "Agnes prays at night", "Fenwick smuggles", "Dorian pays a gambling debt".
  - **No more crude cut:** a kind with no short form used to cut at 57 characters with "...". It now hands the full text to the card, which cuts it to fit and ends it in "…".
- **BACKLOG:** "Case board visuals" moves to `BACKLOG_COMPLETED.md`, built as #250 plus this PR.
  - **The card-text item** (added by #253) stays open, updated: built for the case board here; the Workshop canvas cards and a pass over the gift readings' short forms remain.

## Small calls made on Michael's behalf

- **The hint and secret short forms above,** including "smuggles" and "prays at night" for the flavour secrets.
- **The "heard" line at the detail zoom is unchanged.** It still ends in "…" when long, and the full line is in the tooltip.

## Measured

- **Suites:** `test_text_ui`, `test_evidence_context`, `test_ui`, `test_ui_controls`, `test_town_ui` and `test_playtest_1709` pass.
- **Golden:** identical to main's baseline at `--tol 0` on all 5 seeds.
- **Screenshot:** checked through an uncommitted probe (seed 23973, day 2, detail zoom). The cards read "Kiran accused Greta", "Greta claims Martyr" and "Lian vouches for Nisha".
