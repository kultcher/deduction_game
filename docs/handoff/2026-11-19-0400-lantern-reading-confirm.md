# 2026-11-19, Claude-Lantern: "does this reading confirm what I know or believe?" (`claude/reading-confirms`; zero drift)

- **Base:** main `a990916`. **Status:** PR open. **Next:** Bailiff; then Beadle wires the trust
  gain to it.
- **What:** `ReadingConfirm.assess(view, card, listener, chances)` returns
  `{tier, agreement, source}`, per Michael's item "Trust from readings that confirm what I know
  or strongly believe" (approved Nov 19, via Seneschal):
  - **Tiers:** `known` (source "fact"), `moderate` (≥ 0.85), `small` (≥ 0.70) or `none`. That's
    a cutoff and tiers, as Michael set, not a scale.
  - **Known:** the reading holds in every world the listener's own knowledge allows, at a
    neutral prior.
  - **The belief side:** the better of two readings of the reading. Its content holds (CaseEval
    "holds", no cards, the listener's standing prior). Or what it says about alignment holds,
    read from the listener's own chances (`chances`, its last connections posterior).
  - The design is in `docs/belief_model.md`, "Does a reading confirm what I know or strongly
    believe?".
- **New constants (Michael's values):** `Tuning.Trust.READING_CONFIRM_SMALL = 0.70` and
  `READING_CONFIRM_MODERATE = 0.85`. `tuning_catalogue.md` is regenerated.
- **Small calls made on Michael's behalf:**
  - "Right" also counts the alignment the reading implies, not only its exact content. So
    "Edda was the Poisoner" confirms a strong belief that Edda is evil, which is Michael's own
    example.
  - The alignment side reads the listener's chances, not CaseEval's suspicion-weighted prior.
    That prior follows suspicion only loosely: a suspicion of 0.97 gave an agreement of 0.71.
  - Several people named or cleared are combined as a product of their chances, an
    approximation. It's exact for a reading about one person.
  - A reading pointing at a group (a pair, or a count above 0) uses its content only.
  - The listener's own reading confirms nothing.
- **For Beadle:** call it before the reading is applied. Pass the prepared view and listener
  (`Shared.prepare`, `Jury._eval_listener`) and the listener's chances
  (`proposal.connections.posterior`). `source` says "fact" or "belief", for the reveal.
- **Tests:** new `test_reading_confirm` (7 checks, on the fast list). It covers:
  - a reading clearing the listener is known (a fact);
  - a reading naming one person the listener is 90% sure of is moderate, 75% small, 30% none;
  - tiers follow the cutoffs;
  - its own reading confirms nothing.
- **Measured:** in the PR body (golden, and the fast list).
- **Proposed for the backlog:** none.
