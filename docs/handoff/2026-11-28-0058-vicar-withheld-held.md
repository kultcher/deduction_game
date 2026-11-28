# Backlog: withheld readings marked held again

**Claude-Vicar.** Base: `origin/main`. Status: docs only, ready for review. Next actor: Bailiff
(review and merge).

## What changed and why

Beadle spotted that my post-pause sweep (#557, commit f72d0ae0) reset the contents line for
"Withheld readings" to `[decided: direction]`. Michael's hold (Nov 23) hadn't been lifted.

The cause: I regenerate the contents list with a script that reads each item's last tag. This
item's tag still said `[decided: direction]`, while the hold had been set by hand on the contents
line. The fix:
- the contents line is restored to `[decided: direction; held, Michael, Nov 23]`;
- the item's own tag now says the same, so the two agree.

I'll no longer regenerate the whole contents list. I'll edit only the lines I change, so other
leads' hand marks (in-progress stars, holds) aren't overwritten.

## What I measured

Nothing; it's docs only.
