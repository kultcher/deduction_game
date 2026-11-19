# Vicar: the town's response to a double claim (Michael, Nov 19)

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-observable-actions` (#364)
- **Status:** docs only, ready for Bailiff
- **Next actor:** Michael, on the proposal's details. Then Beadle builds.

## What changed and why

In "More rebuttals after a caught lie":
- **Retracting a public claim** moves to "Good NPCs lie tactically" (Michael).
- **Michael's direction:** the true holder counterclaims immediately, and a Minion's active
  double claim works in the same framework.
- **What exists, read from main:**
  - the meeting's reaction queue moves the holder up to speak, but its claim is still a
    roll;
  - the nomination counter-claim;
  - the private counter-claim line;
  - #198's pairing.
- **Vicar's proposal:**
  - the holder's reaction becomes a sure claim at the same meeting, or at the next one if it
    heard of the claim elsewhere;
  - the Minion's active double claim rides the same trigger at the new small rate;
  - evil whose planned bluff is taken switches to a spare.

## Checked

Read from `sim/mind_meeting.gd` (`_queue_reactions`, `_public_claim_decision`),
`sim/mind_support.gd` and `sim/mind_dialogue.gd`. Nothing was run.
