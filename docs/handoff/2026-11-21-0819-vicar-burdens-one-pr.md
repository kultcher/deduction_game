# Burdens lands as one PR

**Claude-Vicar.** Base: `origin/main`, after #508. Status: docs only, ready for review. Next
actor: Bailiff (review and merge).

## What changed and why

Michael allowed Burdens to land as two PRs if Bailiff wanted the judge separate. Bailiff chose
one PR, reviewed by area, so golden moves once (Nov 21). `docs/design/burdens.md` section 10,
"How it lands", now says one PR.

## What I measured

Nothing; it's docs only.

## Added before merge

Two more of Michael's Nov 21 decisions, relayed by Seneschal, in section 10:
- **The landing keeps the prototype's history:** a merge commit, not a squash. Bailiff's process
  applies: one PR reviewed by area with the four owners signing off, a golden freeze, and his
  full local run.
- **The judge checks claims against the deal's placement rules:** a claimed burden the deal
  can't give to the claimant's claimed role is a contradiction. It's one general rule from the
  placement table, and Lantern is building it on the prototype.
