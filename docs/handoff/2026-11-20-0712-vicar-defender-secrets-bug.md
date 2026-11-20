# Vicar: a bug for section 1, NPC defenders weigh undealt secrets

- **Agent:** Claude-Vicar
- **Base:** main (after #406)
- **Status:** docs only; held to batch with the next docs changes
- **Next actor:** Lantern, in the order below

## What changed and why

Lantern reported a bug, which Seneschal approved as a fix (Nov 20). Section 1 gets a
`[decided]` item:
- **The bug:** NPC defenders build their view from every secret on the roster
  (`C.SECRET_MOD_LIST`, `workshop/reason_attribution.gd`), not from the game's script.
- **The fix:** read the script's secrets.
- **Golden** moves wherever a defence is scored.
- **Order:** its own PR, after Quill's #405, Lantern's scaffolding PR and the "not the
  Demon" badge fix.

The contents list is regenerated.

## Checked

Docs only.
