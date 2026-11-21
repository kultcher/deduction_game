# Quill: the evidence side of Burdens, made playtestable (mock/burdens-slot)

- **Agent:** Claude-Quill
- **Base:** `mock/burdens-slot` at afd5f520 (merged), with Herald's Burdens UI (47273ed8) and Lantern's walk model
- **Status:** pushed to `mock/burdens-slot`. It's a prototype branch, so there's no PR and no golden gate.
- **Next actor:** Seneschal (the placeholders and the open question go to Michael); Beadle and Lantern for the two suites that already fail at the branch tip

## What changed

Seneschal's four items, and the premise rename Seneschal passed on from Herald. Herald's 3fc01f67 and b7436468 had already done several pieces: the Rumormonger phrases, the live reason menu, the board tag, and retiring the flavour short forms. I dropped my duplicates of those at the merge and kept Herald's. That includes Herald's choice that burden cards keep their full text, with no short form.

1. **Readings for every burden.**
   - The phrases are Herald's.
   - The Chronicler's "carried a secret" already counts every burden holder, so it needed no change.
   - **Bug fixed.** `workshop/solver.gd` `_secret_mod_code` mapped Unrequited and Ill-Omened to "unknown", although the C# judge has codes for them (2 and 3, `SolverContext.cs`). The judge therefore held every Unrequited or Ill-Omened Rumormonger reading false in every world, and read the Rumormonger as a liar or poisoned. These readings are now judged on their content. This moves NPC beliefs on deals with one of those holders; see the `test_evil_play` note below.
2. **Burden claims as case cards.**
   - Rumormonger slots on the canvas show the burden's name, "Ill-Omened" rather than "Ill_omened" (`ui/workshop_canvas_view.gd`).
   - A claim, a counter-claim and a clash can all be cited, as the earlier slate entries show (`marked_counter`, `burden_clash`).
3. **Private errand.** Herald did the live menu. I finished the parts that also check the claim, so that only an Unrequited claim can explain an outing:
   - the older editor's citation list (`ui/case_workshop.gd`, placeholder label);
   - the automatic citation (`workshop/canvas_model.gd`);
   - the live judge's citation check (`workshop/live_assessment.gd` `conclusion_issues`).
4. **Test-juror slate** (`tools/case_slate.gd`). Four entries were added: `omen_bluff`, `omen_real`, `unrequited_walk` and `unrequited_bluff`. Their Unrequited claims name a beloved, which Lantern's walk model now reads.
5. **Premise rename.** "holds a secret" is now "carries a hidden burden" (placeholder). It's in `canvas_model.gd` `PREMISE_TEXT`, `live_case_workshop.gd` `LIVE_TYPE_NAMES`, and the town's ledger line "The Demonologist says X carries a hidden burden: Delusional." No code matches the old text; only comments still mention it.

**Not mine, changed so a suite passes: `tools/test_evil_play.gd` (Beadle's).**
- The clemency check planted a suspicion and then opened the meeting, whose belief refresh overwrote it.
- On its seed, Bart is the Unrequited and Kiran's Rumormonger reading names that burden. With the code fix, the refresh lands lower (0.53, not the planted 0.85).
- The check now plants the suspicion after the meeting opens, and it passes.

## What I measured

**Slate:** 10 NPCs, seeds 1 to 6, each case built at day 3, on the merged branch.

| Case | Badge | Strength | Good "yes" votes after | Crosses |
|---|---|---|---|---|
| `omen_bluff`: the Demon claims Ill-Omened after the real Seer's "yes" | Moderate, on all 6 | 2.33 | 3 to 7 of 7 | 2 of 6 |
| `omen_real`: real Ill-Omened (claimed on day 1), framed by a Minion's Seer "yes" | none | 1.18 | 1 or 2 of 6 | 0 |
| `unrequited_walk`: real Unrequited, seen at the beloved's block | "contradicts", on all 6 | 0.51 to 0.54 | 0 or 1 of 6 | 0 |
| `unrequited_bluff`: the Demon seen on the kill night, claims love for someone on another block | none on 5, Weak on 1 | 1.10 to 1.32 | 1 to 3 of 6 | 0 |
| `kill_sighting` (control: the same sighting, no claim) | none on 5, Weak on 1 | 1.12 to 1.35 | 1 or 2 of 6 | 0 |

In game terms:
- A Demon who bluffs Ill-Omened against a Seer's "yes" still gets argued onto the block a third of the time.
- A real omen claimant framed by a false Seer reading is barely moved.
- A real Unrequited seen at the beloved's door is cleared by their claim. Arguing them evil reads as a case against itself.
- The Demon's Unrequited bluff, naming someone who lives elsewhere, doesn't excuse a kill-night sighting. This is Michael's section 11 rule, now working through Lantern's beloved field.
- Before the slate cards named a beloved, the bluff did excuse the sighting slightly (0.97, against the control's 1.12).

**Suites:** 32 run on the merged tree, 30 passed. I ran the 24 that touch secrets, the errand or the Rumormonger, plus `test_burden_*`, `test_premise_step2`, `test_workshop_reading_challenges`, `test_workshop_ui`, `test_workshop_live_canvas` and `test_conversation_nights`. Both failures also fail at the clean branch tip, without my changes:
- `test_press_caught_out` (Beadle's): it checks the retired Sleepwalker ("an unaware Sleepwalker doesn't own the night").
- `test_connections_pairings` (Lantern's).

## Wording (approved by Michael, Nov 21, through Seneschal)

- "carries a hidden burden": the premise, formerly "holds a secret". The town's ledger line reads "The Demonologist says X carries a hidden burden: Delusional."
- "For love (their Unrequited claim)": the reason a burden gives for being out at night. Herald's `UNREQUITED_REASON` is used by both the live Workshop and the older editor.
- Slate-only card texts, which the player never sees, stay as they are: "hang me and you'll all pay for it".

**A fix after the push:** my first premise rename put a comment mid-line in `canvas_model.gd` `PREMISE_TEXT`, which commented out "was turned by the Revenant's curse". The "turned" premise's title had gone missing. It's restored, and the placeholder comment is gone now that the wording is approved.

## Small calls made on Michael's behalf

- The Rumormonger's evil bluff ("a harmless secret to own to") can now give a fellow evil Ill-Omened or Unrequited. I left that alone: an Ill-Omened cover is a fair evil play. The "why" wording is Beadle's.
- No icons for Unrequited or Ill-Omened. The Rumormonger card shows none for them, because the texture loader returns nothing for a missing file. That's Limner or Herald's.

- **A Red Herring explains only a Seer's "yes"** (Seneschal, Nov 21, on Michael's behalf). This is from the Seer check of `docs/design/reading_interpretation.md` §2.1. The Workshop used to let the player call a Seer's "no" an honest mistake "because of a Red Herring", even on a script where nothing else can make a reading go wrong. A Red Herring reads falsely as the Demon and never falsely as clear, so that call is now refused, following Michael's rule that the canvas refuses a cause that can't apply. The change is in `reading_challenges.gd` `cause_reaches`, and `test_honest_mistake` follows it.
- **The Seer card's "(Marked or Red Herring?)" reminder leaves out Marked on a script without it** (the same check). With no Marked it reads "(Red Herring?)". The card learns the script's burdens through a presentation-only `RoleDef.script_secrets`, which `Game.new_case` sets and the simulation never reads. It doesn't move golden. Herald is checking the wording.

## For Michael (through Seneschal)

- Still open: a reactive Marked claim now looks suspect for a real holder too (`marked_rescue` dropped from Strong to no badge).

## Proposed for the backlog

None.
