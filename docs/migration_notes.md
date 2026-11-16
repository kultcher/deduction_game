# Claude Code migration: working notes

Collected Nov 15–16 for the move from the desktop chats to Claude Code. Feed into `CLAUDE.md`
and the doc reconciliation once the chats' exit handoffs are in.

## Michael's direction (Nov 16)

1. **Fun is settled.** The core loop feels good: Michael replays it for fun, not to test.
   Outside playtests are still wanted. Onboarding and tutorials are planned, but come
   **after** mechanics settle, so that work isn't redone.
2. **Tuning is by feel.** The main check is "in hindsight, was this case unsolvable or too
   easy?" The 85–90% identify / 70–75% win targets are loose guides. A/B against the
   previous build exists to keep drift within reason, not to chase the target.
3. **Connections is the current big migration.** The plan is a purge of what it replaces,
   like the Nov 1–3 legacy belief-system retirement
   (`docs/archive/legacy_retirement_plan.md`). Earlier purges may have left artifacts
   (see the audit below).
4. **Argon is out of the loop for now.** Google's new model "Carbon" may come back in,
   mainly for performance work, which Argon was strong at. Keep the Drive patch workflow
   documented but marked inactive.
5. **The 10-NPC town is the default mode.** The 7-NPC town is for tutorials and early
   games. Larger towns are possible later. The focus now is refinement and expansion, not
   proving the core loop. DESIGN.md's "keep the 7-person town until the core loop
   reliably works" open question is stale.

## Project docs to bring into the repo

Claude Code can't read claude.ai Project files, but the repo cites these (the belief-model
doc 7 times, including the header of `workshop/connections.gd`). Copy them into `docs/`
during the migration:

- `claude/belief-model-direction-2026-11-10.md` (the connections spec and its results)
- `claude/playtest-triage-2026-11-13.md`
- `claude/premises-plan.md` (check it against `docs/premises_plan.md`)
- `claude/legacy-migration-plan.md` (probably superseded by
  `docs/archive/legacy_retirement_plan.md`)

## Legacy leftovers audit (Nov 16)

A static pass over `game/`, `sim/`, `ui/` and `workshop/`: files, functions and `sim/tuning.gd`
constants that nothing in game code references. Nothing was built or run. No source file
is fully orphaned, so the leftovers are inside files.

### A. The GDScript↔C# parity harness (solver retirement, Nov 4)

The GDScript kernels were retired Nov 4 (`workshop/solver_backend.gd` header; snapshot
branch `archive/gdscript-solver-final`), but the C# side of the cross-check remains:

- `workshop/cs/SolverBridge.cs`: about 25 methods no game code calls. These are
  `Verify{Float64,Int32,Int64,Byte}Buffer`, `VerifyScalar{Bool,Int64,Float64}`,
  `GetVerifyCalls`/`GetVerifyMismatches`, `GetMode`/`GetModeName` (`SetMode(1)` is still
  called "as a label"), the `GetRegistered*Count`/`GetCachedUniverseCount`/`GetWorldEntryByteSize`
  counters, `EvalMathBatch`/`EvalLerpfBatch`, `DomainWorldKeys`/`DomainHealthyTable`,
  `RoleCoarseMasks`/`RoleFitsTable`/`RoleFitsWeights`/`RoleBluffWeights{Simple,Temporal}`,
  and `SolverUnresolvedMask`. Only `tools/test_csharp_slice_c0.gd` touches some of them.
- About 50 "legacy/fallback" comment mentions across `SolverBridge.cs`, `SolverKernel.cs`,
  `CaseEvalKernel.cs` and `ChannelSumProduct.cs`. Many describe "bit-exact port of X.gd",
  and X.gd no longer exists.
- `workshop/solver_backend.gd`: `is_csharp_available()` (always true or it asserted) and
  the profiling helpers are tool-only. That's fine; keep them as dev tools.

### B. The belief-system purge (Nov 1–3): naming and plumbing left behind

The behaviour is gone, but its names and plumbing remain:

