# 2026-11-17, Claude-Quill: a Delusional teller's wrong reading is priced once (PR #194, `claude/delusional-double-charge`; moves golden)

- **Base:** main `c676018` (#186 merged). **Status:** PR open. **Next:** Bailiff (review,
  golden-moving: merge on its own). Then I build lie severity (judge side) once Michael
  confirms the value (sent to Seneschal: 0.2, measured 0.23).
- **What (BACKLOG section 2, [decided], Michael Nov 17):** in play the role check skipped an
  evil teller's reading content but not the world's Delusional holder's. A Delusional
  reader's wrong reading therefore survived only through the 1% "healthy but wrong"
  fallback, on top of the false-report likelihood. `RoleConstraints.cs` now skips the
  content when the teller is the world's Delusional holder (live, not content-only),
  for every role-checked gift, Seer red-herring readings included. The gift's own acts stay
  checked: a Martyr's or Executor's one chosen target, a Veteran's one night. This
  generalises #183's Martyr-promise flag (`deludedPromise` is gone). Every reading's teller
  now joins the coarse memo key (`relay_mediums`), so worlds that differ only in who is
  Delusional aren't merged.
- **In game terms (fixture `tools/test_delusional_reading.gd`):** a listener who knows a
  reading is wrong (an Archivist naming two people they know are good) now gives "they were
  Delusional" about 1 chance in 7 against "they lied" 85%. Before: about 1 in 600, against
  98%. So a "Delusional" defence or challenge now has real weight; a lie is still the likelier
  explanation when Delusional is one modifier among several.
- **Not covered:** a Night Watch's list is checked in the movement model
  (`live_activity._observed`), which knows each person's alignment but not who is
  Delusional, so a Delusional Night Watch's wrong list still takes the list's own error
  there. A Delusional Medium's relay is also ruled out in the kernel's relay check
  (`relayHealthy`; pinned by `test_roles_dead`). I haven't checked whether CaseEval's
  transmission-health channel already prices that case. Both are for a later pass.
- **Golden:** re-baselined to `baseline_dba17f9` (on main `cee8811`, after #193); see `docs/golden_baseline.md`.
  - Every seed diverges from record 1, with small suspicion shifts.
  - Four outcomes are unchanged.
  - **98933 changes:** the town hangs the Revenant on day 2 and the Demon on day 3 and
    good wins. Before, it hanged Merrin, a good Surveyor, on day 3, and the case was still
    open at day 4. Her wrong-looking Surveyor reading now partly reads as Delusional.
  - Two captures were identical.
- **Suites run:** `test_delusional_reading` (new, 6 checks, in `ci_fast_suites.txt`),
  `test_workshop_reading_challenges`, all `test_roles_*` in the fast list,
  `test_location_solver`, `test_shared_model`: all pass.
- Sessions: none needed from others.
