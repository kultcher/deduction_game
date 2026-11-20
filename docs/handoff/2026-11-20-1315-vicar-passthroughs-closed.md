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

## Also: the kill-score pass is closed

Beadle's #421 (the approved kill-score values) is merged (174191ee), so "Kill-score pass on
every role" moved to BACKLOG_COMPLETED.md, as the item itself said to do.

## Also: Argon's audit group 1 is closed

Seneschal reported that Bailiff's `tools/` sweep is done: #379 merged and dropped the Oct 30
prior experiment, and the rest of the scripts are still in use. With Lantern's scaffolding
removal, that finishes group 1. Only groups 2 (deferred) and 3 (the file splits) are left.
