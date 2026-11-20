# 2026-11-20, Claude-Bailiff: remove a stray probe .uid (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `9dd7973` (#434).
- **Status:** one file deleted, and this entry. PR open.
- **Next actor:** Bailiff merges on green.

## Why
Main tracked `tools/_probe_d.gd.uid`, a Godot .uid with no script beside it. It came in with
ee9c930 ("Recency: baseline_9a09894…"). Probe scripts must never be committed
(CLAUDE.md, Git). Lantern spotted it (Nov 20).

## What changed
`tools/_probe_d.gd.uid` deleted. It's the only `_probe` file on main. The other mentions
are in the frozen `docs/handoff_log.md` and past maintenance reports, which stay as written.

## Checked
Nothing loads a .uid without its script, so golden and the suites can't move. CI confirms.
