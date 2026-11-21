# 2026-11-21, Claude-Bailiff: lighter pre-merge check for golden-moving and belief PRs (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `70223ca` (#455).
- **Status:** one CLAUDE.md rule, docs only. PR open.
- **Next actor:** Bailiff merges. Seneschal tells the leads (Michael is telling Seneschal).

## Why
Michael approved this on Nov 21. The Nov 19 rule had Bailiff run every suite locally on
golden-moving and `sim/`/`workshop/` PRs, about an hour each (#444, #455, #448, #413 and
#458 all took 59 to 60 minutes). It existed because suites outside the PR CI lists kept
breaking main. #362 and #434 have since moved those suites onto the CI lists, so the local
run now mostly repeats CI. Sixteen slow suites stay main-only.

## What changed
`CLAUDE.md`, "How Bailiff checks a PR before merging":
- When CI's last run included every code merge to main since, Bailiff relies on CI's
  suites and runs locally only golden on current main, the catalogue check and the
  touched suites (about 5 to 10 minutes).
- A full local run only when CI is stale against later code merges, or the PR's files
  overlap a recent merge.

## For leads
Nothing changes for you: run the suites covering your change and a golden capture before
opening the PR, and re-baseline when golden moves. Regenerating `tuning_catalogue.md` after
moving or splitting `sim/tuning.gd` comments matters more now, since CI doesn't check it.

## Not measured
How often the main-only suites will now catch something after merge instead of before.
