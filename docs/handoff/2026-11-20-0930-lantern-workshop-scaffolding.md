## Nov 20 — Claude-Lantern: the Workshop's comparison-era scaffolding removed

- **Base:** main `3b83b61`. Main gets merged in once #397 (drops) lands, per the backlog order.
  **Status:** PR open. **Next:** Bailiff. **Zero drift:** golden is identical to
  `baseline_7792e9a` at `--tol 0`.
- **What this is:** the first group in Argon's audit cleanup (`BACKLOG.md`, "Dead code, zero
  drift"). Scaffolding from when the judge was compared with the earlier belief model, plus
  every test that existed only for it (Michael's rule).

### Removed
- **The movement fixture:**
  - the "movement" fixture kind in `workshop/fixtures.gd`;
  - `movement_model.gd`'s fixture-only functions (`likelihood`, `_incident`,
    `trace_distribution`, `passer_distribution`, its cache and that cache's line in
    `caches.gd`). The live gate stays (`available`, `claim_refs`, `evidence`, `factors`,
    which defer to `live_activity.gd`);
  - the `movement_experiment` checks in `case_graph.gd`, `ui/case_workshop.gd` and
    `ui/live_case_workshop.gd`;
  - the printed-only "movement" specimen in `tests/fixtures/workshop_checkpoint_v5.json`;
  - `Tuning.Workshop.NIGHT_OUT_RATES` and `HAUNT_VISIT_RATE`, which only the fixture read.
    `tuning_catalogue.md` is regenerated.
- **`workshop/ledger_audit.gd`:** removed, along with its "aliases" gate in
  `LiveAssessment.evaluate()` and its line in the dev comparison panel
  (`ui/workshop_comparison.gd`). The rest of that panel is unchanged.
- **`legacy_evidence`:** removed from the listener snapshot everywhere (bridge, profile judge,
  the test-juror listeners, the ghost juror, `tools/analyst.gd`). Only the audit read it.
- **`tools/connections_prototype.gd` and `connections_prototype_summary.py`:** retired.
  README's code map and `docs/belief_model.md` now point to `tools/case_slate.gd` and
  `tools/autoplay.gd`.
- **Jury result keys** (sent to Herald):
  - `support_model` (the whole dict), `shared_assessment`, `pattern` and `legacy_path`;
  - each claim's `support_model` and `conditional_mass`.

  No code outside tests read them. The logic behind them stays: `_pattern` still feeds the
  verdict. Where the values still live:
  - `case_eval.movement` (was `factors`);
  - `case_eval.acceptance` (was `report_acceptance`);
  - `case_eval.posterior` (`forced_mass`);
  - `case_eval.prior` and `case_eval.category`.

### Kept on purpose
- **The ghost juror's `theories`, `reasoning_mode` and `confidence_mode`:** Jury reads
  `primary_listener.theories` with no default, and Jury, Reasoner, SupportModel and Theory read
  the two modes off the ghost.

### Tests
- **Removed:** the movement-fixture block in `test_workshop_remaining`, the audit checks in
  `test_workshop_integration` and `test_workshop_reading_identity`, the `legacy_evidence`
  redaction check in `test_workshop_provenance`, the vacuous atoms and faults checks, and the
  "states" prints.
- **Repointed to `case_eval`, `assessment` or a direct `Solver.analyze`:** checks in
  test_workshop, test_workshop_cases, test_workshop_reasoning, test_workshop_canvas and
  test_workshop_consequences. The `shared_assessment` equality checks were tautological and now
  compare `.assessment`.
- **Renamed:** `test_roles_secrets._test_muddler_domain_and_channel_parity` became
  `_test_secret_domain_and_muddler_premise`.

### Measured
- Golden is identical on all five seeds. There are no import or parse errors.
- 34 suites pass:
  - test_workshop, test_workshop_cases, test_workshop_reasoning, test_workshop_remaining;
  - test_workshop_integration, test_workshop_why, test_workshop_provenance,
    test_workshop_reading_identity;
  - test_workshop_consequences, test_workshop_presentation, test_workshop_live_cognition,
    test_workshop_canvas;
  - test_workshop_factor_cache, test_roles_secrets, test_juror_listener, test_town_note,
    test_badge_text, test_judge_for_profile, test_ui;
  - test_workshop_efficiency, test_case_eval, test_roles_official, test_workshop_card_answers,
    test_workshop_regressions;
  - test_workshop_attention, test_shared_model, test_workshop_ownership,
    test_workshop_live_canvas, test_evil_play, test_workshop_profile_receipts,
    test_workshop_votes, test_tuning_hoist.
- **Overlap:** #410 also edits `game/workshop_canvas.gd` and `game/profile_judge.gd`.
  Whichever lands second resolves a small textual conflict.
