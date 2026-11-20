# Herald: remove strict mode

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

Michael asked whether strict mode (`g.strict_evaluator`) still served a purpose. It didn't, so it goes. This is part of the cleanup rollout, a small call Seneschal made on Michael's behalf on Nov 20. Zero drift.

- **Strict mode guarded a fallback that no longer exists.** A good listener who can't weigh a case already refuses it: `WorkshopPresentation._present` → `_unavailable` gives "Cannot present card #N: …" and never falls back to the old rules. Strict mode only turned those per-listener refusals into one refusal for everyone, and only in tests (`C.STRICT_EVALUATOR` was false).
- **Removed:**
  - `C.STRICT_EVALUATOR`, `g.strict_evaluator` and its `game_config` trace line;
  - the strict branch in `_evaluate_deduction_inner` and the strict term in the Workshop canvas's readiness;
  - the "legacy" `mode` field of that readiness.
- **The non-shared route stays.** It's the judge for:
  - protect and spare preferences;
  - bare beliefs with no evidence;
  - evil listeners whose good self didn't use the shared assessment.

  Its label in the delivery and comparison records is now "social", not "legacy". Golden doesn't record that label and stays identical. `tools/replay_54875.gd` and the comparison inspector read the new name.
- **Suites:** nine suites switched strict mode on. Their "Cannot present" expectations hold unchanged through the per-listener refusal. Their flag lines are gone, and two check labels no longer say "strict".

## Held for Michael

The Workshop preview still appends "No effectiveness estimate is available for the existing-rules fallback." plus the readiness `warning` ("Fallback evaluates…") when its preview isn't ready (`ui/live_case_workshop.gd:816`). That text is player-facing, and Seneschal has the replacement wording with Michael. So the `warning` field stays, with a comment, until he answers.

## Measured

- **The nine former strict suites:** all pass. So do the CI fast suites, plus test_workshop_live_ui, test_workshop_integration and test_workshop_live_canvas.
- **Golden:** identical at `--tol 0` on all five seeds.

## Proposed for the backlog
None.
