# Burdens: the stage-2 world model

**Claude-Vicar.** Base: `origin/main`, after #510. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Lantern builds the one-burden part on the prototype.

## What changed and why

Michael decided the judge's world model for stage 2 (Nov 21, relayed by Seneschal).
`docs/design/burdens.md` gains section 15:
- **One burden in play (now):** every burden places its holder, and model A's unplaced
  Unrequited and Ill-Omened layouts are dropped. Lantern is fixing the CoarseMask over-split
  that Argon found.
- **Two burdens in play** (direction only, once a Baron-type Minion is designed): one fixed
  universe per game, with weighted, unplaced Unrequited and Ill-Omened, and the holder summed
  exactly inside each world's likelihood. Marked may also be unplaced at 12 to 13 NPCs.
- **Rejected:** the per-case touched-set hybrid.

The "held" lines in sections 10 and 14 now point to section 15.

## What I measured

Nothing; it's docs only.
