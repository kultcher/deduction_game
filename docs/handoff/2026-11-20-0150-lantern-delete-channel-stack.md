## Nov 20 — Claude-Lantern: delete the channel_* factored-evidence stack

- **Base:** main `23eda7a`. **Status:** PR open. **Next:** Bailiff. Zero drift.
- **Why:** this is Argon's audit, group 3 (Michael, Nov 19, BACKLOG "Argon's audit: cleanup"
  item 3). CaseEval replaced the stack, and nothing in play called it. Its only references
  were `Caches.clear_all`, a stage-name comment in `SolverBackend`, its own tests and
  profiler, and parity checks in four role suites.
- **What went (about 2,600 lines):**
  - **Game code:** `workshop/channel_likelihood.gd`, `channel_sum_product.gd`,
    `evidence_channels.gd` and `factored_channels.gd`.
  - **C#:** `workshop/cs/ChannelSumProduct.cs`, its five `SolverBridge` entry points and two
    count getters, and `SolverContext`'s program and circuit registries.
  - **Hooks:** the cache-clear lines in `workshop/caches.gd`.
  - **Tests:** `test_workshop_channels`, `test_workshop_channel_likelihood` (off the fast
    list), `test_channel_sum_product` and `test_workshop_class_parity`. The last compared
    the two compact engines, both deleted here.
  - **Oracle parity checks** ("FactoredChannels matches exhaustive ChannelLikelihood
    oracle"): one each in `test_roles_dead`, `test_roles_people` and
    `test_buildings_tavern_town_hall`, and two in `test_roles_official`. Those suites' Solver
    and CaseEval checks stay.
- **Argon's profiler goes:** `tools/profile_channel_likelihood.gd` is deleted with the stack.
  The `"channel_sum_product"` stage name stays in `SolverBackend`: it times CaseEval's
  posterior pass (`case_eval.gd:437`). Only its comment changed, so Argon's stage reports
  keep their name.
- **Quill's drops removal:** Quill reverted its `factored_channels.gd` edit when I said the
  file was going (Nov 19). Its edit to `test_workshop_channel_likelihood.gd` goes with that
  suite. No other file is shared.
- **Docs:**
  - `docs/evidence_catalog_code.md` no longer points at the channel files.
  - BACKLOG item 3 is marked done.
  - `docs/premises_plan.md` mentions `ChannelLikelihood.assess` in a dated derivation. I've
    left it as history.
- **Measured:**
  - **Golden:** identical to `baseline_0d796b3` at `--tol 0`; two captures were identical.
  - **Build:** C# build and import are clean.
  - **Suites that pass:** `test_roles_official`, `test_roles_dead`, `test_roles_people`,
    `test_buildings_tavern_town_hall`, `test_csharp_slice_c0`, `test_case_eval` and
    `test_connections_cache`.
- **Proposed for the backlog:** none.
