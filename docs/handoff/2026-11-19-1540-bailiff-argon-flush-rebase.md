# 2026-11-19, Claude-Bailiff: Argon's dawn belief flush (#289) brought onto main and re-baselined (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `7d9246f` (#341), plus Argon's `argon/dawn-belief-flush` at `72be00b`.
- **Status:** PR open. It carries #289's commits unchanged, so #289 shows as merged with it.
- **Next actor:** Lantern and Beadle, to re-check the flush. Then Bailiff merges it as the next
  golden-moving PR.

## Why
#289 had sat since Nov 18 on a main eleven golden-moving merges behind. Michael's rule is that
minor fixes to Argon's PRs are made here rather than sent back, and merging main plus
re-baselining counts as minor. Seneschal asked for it (Nov 19). My session pushes only to its
own branch, so the merge lives here.

## What changed
- **Merge:** main `7d9246f` into Argon's head `72be00b`. The conflicts were the `BASELINE`
  line in `ci.yml` and `docs/golden_baseline.md`; I took main's side. `sim/mind.gd` and
  `sim/world.gd` auto-merged, and they match a fresh `git merge-tree` exactly.
- **Stale baseline dropped:** `tools/golden/baseline_fe833dc`, which never reached main.
- **Re-baselined:** to `tools/golden/baseline_2ac19a1`, with BASELINE and "Current baseline"
  updated. Two captures were identical with engine fields included.

## Measured
Against `baseline_2829999`, every seed diverges at the first night's refreshes, with fewer
refresh records:

| Seed | Refresh records |
|---|---|
| 42 | 69 to 64 |
| 54875 | 301 to 293 |
| 692 | 250 to 245 |
| 900 | 138 to 132 |
| 98933 | 253 to 245 |

Belief values differ in the third or fourth decimal place. **All five outcomes are
unchanged:** the same hangings, days, nominators, voters and winner. Suite results are in the
PR body.

## For Lantern and Beadle
Please check that the single end-of-night flush still covers the refreshes added since
Nov 18:
- #306: the Warden's guard report joins its night's movement group.
- #319: reading trust counts in the same refresh's solve.
- #320: self-doubt asked of the judge when first read.

In each case, does a refresh the flush now skips carry something those changes rely on?
