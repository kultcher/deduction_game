# 2026-11-18, Claude-Herald: learning resources layer 1, mechanics terms and control tooltips (`claude/herald-terms-layer1`)

- **Base:** main `29a0fba` or later. **Status:** PR open, UI only. **Next actor:** Michael approves the wording through Seneschal, then Bailiff merges. **Hold the merge until the wording is approved.**
- **Source:** BACKLOG "Learning resources" [decided: direction], layer 1 only, as Seneschal assigned it on Nov 18. Layers 2 (the field manual) and 3 (the tutorial) are on hold.

## What changed

- **`ui/term_defs.gd` (new):** one registry for both lists, so layer 2 can read the same words.
  - `MECHANICS`, 14 terms, each with a tooltip:
    - On the Block, Vigil, Ward, Clemency, Trace;
    - the three evidence classes: Speech, Circumstantial, Concrete;
    - Night order;
    - the five traits: Privacy, Gossip, Confidence, Insight, Composure.
  - `CONTROLS`, 14 action-button tooltips, matched by the start of the button's label.
  - Marked and Delusional were already covered: they're secrets, which `TextTerms` registers with tooltips.
- **`ui/text_terms.gd`:** registers the mechanics as kind `mechanic`, with no colour and a tooltip. Common words match only when capitalized, so "a ward of the parish" is left alone. The lower-case "vigil" and "on the block" still match.
- **`ui/main.gd`:** `_button` sets each button's tooltip from the registry. Buttons with no entry get none, as before.
- **New suite:** `tools/test_term_defs.gd`, 21 checks.

## The drafts (sent to Seneschal for Michael)

All the wording is in `ui/term_defs.gd`, marked DRAFT. It was checked against DESIGN.md for each mechanic: vigil, ward, clemency, traces, evidence classes, night order and traits.

## Measured

- **Suites passed:** `test_term_defs` (new), `test_text_terms`, `test_text_formatter`, `test_text_ui`, `test_ui` and `test_ui_controls`.
- **Known failure:** `test_day_conversation_view` hangs on main, as it does without this change; #283 fixes it.
- **Golden:** not captured. No simulation or game file changed, only UI files.
