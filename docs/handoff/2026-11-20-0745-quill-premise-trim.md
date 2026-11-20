# The premise menu, trimmed

**Claude-Quill, Nov 20.** Base: main at 509732f9 (with #403). Status: ready for review. Next
actor: Herald reviews the Workshop UI, Lantern the judge, then Bailiff. Zero drift: golden is
identical (see "Measured").

## What changed and why

Michael approved all three trims from my premise check (Nov 20). One commit each:

- **(a) "These reports conflict" is removed.** It never moved belief, because its cards were
  quoted rather than argued, and it was a trust earner with no risk.
  - **Gone:**
    - the premise from every picker and name;
    - the canvas compile;
    - the judge's handling (solver, jury, reasoner, support model, shared ledger, case_why);
    - the live adapter and session validation;
    - the presentation's scrutiny pressure (`_conflict_pressure` and its callers), the
      trust-reward exemption, and its evil-reply branch;
    - the deduction vocabulary (`conflict_of`, `group_of` and their text, key and filing
      checks);
    - `CONCLUSION_COEFFS["conflict"]`;
    - the voice keys `present_conflict_found` and `present_conflict_none`, in all 15 voices
      (test_dialogue_voices' count goes from 257 to 255).
  - **Kept:**
    - `present_conflict_weighing`, which voices a clash inside any other case;
    - the general contradiction finder (`Solver.minimal_conflicts`, `_find_conflicts`,
      `reasoner._local_conflict`, `shared_ledger.challenges_conflict`), which reading
      challenges use.
- **(b) "X's readings don't fit together" stays.** It's the only way to argue Delusional, and
  it weighs a source's readings together.
- **(c) "Is a Minion" is folded into "is evil".** Both moved listeners identically. The
  Minion premise only asked the judge "evil and not the Demon", which it couldn't tell apart
  by role.
  - **Gone:** the premise type, its theory key, `ConclMinion` in the C# kernel, and its
    entries in `CONCLUSION_COEFFS` and `PREMISE_ALIGNMENT_TYPES`.
  - **Kept:**
    - "is the Demon" and "is not the Demon";
    - every role-level Minion idea (positions, movement profiles, role pools);
    - case_why's "a Minion, not the Demon" alternative for a Demon premise.
  - BACKLOG notes it may return with premises step 4.
- **(d) "Holds their claimed gift" is merged into "is good".** The judge asked "not evil" for
  both; the C# code is now `ConclGood`.
  - **Gone:**
    - the premise type;
    - its `PREMISE_CLEARS` and alignment entries;
    - the live adapter's claim requirement;
    - the `Mind.card_clears` branch (Beadle flagged it; nothing else relied on it);
    - the believed-role side effect, which did nothing for good roles.
  - **Kept:** "is bluffing their claimed gift" (`notrole`). It's a separate premise, read as
    evil, already off the menu, but saved cases still evaluate.
  - BACKLOG notes it's revisited if "Good NPCs lie tactically" is decided.

**NPCs never file these premises.** The bot files only "evil", fabrication checks build only
"evil", and presentations build "good" and "suspicious". So play doesn't change.

**Old saved boards:** a conflict or Minion case on an old board is now refused as an
unsupported claim, and an old "holds their gift" case no longer clears anyone. The player
can no longer file any of them.

**Tests:**
- **Deleted, conflict-only:**
  - test_workshop_presentation `_conflicts` and the conflict-scrutiny half of
    `_scrutiny_and_cover`;
  - test_town_note `_conflict_quotes` and `_conflict_draft`;
  - the conflict checks in test_workshop_live_canvas, test_workshop_canvas and
    test_workshop;
  - two juror checks in test_workshop_reasoning.
- **Switched:**
  - test_workshop_cases (its contradiction checks now run under an "evil" premise);
  - test_ui and test_social_credibility ("lied");
  - test_juror_listener;
  - test_workshop_card_adapters (the totem case is now "evil");
  - test_roles_official (Demon only) and test_workshop_regressions;
  - test_premise_step1 and test_badge_text ("marked" as the non-settling premise);
  - test_mechanics_claims and test_mechanics_conclusions (`notrole`).

**Left alone:** the empty `conflict_scope` field in the case schema, and the `quotes` line
relation. Both are now unused, and removing them is a separate cleanup.

## Also answered for Seneschal (Nov 20)

- **Misled versus reading-lie strength:** closed. The Mistaken merge and the Lying retune
  (#296) settled it.
- **The Lamplighter accounting test:** already covered by `test_lamplighter_count_mix`, which
  passes 13 of 13.

## Measured

- **Golden:** identical to main's baseline at `--tol 0` (see the PR for the capture at the
  merged head).
- **Suites:** the 11 premise suites, every edited suite, test_dialogue_voices and its
  neighbours passed after each change. At the merged head, the CI fast list: see the PR.

## Proposed for the backlog

None. (Lantern is taking the `reason_attribution` defence-view fix from #405 as its own PR.)
