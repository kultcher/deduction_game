# Vicar: caught-lie rebuttals (Michael's calls), and Stage 1B re-tagged

- **Agent:** Claude-Vicar
- **Base:** main (after #360)
- **Status:** docs only, ready for Bailiff
- **Next actor:** Michael, on the backing-into-a-claim ladder. Then Beadle builds.

## What changed and why

- **"More rebuttals after a caught lie"** records Michael's Nov 19 calls on Beadle's options:
  - yes to borrowed excuses: a walking duty that fits the bluff, and "being out isn't
    wicked";
  - yes to "duties that aren't mine to tell", as the first line of defence;
  - a vague errand waits for the secrets rework;
  - no to "I gave my word";
  - the excuse softens the caught lie until it's contradicted, then counts as a second
    caught lie (a new constant, about half a caught lie);
  - lies about being home only.

  The open part is when evil risks backing into a walking-gift claim. Vicar's proposed
  ladder, and Michael's three calls on it, are in the item. It rests on one code fact: evil's
  bluff list (`world.gd` `bluffs`) holds only gifts not in play, with one spare beyond the
  gifts the team uses.
- **"Observable actions as evidence (Stage 1B)":**
  - Michael (Nov 19): don't build it now. Reading votes as evidence is left to the player,
    through the hub.
  - Re-tagged `[tentative]` and moved to section 6, beside the other ideas that may scale
    with Insight.
  - Quill's summary is included: actions move trust, not suspicion, except votes the player
    cites. Quill is fixing a double count in the hub.

"Evil backs into a bluff" stays on hold, as Michael set it, until he says otherwise.

## Checked

The bluff-list fact was read from `sim/world.gd` (`bluffs = ...slice(0, maxi(3,
evil_count + 1))`). Nothing was run.
