# Vicar: Michael's Nov 18 calls on the remaining open BACKLOG items

- **Agent:** Claude-Vicar
- **Base:** `claude/vicar-backlog-verified` at 7f0757c (PR #254, unmerged), from main f23566a
- **Status:** docs only, ready for Bailiff
- **Next actor:** Bailiff (review and merge #254); Quill and Herald for the two newly
  `[decided]` items; Beadle for the folded trust sub-point

## What changed and why

Michael's decisions, relayed by Seneschal on Nov 18:

1. **"Evidence can build NPC-to-NPC trust"** folded into Beadle's "Backing a strong case
   builds trust" as a sub-point, with a line recording Michael's scope for the item
   (agreement through votes, nominations, accusations and defences, plus "their reading
   confirms me"). I only appended; Beadle's rescope of the item's main text is Beadle's.
2. **"Dowser clearing strength"** moved from the tentative social tuning to Numbers, next
   to "The Seer's rise looks small", tagged `[later: role tuning pass]`.
3. **"Believable public revisions; withdraw or revise a case"** is `[decided]`. Owners:
   probably Quill (the judge) and Herald (the UI). It notes the pairing with "Recovering
   from a wrong 'lying' call" and the "poisoned, not lying" note.
4. **"Medium relays: later social consequences"** and **"Trust dynamics around sources"**
   bundled as one item (the second as a sub-point) and tabled.
5. **"Role hints from workplaces and haunts"** tabled. The emptied "Exploration" heading in
   section 2 is removed.
6. **"Situational credence modifiers"** tabled.
7. **"Talking to a group"** tabled.
8. **New item, "New role hint families"** (Michael's own), in section 3, `[decided]`,
   design first. The facts in it are read from `sim/content.gd` `HINT_PACKAGES`: five
   families, "official business" holds seven roles, and Rumormonger and Martyr are each in
   two families. Owners: Quill (roles and evidence), Herald (the wording); Michael names
   the families.

Also updated DESIGN.md's open-direction lines for the three tabled items it lists, and
`docs/design/open_questions.md`'s index for all eight.

## Checked

A coverage script: every line removed from BACKLOG.md is still in BACKLOG.md (moved or
tabled), apart from the rewrapped folded text and the removed "Exploration" heading.
Nothing was run in the game.
