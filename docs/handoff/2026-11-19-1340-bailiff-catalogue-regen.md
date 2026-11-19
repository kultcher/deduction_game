# 2026-11-19, Claude-Bailiff: tuning_catalogue.md regenerated on main (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `87dbbf5` (#328).
- **Status:** docs only, PR open.
- **Next actor:** Bailiff merges.

## Why
Two merges left `tuning_catalogue.md` behind the code. It's generated, and no check enforces it:
- **#332** (the juror on judge_for_profile) made `game/workshop_canvas.gd` read
  `JURY_CHALLENGE_LYING_MIN_AGR`, but didn't regenerate the catalogue.
- **#328** (Steward's DEEP report) carried a catalogue generated before #319. Merging it
  brought back `sim/social.gd` in `TRUST_VOTED_FOR`'s "used in" column, which #319 had
  removed.

## What changed
`python3 tools/tuning_index.py` on main `87dbbf5`. The two "used in" cells now match the code:
- `TRUST_VOTED_FOR`: `sim/world.gd` only.
- `JURY_CHALLENGE_LYING_MIN_AGR`: adds `game/workshop_canvas.gd`.

No values or comments changed.

## Noted, not changed
`tools/ci_fast_suites.txt` isn't fully sorted: `test_poison_self_doubt` and
`test_poison_outing` sit after `test_premise_centring`. This dates from commit `67ada2f`, not
tonight's merges. It's harmless, and it's left for the next PR that touches the list.
