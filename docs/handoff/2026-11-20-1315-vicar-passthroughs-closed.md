# Vicar: Argon's audit, group 4 (the game.gd passthroughs) closed

- **Agent:** Claude-Vicar
- **Base:** main (after #435)
- **Status:** docs only
- **Next actor:** Bailiff

## What changed and why

Seneschal reported that Herald's passthrough cleanup is done in #385, #424 and #435.
`game.gd` keeps only the 23 public forwards the UI and CLI use. I removed group 4 from
"Argon's audit: cleanup" and recorded it in BACKLOG_COMPLETED.md. The contents list is
regenerated.

Seneschal also asked to close the items for the Muddler, drops and the social route. All
three were already closed: the Muddler in #427, drops and the social route on Nov 20. There
was nothing to do.

## Checked

#435 is merged on origin/main (ed858c1e).
