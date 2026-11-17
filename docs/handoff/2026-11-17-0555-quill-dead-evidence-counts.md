# 2026-11-17, Claude-Quill: the end-of-case evidence counts skip the dead (`claude/dead-evidence-counts`)

- **Base:** main `59a387c`. **Status:** PR open. **Next:** Bailiff.
- **What (playtest 89077, Coroner's review, finding 7, low):** `CaseMetrics.demon_evidence`
  listed Edda's Night Watch reading as "reachable" evidence against the Demon. Edda had
  learned it the night Constance killed her, and no Medium was alive to hear it. The
  docstring already said "held by living townsfolk", but the loop never checked `alive`.
  Now a dead townsperson's readings and sightings count only while a living good Medium
  could still reach them, or a living good townsperson they told holds it (Codex).
- **Effect in play:** only the end screen's "evidence that existed" line on a loss, and
  the sweeps' `loss_hint`. Neither reads RNG or changes any decision. Golden doesn't record
  the end summary, so it's unaffected.
- **Tests:** new `tools/test_case_metrics_dead.gd` (3 checks; the dead-witness check fails
  on main), added to `ci_fast_suites.txt`. `test_demon_types`, `test_evil_play` and
  `test_ui_controls` (the other suites that touch the metrics) pass.
