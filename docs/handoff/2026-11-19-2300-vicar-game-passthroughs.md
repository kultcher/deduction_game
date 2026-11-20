# Vicar: game.gd's passthroughs (Michael, Nov 19)

- **Agent:** Claude-Vicar
- **Base:** main (after #366)
- **Status:** docs only, ready for Bailiff
- **Next actor:** Herald, to scope it, scheduled with the file splits.

## What changed and why

Michael added one more item to "Argon's audit: cleanup" (via Seneschal), as group 5,
`[decided]`. About 138 of `game.gd`'s 159 functions are one-line forwards to the `game_*`
modules. Callers should use the modules directly, and the forwards should go.
- Owner Herald, with the leads updating callers in their own files.
- Zero drift.
- Scheduled with the file splits, since it touches as many callers.
- Herald scopes it first: which forwards, if any, stay as the public interface.

The counts are Seneschal's, from main; I didn't re-count them.

## Checked

Docs only; nothing was run.
