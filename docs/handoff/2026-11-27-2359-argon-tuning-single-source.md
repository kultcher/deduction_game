# Handoff — Argon (`argon/tuning-single-source`)

**Date:** 2026-11-27 23:59 UTC  
**Branch:** `argon/tuning-single-source` (from `main`)  
**Goal:** Eliminate hand-copied `sim/tuning.gd` constants in `workshop/cs/*.cs` so GDScript is the single source of truth, failing loudly in both debug and release if unconfigured, with zero numerical drift.

## Sweep of `workshop/cs/*.cs`

### Tuning copies removed / unified
| C# symbol | Previous literal | `sim/tuning.gd` source | Action |
|---|---|---|---|
| `LiveActivityKernel.VigilMiss` | `0.05` | `Tuning.Workshop.VIGIL_MISS` | Injected via `SolverBridge.ConfigureTuning()` from `SolverBackend.sync_tuning()`; `double.NaN` default throws `InvalidOperationException` if read unconfigured. |
| `LiveActivityKernel.GoodOwnAlibiOut` | `0.2` | `Tuning.Workshop.GOOD_OWN_ALIBI_OUT` | Deleted (dead constant — already passed per card in `cardDoubles[cardIdx * 2 + 1]` by `workshop/live_activity_pack.gd`). |
| `LiveActivityKernel.WalkerClaimGift` | `0.95` | `Tuning.Workshop.WALKER_CLAIM_GIFT` | Injected via `SolverBridge.ConfigureTuning()` with `double.NaN` fail-loud guard. |
| `LiveActivityKernel.WalkerClaimHome` | `0.03` | `Tuning.Workshop.WALKER_CLAIM_HOME` | Injected via `SolverBridge.ConfigureTuning()` with `double.NaN` fail-loud guard. |
| `LiveActivityKernel.WalkerClaimSecret` | `0.02` | `Tuning.Workshop.WALKER_CLAIM_SECRET` | Injected via `SolverBridge.ConfigureTuning()` with `double.NaN` fail-loud guard. |
| `RoleConstraintsKernel.MarkedDemonChance` | `0.5` fallback | `Tuning.Setup.MARKED_DEMON_CHANCE` | Already injected at bridge init; replaced silent `0.5` fallback with `double.NaN` fail-loud guard and unified into `ConfigureTuning()`. |

### Other non-trivial float literals verified as structural (not tuning)
- `CaseEvalKernel.cs:135-136` (`0.1875`, `0.25`): Augur slot probabilities (`3/16`, `1/4`) from 4-block geometry.
- `CaseEvalKernel.cs:335` (`4.0`, `9.0e18`): `Int64` packing overflow guard.
- `CaseEvalKernel.cs:1143,1147` (`0.02`, `0.98`, `1.5`): Suspicion clamping bounds (`priorK` is already passed as a parameter).
- `LiveActivity.cs:24` / `SolverContext.cs:168` (`GdFloor1e30`): Bit-exact IEEE-754 representation of GDScript's `1e-30` floor.
- `LiveActivity.cs:798-820` (`0.75/0.15/0.1`, `0.9/0.1`): Unclaimed-person and non-walking-role-claim profile mixture weights (`live_activity_profiles.gd`), not in `sim/tuning.gd`.
- `LiveActivity.cs:857,860,861,875` (`0.25`, `0.55`, `0.05`): Base night-out profile rates (`PROFILE_RATES` in `live_activity_profiles.gd`), not in `sim/tuning.gd`.
- `LiveActivity.cs:976,980` (`0.1`, `0.9`): Unknown-role gift Lamplighter-tour vs single-destination split.
- `LiveActivity.cs:1109` (`0.7`, `0.3`, `0.9`): Evil/quoted alibi likelihoods (explicitly noted as fixed in `sim/tuning.gd:1185`).
- `LiveActivity.cs:1162` (`0.6`, `0.4`): Non-family Demon trace evening-block vs uniform-block split.
- `LiveActivity.cs:1447,1458,1476,1606` (`0.7`, `0.1`): Habitual evening haunt distribution (`0.7` haunt + `3 × 0.1` other blocks).
- `LiveActivity.cs:1785` (`evP = 0.25`): Uniform prior over `BlockCount = 4` evening blocks (`1.0 / 4`).

## Changes
- `workshop/cs/LiveActivity.cs`, `workshop/cs/RoleConstraints.cs`, `workshop/cs/SolverBridge.cs`: Replaced C# tuning copies/defaults with `double.NaN`-guarded properties configured via `SolverBridge.ConfigureTuning(...)`. Added `IsTuningConfigured()`, `GetConfiguredTuning()`, `GetModifierCodes()`, and `VerifyTuningFailLoud()`.
- `workshop/solver_backend.gd`: Added `SolverBackend.sync_tuning()` called during `_bridge()` init.
- `sim/tuning.gd`: Updated comments on `VIGIL_MISS`, `GOOD_OWN_ALIBI_OUT`, and `WALKER_CLAIM_GIFT` to reflect injection instead of manual mirroring.
- `tools/test_cs_tuning_parity.gd` (registered in `tools/ci_fast_suites.txt`): Verifies runtime tuning parity against `sim/tuning.gd`, tests the fail-loud guard, checks burden/modifier integer code parity across `SolverBackend`, `Solver`, `RoleConstraints`, and `SolverContext.cs`, and statically guards `workshop/cs/*.cs` against new `const double`/`const float` tuning copies or `Mirrors ... Tuning` comments.
- `README.md`: Documented the single-source tuning rule under `workshop/cs/` in the code map.

## Verification
- `dotnet build Demonologist.csproj -c Debug --nologo -v q`: 0 errors.
- Local suites passed (8/8): `test_cs_tuning_parity` (1.4s), `test_connections_cache` (119.2s, includes `Connections.cache_verify`), `test_roles_secrets` (3.6s), `test_shared_delusion` (5.0s), `test_vigil_nightwatch` (23.3s), `test_workshop_live_activity` (4.2s), `test_own_alibi_lies` (1.2s), `test_burden_unrequited_walk` (1.9s).
- Zero numerical drift: identical IEEE-754 `double` values passed from `sim/tuning.gd`. Linux CI golden diff (`--tol 0` against `baseline_1bf8a4b`) will verify on PR.
