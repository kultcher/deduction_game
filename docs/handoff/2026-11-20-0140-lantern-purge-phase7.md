## Nov 20 — Claude-Lantern: purge phase 7, the pre-CaseEval engine and the attention experiments, and the six-file audit

- **Base:** main `48ef4c5`. **Status:** PR open. **Next:** Bailiff. Zero drift.
- **Merge order with Quill's drops removal:** whichever is ready first merges first, and the
  other merges main in (agreed with Quill, Nov 19). This PR doesn't touch the files Quill's
  edits (`connections.gd`, `case_eval.gd`, `movement_model.gd`, `live_activity.gd`,
  `solver.gd`). It touches `live_assessment.gd` only at the old workload gates, which Quill's
  `dropped` edits don't reach.
- **What went:**
  - **`Jury.engine` and the pre-CaseEval engine:** the `"legacy"` switch, `_assess_target`,
    `_assess_target_inner`, `_possibility_agreement`, and `Consequences.assess`.
    `consequences.gd` keeps the four helpers the CaseEval path uses (`_prepared`, `_scope`,
    `_arguments`, `_stance`).
  - **The credibility mixture that engine ran on** (`support_model.gd`): `assess`, `_assess`,
    `_mixture`, `dimensions`, `c_source`, `_contributing`, `_add_atom`, `possibility`,
    `_possibility`, `_comparison`, `_comparison_inner`, the `comparisons` cache and the
    `reuse_comparisons` / `reuse_batches` switches. `explain`, `prior_scores`,
    `world_score`, `source_quality` and `_direct_ratio` stay: the CaseEval path uses them.
  - **The old engine's workload gates:** the "eight-reading / six-claim" and "64-state
    credibility budget" issues in `LiveAssessment.prepare` (its `mixture_budget` argument
    went) and `SharedLedger.prepare`; `Jury.engine` in `GhostJuror`'s cache key; the
    `Jury.evaluate` fallback in `SharedLedger._evaluate_adjusted`.
  - **The attention experiments:** `Reasoner.always_keep_kinds`,
    `tools/read_everything_gap.gd`, and autoplay's `--no-attention`.
  - **Tests:** `test_workshop_checkpoint` checked model v5's output on the old engine, and is
    deleted. Its fixture stays: `test_case_eval`, `test_roles_official` and
    `test_workshop_card_answers` read it. Checks of the mixture's internals went from
    `test_workshop_remaining`, `test_workshop_efficiency`, `test_roles_dead` and
    `test_demon_when_hanged`. Two checks now run through `Jury.evaluate` instead of
    `Support.assess`: the hidden-cause independence check in `test_workshop_remaining`, and
    the prior-reuse check in `test_workshop_profiling`.
- **Small calls made on Michael's behalf:**
  - **`Reasoner.unlimited_cards` stays**, though the plan listed it. `test_connections_core`
    reads a listener's held cards through it, and the 6b measurement (attended against held
    cards) needs it. Its comment now calls it a test and measurement hook. `--no-attention`,
    the only way play could set it, went.
- **Coverage this drops, worth knowing:** these mixture checks have no CaseEval equivalent:
  - a withdrawn retelling counts for nothing while the original reading still counts
    (`test_workshop_remaining`);
  - distrusting a Medium, or the dead speaker it relays, lowers the relay's acceptance, and
    a faithful relay doesn't corroborate an identical original (`test_roles_dead`);
  - a poison episode counts once, and a bare poisoning claim gets no free discount.

  The CaseEval path's own handling of relays and withdrawals is covered elsewhere
  (`test_relayed_alibi`, `test_roles_dead`'s remaining Medium checks), but not in those
  exact forms.
- **Measured:**
  - **Golden:** identical to `baseline_652298a` at `--tol 0`; two captures were identical.
  - **Suites that pass:** `test_demon_when_hanged`, `test_workshop_remaining`,
    `test_workshop_efficiency`, `test_workshop_profiling`, `test_roles_dead`,
    `test_case_eval`, `test_roles_official`, `test_workshop_card_answers`,
    `test_workshop_reasoning`, `test_workshop_attention`, `test_workshop_cases` and
    `test_connections_core`.
  - **CI runs the rest of the fast list.**

### The six-file audit (Argon's Tier 3 list, Seneschal's brief)

For each pre-connections leftover in the six files, which phase removes it, or why it stays:

- **`workshop/jury.gd`:**
  - `engine` and `_assess_target*`: gone in this PR.
  - `_headline`, `_headline_chance`, `_headline_group_key`, `_directional`, `_source_trust`:
    6a.
  - `support_model` and the placeholder `legacy_path` in `_assess_target_eval`'s result: they
    stay for now. Herald's fixture-mode jury window reads them
    (`ui/case_workshop.gd` ~793), and Herald is removing that block. The placeholder's name
    goes in phase 8 once nothing reads it.
- **`workshop/reason_attribution.gd`:**
  - the header "Phase 2a of the legacy retirement plan": phase 8.
  - `_headline_chance` and the unattended-report route (`:209-211`, `:658`): 6a.
- **`workshop/live_assessment.gd`:**
  - the legacy mixture gates: gone in this PR.
  - "Legacy opinion Psychologist readings" (`:284`, `:544`) stay. They concern the older card
    shape for a Psychologist opinion, not the belief model, and the 2026-11-05 test audit
    left them as a design call.
- **`workshop/shared_ledger.gd`:**
  - the legacy gate and the `Jury.evaluate` fallback: gone in this PR.
  - "off by default" (`:110`): phase 8.
  - the `_headline` mention in the route-trust comment (`:323`): 6a.
- **`workshop/reasoner.gd`:**
  - the world search (`search`, `_search`, `_find`, `_swaps`, `_find_live`) is **live**, not
    dead. `Support.explain` calls `Reasoner.search` (`support_model.gd`, `_explain`).
    `Jury._assess_target_eval` and `SharedLedger` call `explain` on the CaseEval path, so the
    search stays. It isn't an addition to phase 7.
  - `prepare`, `direct_checks` and `unlimited_cards`: live, and they stay.
- **`ui/case_workshop.gd`** (Herald's file): live. It's the base of `case_workshop_canvas.gd`
  and `live_case_workshop.gd`, and its base context menu (`_context_action`) is used by the
  live Workshop. Its fixture-only paths (`_load_example`, `_open`, LoadMockup,
  WorkshopExperiment, the fixture-692 jury window) are reachable only from suites once
  Herald's dead-labs PR deletes the two lab scenes. Herald removes them in a fixture-mode
  follow-up. `ui/workshop_comparison.gd` stays: the live Workshop preview uses it, so
  Argon's audit was wrong to list it.
- **Proposed for the backlog:** none.
