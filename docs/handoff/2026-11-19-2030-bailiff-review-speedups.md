# 2026-11-19, Claude-Bailiff: faster PR checks, and the slow list on belief PRs (`claude/nice-mayer-naok85`)

- **Signed:** Claude-Bailiff
- **Base:** main `74e6e74` (#361).
- **Status:** CI config, a suite list and docs. PR open.
- **Next actor:** Bailiff merges on green. Michael may want to read the CLAUDE.md change.

## Why
Michael asked how to clear the queue faster (Nov 19, via Seneschal). For a typical zero-drift
PR, most of the time went into my local re-runs: 40 to 90 minutes, longer when several ran at
once. Re-checking PRs after each merge to main added more. CI and Codex were rarely what held a
PR up. The local runs mattered because of suites PR CI didn't run: tonight `test_relay_bluff_games`,
`test_workshop_action`, `test_self_sighting` and `test_own_night_knowledge` caught changes that
PR CI passed. Michael approved these recommendations on Nov 19.

## What changed
- **(f) The slow list in PR CI.**
  - A new `tools/ci_slow_suites.txt` holds those four suites.
  - In `.github/workflows/ci.yml`, the Docs-only check now also reports whether the PR touches
    `sim/` or `workshop/`. When it does, each shard adds its share of the slow list, one suite
    per shard, on top of the fast list.
  - Main's push runs and the nightly run already run everything. The nightly run can no longer
    be cancelled by a merge, since #341.
- **CLAUDE.md:** the commands note mentions the slow list. Under Rules:
  - **(e)** a follow-up commit that changes only strings, docs or tests needs no new Codex review.
  - **(b)** zero-drift and text-only PRs merge on CI, with no local re-run by Bailiff. Bailiff
    still runs golden-moving PRs and changes under `sim/` or `workshop/` locally.
  - **(c)** wording and docs PRs may be batched into one merge pass.
- **(d) Auto-merge:** waits on Michael's repository setting. Nothing changed here.

## Not measured
The slow list adds about 2.5 minutes to each shard on a belief PR, going by tonight's local
timings: each of the four suites took about 145 to 170 seconds, one per shard. GitHub's runners
weren't measured. This PR touches no `sim/` or `workshop/` file, so its own CI won't exercise the
new step. The first belief PR after it will.
