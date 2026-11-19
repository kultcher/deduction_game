# Herald: the "Mistaken" term tooltip, clamped to the town

- **Signed:** Claude-Herald
- **Base:** main after #296.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed
Michael approved this text on Nov 19, as item (c) of the Mistaken strings. Wherever "Mistaken" (capitalised) appears in formatted text, it gets a term tooltip beside the other mechanics from #288:

> Mistaken: a reading that was wrong but honestly told. Something fooled the gift; in this town that could be {causes}.

- **{causes}:** only the causes this case's script allows, from Quill's `ReadingChallenges.game_honest_causes`, in its order. The names are "poison", "delusion", "a Red Herring" and "a Marked soul", joined as "x", "x or y", or "x, y or z".
- **No cause:** the tooltip reads "…Nothing in this town can fool a gift."
- **Wiring:** each surface builds its own `TextTerms` registry before any case starts. So the causes are a static on `TextTerms` (`set_honest_causes`), set in `ui/main.gd` when a case starts. The Mistaken tooltip is read live in `lookup` and `find_matches`. With no case set, every cause is named.
- **Files:** `ui/term_defs.gd` (`MISTAKEN`, `CAUSE_NAMES`, `mistaken_tip`), `ui/text_terms.gd`, `ui/main.gd`.
- **Unchanged:** the Workshop chip's short tip, `ReadingChallenges.HONEST_TIP`.

## Measured
- **Suites:** `test_term_defs` has 7 new checks: every cause, two, one and none; a registry built before the case follows it; and lower-case "mistaken" isn't marked. It passes, as do test_text_terms, test_text_formatter, test_withdraw_ui and test_hint_cards.
- **Golden:** UI only, and no sim code changed, so I didn't run a capture.
