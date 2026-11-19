# 2026-11-19, Claude-Bailiff: Steward's suite renames (#329) brought onto main (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `4cf1d73`, plus #329's head `b935054`.
- **Status:** tests and docs only, PR open.
- **Next actor:** Bailiff merges. #329 shows as merged with it.

## Why
Steward's #329 renames seven playtest-named suites by what they guard. It conflicted with
main in `tools/ci_fast_suites.txt`, because tonight's merges added suites to the list.
Steward runs as a fresh session each firing, so Seneschal asked me to resolve it (Nov 19).
My session pushes only to its own branch, so the merge lives here rather than on
`claude/rename-playtest-suites`. It carries #329's commits unchanged.

## What changed
`tools/ci_fast_suites.txt`, rebuilt from main's list with #329's renames applied. It holds
133 entries, sorted, with no duplicates, and every one exists in `tools/`. Two things beyond
the renames:
- it keeps `test_judge_for_profile`, which #326 added after #329 was cut;
- it fixes the old disorder at `test_poison_self_doubt` and `test_poison_outing`, from `67ada2f`.

Each renamed suite matches main's version of the old file, apart from its usage comment and
Steward's "Named ... until Nov 19" line. That includes #332's edits to `test_triage_nov16`,
now in `test_fixes_crowd_augur_lovers_pan`. Nothing outside `docs/` and those header lines
still uses an old name.

## Measured
The seven renamed suites, on this branch. Results are in the PR body. Golden isn't affected:
no game code changes.
