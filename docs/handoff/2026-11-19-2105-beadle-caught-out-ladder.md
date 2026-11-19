# One caught-out ladder for good and evil: the private side

- **Agent:** Claude-Beadle
- **Base:** main at `767e325` (`baseline_ee15238`)
- **Branch:** `claude/beadle-caught-out-ladder`
- **Status:** PR open. Golden is identical to `baseline_ee15238` (see Measured): the passive
  player never presses anyone.
- **Next actor:** Bailiff (review and merge). Then Lantern wires the judge's softening on
  these facts, and Michael sets its numbers (below).
- **BACKLOG item:** "More rebuttals after a caught lie", Michael's Nov 19 calls (Vicar, #364):
  the caught-out ladder. A partial built note is added.

## What changed

An NPC caught out of a home alibi in private, by a sighting or by a case that breaks the
alibi, now answers on one ladder, whether it is good or evil.

1. **A claimed walking gift**, or evil's claimed walking bluff, tells that duty, as before.
   - **New:** evil now does this when shown a case too (`trapped_explanation`). Before, it
     said only "Fine, I was out".
2. **An unclaimed walking gift or bluff gets the soft tier (new).** "Fine, I was out", then
   the NPC's default gift refusal. It owns the night, but keeps the gift.
   - **Before:** a good hidden walker revealed its gift outright, and evil with a planned
     walking bluff claimed the bluff outright.
   - **Lines:** it uses the existing `trapped_night_out` and `gift_refusal` lines; Michael
     rejected "duties not mine to tell". Herald has the final say on wording.
3. **Pressed again about that night, or once nominated,** it names the gift: a good walker
   its own, evil its planned walking bluff. This is the old reveal, one step later.
4. **Evil with nothing to claim** (a non-walking bluff, or none), caught out by a case, owns
   the night: "Fine, I was out. Doesn't mean I was doing anything wrong."
   - It may offer the sleepwalk bluff instead, as before.
   - **Before:** it stood by the home alibi the case had just broken.
   - It logs the reason "evil work, keeps the reason". It isn't a lie, since it was out.

**The facts left on the board** carry an `excuse` field, for Lantern's softening in
SourceDoubt: "admit" for the soft tier, "not_wicked", or "duty" (with `duty_role` and
`block`). Each also names its owner (`source`) and the night it excuses (`excuses_night`).

**Not in this PR:**
- The podium path at the meeting keeps today's roll.
- Evil backing into a spare or unknown walking gift.
- The Minion's double claims.
- The true holder's sure counterclaim.
- The switch when a bluff is taken.

Those are the next PR.

## For Michael: the softening constants (proposed, not built)

Lantern builds the judge side once the values are set.

- **While an excuse stands:**
  - **Lantern's suggestion:** a listener's caught-alibi doubt is multiplied by 0.75. The
    caught lie implicates three-quarters as much.
  - **Quill's alternative, stated as a rate:** a good person's chance of having said "home"
    while out rises from 0.2 to 0.35 for that night. That roughly halves how far the caught
    lie moves a listener.
  - **My recommendation:** Quill's form. It comes out of the existing likelihood, so a
    listener who already doubts the excuse-giver gains less, and no role needs a special
    case.
- **Once the excuse is contradicted:** it counts as a second caught lie, at about half a
  caught lie's weight. My proposal; Quill and Lantern measure the exact value.
- **Only a "duty" excuse can be contradicted:** no report from that duty for that night, a
  report placing it where the listener's own sighting rules out, or a stronger claimant of
  that role. "admit" and "not_wicked" name nothing checkable.

## Measured

- **New suite:** `tools/test_caught_out_ladder.gd` (10 checks), on the fast list.
  - A good walker, first caught: the soft tier. Caught again: it names its gift.
  - Nominated: it names the gift at once.
  - Evil with a walking bluff gets the same two steps.
  - Evil with a claimed walking bluff tells the duty, marked "duty".
  - Evil with nothing to claim owns the night, or offers the sleepwalk bluff, and never
    stands by the broken alibi.
- **Updated suites,** to the ladder's first press:
  - `test_evil_owned_lie`: the soft tier first, then the reveal.
  - `test_dialogue_fixes_testimony`: the caught-out opener on the second press.
  - `test_press_caught_out`: evil with nothing to claim now owns the night.
- **Also pass:** see the PR.
- **Golden:** identical to `baseline_ee15238` at `--tol 0`.

## Proposed for the backlog

None.
