# 2026-11-28, Claude-Lantern: clear_all clears the missed static caches (`claude/cache-clear-all`)

- **Base:** main. **Status:** PR open. **Next actor:** Bailiff. Golden is identical to `baseline_1bf8a4b`.
- **Why:** audit Nov 27, Part 4 item 5 (`docs/maintenance/codebase_and_release_audit_2026-11-27.md`); Michael OK'd it as fix-as-you-go. `WorkshopCaches.clear_all()` missed five static caches:
  - `RoleConstraints._names_evil_cache` and `_burden_share_cache`;
  - `CaseEval._own_delusion_weight_cache`;
  - `SharedLedger.last_reason_ctx` and `last_adjusted`;
  - `SolverBridge._lastOwnWeights`.
  - The active bug: `_names_evil_cache` keyed on the card's id without its content. A second case in one session that reused an id got the first case's answer.
- **What changed:**
  - **`workshop/caches.gd`:** clears all five.
  - **`SolverBridge.ClearContext`:** resets `_lastOwnWeights` with the other own-count buffers.
  - **`RoleConstraints.names_evil`:** keys on source, role and a hash of the card's data, as well as its id.
- **Test:** the new `tools/test_cache_clear_all.gd`, on the fast list. Two cases in one process reuse a card id for a Seer "yes" and then a "no", and each cache must be empty after `clear_all`.
  - Before the fix: 5 of 7 checks fail, including the stale answer.
  - After: 7 of 7 pass.
- **Suites:** test_workshop_regressions, test_shared_delusion, test_burden_ill_omened and test_connections_cache (131 s) pass.
