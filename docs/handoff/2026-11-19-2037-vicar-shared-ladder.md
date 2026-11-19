# Vicar: one caught-out ladder for good and evil (Michael, Nov 19)

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-observable-actions` (#364)
- **Status:** docs only, ready for Bailiff
- **Next actor:**
  - Beadle builds it once "Evil backs into a bluff" comes off hold. Michael to say.
  - Herald, for the wording.

## What changed and why

Michael's answers on the backing-into-a-claim ladder, in "More rebuttals after a caught lie":
- **The ladder is right,** and good hidden walkers use the same one, so the response isn't
  a tell.
- **Today, read from main:**
  - evil with a walking bluff already owns the outing (`_bluff_outing`);
  - a good hidden walker caught out in private reveals its gift outright
    (`trapped_explanation`), with no soft tier.
- **New soft tier, for both:** "Fine, I was out", then the default gift refusal
  (`gift_refusal`). Michael: "duties that aren't mine to tell" isn't the right wording.
- **A Minion's deliberate double claim:** also when confronted privately by the player, not
  only at a nomination.
- **New:** a small chance that an unclaimed non-Scion Minion enters a double claim
  unprompted. It needs a new constant, for Beadle to propose.
- **Still open:** whether a publicly claimed evil may retract to back in. Vicar's lean: no.

## Checked

Read from `sim/mind_dialogue.gd` (`trapped_explanation`, `_gift_outing`, `_bluff_outing`,
`lie_or_stonewall`) and `sim/world.gd` (`bluffs`). Nothing was run.
