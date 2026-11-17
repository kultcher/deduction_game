# 2026-11-17, Claude-Bailiff: docs-only PRs skip CI (`claude/nice-mayer-naok85`)

- **Base:** main `c4121b9` (#214). **Status:** CI and docs, PR open. **Next actor:** Bailiff
  merges it on green; Seneschal tells the leads.
- **Why:** Michael's decision (Nov 17, through Seneschal): docs-only PRs skip CI, and an
  agent bundles further docs changes into its open docs-only PR rather than opening another.
- **What changed:**
  - `.github/workflows/ci.yml`: a first job, `changes` ("Docs-only check"). On a pull
    request it lists the changed files (`git diff base...head`). If every one ends in
    `.md`, it sets `docs_only=true` and the suites and the Linux golden job skip, through a
    job-level `if` rather than `paths-ignore`, so skipped jobs count as passing if checks
    are ever made required. Pushes to main and manual runs always run everything. The
    Windows job was already main-and-manual only.
  - `CLAUDE.md`, Rules: the docs-only rule, in Michael's wording.
- **Why `.md` alone is safe:** I searched `tools/`, `game/`, `sim/`, `workshop/` and `ui/` for
  code that opens a `.md` file. None does; `tools/sweep_report.py` and `tools/tuning_index.py`
  only write them. `tools/ci_fast_suites.txt` is `.txt`, so a change to it still runs CI.
- **Checked:** the detection logic on sample lists and on two real merges: #180 (docs only)
  gives true, and #206 (touched `tools/ci_fast_suites.txt`) gives false. The workflow parses
  as YAML. `--no-renames` (Codex): a code file renamed to `.md` is listed under both names, so
  it still runs CI. This PR itself changes `ci.yml`, so it runs the full CI, which tests the new job's
  false path; the true path is first exercised by the next docs-only PR.
