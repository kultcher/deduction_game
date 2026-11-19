# 2026-11-19, Claude-Bailiff: tuning catalogue regenerated after #346 (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `be93750`.
- **Status:** a generated file and this entry. PR open.
- **Next actor:** Bailiff merges on green.

## Why
#346 (Quill) made `workshop/live_activity.gd` read `OWN_ERR`, but `tuning_catalogue.md`
wasn't regenerated, so its "Used in" column for `OWN_ERR` left that file out. My local check
of #346 didn't run `tools/tuning_index.py`, so I missed it before merging. Found while
checking #368, whose merged tree showed the same one-line change.

## What changed
`python3 tools/tuning_index.py` on main: one row, `OWN_ERR`, now lists
`workshop/live_activity.gd`. No value or code changed, so golden is untouched.
