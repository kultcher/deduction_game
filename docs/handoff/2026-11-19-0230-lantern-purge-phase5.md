# 2026-11-19, Claude-Lantern: purge phase 5, the earlier model's refresh-only code deleted (`claude/purge-phase5`; zero drift)

- **Base:** main `634332e`, with `claude/fix-red-main` (#298) merged in. **Merge #298 first.**
  **Status:** PR open. **Next:** Bailiff. Then the reading-trust "confirmed from my view" test,
  with Beadle (Michael's tiers, Nov 19). Purge phases 6a, 6b, 7 and 8 remain.
- **What went** (`docs/connections_purge_plan.md`, phase 5). All of it has been unreachable
  since phase 3, because every listener now carries the connections model's state:
  - **Spillover damping and card shaping:** `Shared.premise_shaping`, `without_shaping`,
    `_field_base`, `_shape_effect` and the shaping blend in `_evaluate_adjusted`. Also the
    shaping passes in `WorkshopOwnership._refresh` and `WorkshopWhy._union`.
  - **`Shared.evaluate` and `_evaluate_impl`** lose their `shaping` argument. The callers in
    credibility, ownership, the Why report and connections_prototype are updated.
    `_evaluate_adjusted` now takes `(plan, prepared, suspicion)`.
  - **The earlier "suspicious" pressure:** `WorkshopPresentation._other_suspicious` and
    `_filing_rise`.
  - **The earlier Why report:** the stage-by-stage branch of `WorkshopWhy.presentation`, and
    `_union`, `_reliability`, `_scale_reliability`, `_post`, `describe`, `_describe_extras`
    and `_tags`. With no stored connections breakdown (nothing to weigh), the report now says
    it isn't ready. `record` keeps only the connections summary. `case_why.gd` stays.
  - **Constants:** `PREMISE_SPILLOVER_MIN` and `PREMISE_SPILLOVER_MAX`; `tuning_catalogue.md`
    is regenerated. Spillover damping stays on BACKLOG as [tentative] (decision 5).
  - **Tests:** test_premise_step1 drops the `without_shaping` check, and
    test_connections_cases drops the "no spillover damping" check. Both called deleted code.
- **Measured:** in the PR body (golden, the fast list, and the suites these files touch).
- **Proposed for the backlog:** none.
