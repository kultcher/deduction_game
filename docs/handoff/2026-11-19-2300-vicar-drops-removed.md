# Vicar: drops removed altogether (Michael, Nov 19)

- **Agent:** Claude-Vicar
- **Base:** main
- **Status:** docs only, ready for Bailiff
- **Next actor:** Quill builds it.

## What changed and why

Michael widened his item (via Seneschal): drops are removed altogether. That means personal
items and the already-dead home-block material drops alike, with no measurement first.
`LEGACY_EXTRA_SHIFT_DRAW` goes in the same PR.
- **BACKLOG:** "Remove dropped personal items" becomes "Remove drops altogether". The two
  items that point to it ("NPCs find evidence" and the audit cleanup) follow the new name.
- **DESIGN:** the Drops paragraph says drops are to be removed, and the Framer line goes
  with them.
- **Settled by Michael:** `search` stays at the eight town locations. It still finds the
  Revenant's totem and the place's regulars.

## Checked

Docs only; nothing was run.