- **"Legacy fallback" reporting is now mislabelled.** `WorkshopOwnership.fallback`
  (`game/workshop_ownership.gd:257`) is the live Phase 3 decision: keep the last good
  shared vector and log. But it logs as `legacy_fallback`, and the dev report says "the
  **legacy rules judged** N things" (`game/game.gd:91`, `game/game_day_night.gd:633-652`,
  `case_summary.legacy_fallbacks`). No legacy rules exist to judge anything. Rename it to
  something like "unprepared refreshes".
- **The Workshop canvas still advertises a legacy mode.** `game/workshop_canvas.gd:180-181`
  returns `"mode": "legacy"` with the warning "Fallback evaluates … using the existing
  argument system". That system (`sim/argue.gd`) was deleted in Phase 4d, and
  `game_presentation.gd` blocks the submission instead. The `"Adapter available" /
  "FALLBACK"` notes (lines 19-53) date from the same era.
- **`legacy_evidence`** is built in `game/workshop_bridge.gd:180` and passed in empty
  stubs (`workshop_canvas.gd` ×3, `workshop_why.gd`, `ghost_juror.gd`). Its only reader is
  `workshop/ledger_audit.gd:23`. Check whether the audit still needs it.
- **`fallback_count` / `present_fallbacks`** (`game/game.gd:90`,
  `game_presentation.gd:379`): check what still increments it now that there's no legacy
  route.
- `sim/deduction.gd:3`: a docs link to `docs/legacy_retirement_plan.md` (now under
  `docs/archive/`). The `normalize()` comment says "old names kept working". Check whether
  any save or log still uses the old names.
- `sim/world.gd:67`: `knell_night` is marked "(legacy)", and `_sexton_knell()` (line 1360)
  is never called.

### C. Off switches and dead knobs in `sim/tuning.gd`

- `LEGACY_MUD_DROPS_ENABLED = false`, read once (`game_day_night.gd:405`). Its branch is
  dead.
- `LEGACY_EXTRA_SHIFT_DRAW = 0.3`: "kept only so setup draws stay aligned". Removing it
  shifts every seed, so it needs a deliberate golden re-baseline. That's a good thing to
  fold into the next planned re-baseline.
- `USE_FLAVOR_SECRETS = false` (benched flavour secrets): `world.gd:462` and the content
  behind it. Decide whether this is parked or dead.
- `CONNECTIONS = false`: the current migration. Leave it alone.
- **21 constants that nothing reads**, including `MISLEADING_TRACE_CHANCE` and
  `RIVAL_CLAIM_EFF` (both labelled retired), `SHARE_TRUST_BUMP` ("superseded Oct 30"),
  `PARANOIA_DRIFT_RATE` ("unused since Oct 30"), the 10 `SHARE_ROLE_HINT_*` /
  `SHARE_ROLE_CLAIM_*` keys, `NIGHT_DOUBT_CAP`, `CHALLENGE_SOURCE_PENALTY_SCALE`,
  `ALLOW_UNANCHORED_PLAYER_NOMINATION`, and the `HEARTHWITCH` / `CLERK` / `ARCHIVIST` /
  `RUMORMONGER` gift dicts. Check for dynamic lookups by name before deleting. The header
  also keeps `Activity` / `Public` / `Speech` aliases "for backward compatibility".
  `tuning_catalogue.md` lists all of these.

### D. Smaller dead functions (game code, never called)

`game/board_model.gd` `shown_cards`; `sim/deduction.gd` `conflict_of`; `sim/mind.gd`
`night_reliability`, `_spoken_list`; `sim/social.gd` `_implicated`; `sim/world.gd`
`player_locations_on`, `_medium_text`, `_sexton_knell`; `ui/card_list.gd` `meta_at`;
`ui/portrait_badge.gd` `get_grayscale`; `ui/soundtrack.gd` `set_enabled`, `set_volume_db`;
`workshop/case_why.gd` `_log_ratio`; `workshop/day_presence.gd` `at_any`;
`workshop/public_evidence.gd` `victim_effect`; `workshop/cs/SolverContext.cs` `WithConverted`.
Some of these are probably UI hooks for later. Others (`ui/main.gd` `_open_theory`,
`finish_streaming`, `mind.gd` `seer_picks`, `claim_credence`) are used only by tests.

**Method caveat:** these are name matches, so a call through a string (`call("name")`, a
signal wired in a `.tscn`, `has_method`) would show as dead. Grep for the string before
deleting anything.
