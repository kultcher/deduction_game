# Maintenance runs (Claude-Steward)

A scheduled task runs this Monday and Thursday early morning, US Eastern: a **STANDARD** run
on Monday, a **DEEP** run on Thursday. Michael or any agent can also ask for one. The output
is one PR from `maintenance/<date>`, with the report and doc-only fixes.

## Scope

Everything that landed on `main` since the last report: find the previous report's commit
range (its first lines), and review from its end to `origin/main` now.

## The report: `docs/maintenance/<YYYY-MM-DD>.md`

Follow the newest report's layout. Sign it `Claude-Steward`, and give the commit range, the
PRs in it, and the run type.

- **Needs Michael:** short numbered points, most important first. Is anything broken on
  `main`; decisions waiting on him; anything that undoes behaviour he set. If nothing needs
  him, say so.
- **A. Code review:** read the diffs of every merged PR in the range and the code around
  them. Report real bugs with file and line, and why they matter in play. Don't fix code in
  the report PR: name the owning lead (see `CLAUDE.md`) so they can pick it up.
- **B. CI and behaviour drift:** CI results on `main` in the window, the golden baseline
  and any re-baselines (were they recorded in `docs/golden_baseline.md`?), and any sweeps
  that ran. Say what wasn't measured.
- **C. Design rules:** check the window against the guardrails in `CLAUDE.md`:
  per-role special cases, modern words or numbered nights in spoken text, logged reasons
  for lies, determinism, and nothing that pushes NPCs toward a perfect solver.
- **D. Docs:** drift between the code and `DESIGN.md`, `README.md`, `BACKLOG.md`,
  `TUNING_NARRATIVE.md`, `tuning_catalogue.md` (regenerate it with
  `tools/tuning_index.py`) and `CLAUDE.md`. Fix doc-only drift in this PR and list each fix.
- **E. Deep run only:**
  - **E1. Test audit:** tests added or changed since the last deep run. Do they test what
    they claim? Any that can't fail?
  - **E2. Housekeeping, list only:** merged branches Michael can delete, stale `mock/` and
    `sweep-results/` branches, unused files. Never delete anything yourself.
- **Could not check:** anything you couldn't build, run or reach.

## Rules

- Describe effects in game terms, as `CLAUDE.md` asks.
- Build and run the suites the window touched if you can (`CLAUDE.md` has the commands);
  otherwise say the review is from reading only.
- Add a handoff entry in `docs/handoff/`, as for any PR. Bailiff merges the report PR.
