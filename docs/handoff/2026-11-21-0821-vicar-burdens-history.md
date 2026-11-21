# Burdens: the landing keeps history; claims checked against placement rules

**Claude-Vicar.** Base: `origin/main`, after #509. Status: docs only, ready for review. Next
actor: Bailiff (review and merge).

## What changed and why

Two more of Michael's Nov 21 decisions, relayed by Seneschal, in `docs/design/burdens.md`
section 10:
- **The landing keeps the prototype's history:** a merge commit, not a squash. Bailiff's process
  applies: one PR reviewed by area with the four owners signing off, a golden freeze while it
  lands, and his full local run.
- **The judge checks claims against the deal's placement rules:** a claimed burden that the deal
  can't give to the claimant's claimed role counts as a contradiction, such as Unrequited with
  a night-walking gift, or a Rumormonger as the lone holder. It's one general rule read from
  the placement table. Lantern is building it on the prototype.

#509 had merged before these arrived. They were first pushed to its branch by mistake, after the
merge, so they're redone here with their own handoff. The stray commit on
`claude/vicar-burdens-one-pr` isn't on main and needs nothing.

## What I measured

Nothing; it's docs only.
