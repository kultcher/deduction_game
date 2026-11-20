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

## Project docs: moved into the repo (Nov 16, Bailiff)

Done in Bailiff's `claude/handoff-docs`. The live belief-model doc is `docs/belief_model.md`,
the rest is under `docs/archive/project-docs/` (its README maps each one), and the Nov 13
triage is `docs/archive/playtest_triage_2026-11-13.md`. Code no longer cites Project docs.
Only dated entries in the handoff log and archive still name them, as history.

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

- ~~`LEGACY_MUD_DROPS_ENABLED`~~ and ~~`LEGACY_EXTRA_SHIFT_DRAW`~~: removed with the drops
  (Nov 19, Quill), in one golden re-baseline.
- `USE_FLAVOR_SECRETS = false` (benched flavour secrets): `world.gd:462` and the content
  behind it. Decide whether this is parked or dead.
- `CONNECTIONS`: on by default since #160 (Nov 16), and removed with the earlier model in
  purge phase 3 (#290, Nov 18); `--legacy-model` now stops with a note.
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

## Playtest 26532 (Nov 16, Claude playing, Michael driving; connections switch off)

Won on day 4: Edda (Demon) and Isolde (Breathstealer) hanged, then Nisha (Scion, promoted).
No wrongful executions, 5/7 innocents alive.

- **None of the Muddler's gossip was muddled.** Hollis was the Muddler, and every relay he
  passed on came through intact.
- **The case against Isolde as the Breathstealer didn't land as well as it should have.**
  The chain was complete: Lian was killed, so his Archivist reading "Greta or Isolde" was
  true; Merrin was silenced on day 1; Greta never shared her block (#78, Merrin alone at
  the mill that evening); Isolde did. The filed case still got 4/10 on day 2. She hanged on
  day 3 once Dorian's Dowser reading and the town's mood caught up.
- **The town didn't connect Merrin's two "cannot remember" Confessor visits to Nisha.**
  Both visits were on the Market, and on night 2 Nisha was the only living Market resident
  besides Merrin. The day-3 Nisha nomination failed 3/9. It passed on day 4 only after a
  vigil caught her at the kill and the mill traces matched.
- **Vigils look very strong.** "Arrived" means the target was on that block, so a vigil
  on the right block catches the demon outright. The night-3 vigil ended the case. This
  bears on DESIGN.md's "Is unlimited Vigil too strong?"
- **Breaking ward promises cost little that showed.** Two were broken, and Fenwick came
  to the player with gossip a day later.
- **Grimoire bug:** Greta (good) relaying Edda's fake Clerk reading is logged as Greta's
  own lie ("Evil: tells Hollis their Clerk reading… (heard from Edda)" and [LIE] in
  `grimoire talk`), so her lie count reads 1.
- **Evil fabrication didn't check whether it implicated the liar.** Isolde's fake
  Magistrate result ("Greta and Lian shared an alignment") made her own guilt follow from
  Lian's public Archivist reading.
- **Defence mismatch:** Isolde answered "Your case rests on where I was last night" to a
  case about day-1 whereabouts. **Fixed (Nov 16, Herald):** a sighting by day that a case
  cites was read as a night sighting of the same number (day 1 evening → "night 1", spoken
  "last night" on day 2). It's now its own kind of item, and the hinge is the heaviest
  cited item a defence can answer (a reading or a night).
- **`ask night` doesn't return night-action results** (Confessor, Lamplighter). Not on the
  backlog or in the handoff log under any owner. **Built (Nov 16, Herald):** after the
  night's errand, the gift's result for that night is said again if told before, held back
  in words if not, or "nothing" if it showed nothing.
- **A good NPC hiding a gift lied "home all night"** (Hollis, the Lamplighter). Same
  pattern as the Jory open item in `docs/belief_model.md`.
- **Seed reproducibility:** restarting case 73398 after a crash dealt different roles and
  a different first morning. See the seed section below once it's investigated.

### Seed reproducibility: the cause (Nov 16)

Not a determinism bug in the simulation. **In the game UI, a dynamic script and the case
are seeded separately:**

- The case seed (the title-bar box, `ui/main.gd` `_new_case`) seeds the world:
  schedules, homes, the night-0 RNG and so on.
- The **dynamic script** is rolled on the New Case screen from its own random seed
  (`ui/new_case_screen.gd` `_roll_dynamic`: `sd = randi() % 1000000 + 1`). That decides
  which gifts, minions and secret are on the script, and so who is dealt what.
- So typing case 73398 again with a freshly rolled dynamic script gives the same
  population and seed but a different roster. The deal differs, the town draws diverge,
  and so does the first morning.

The sweep tools don't have this problem: `autoplay.gd --dynamic` builds
`ScriptBuilder.dynamic({"seed": s})` from the case seed itself. Replays from a dev log are
also fine, since `case_start` setup records `script.to_dict()` (`sim/world.gd:412`).

**Fixed (Nov 16, option 1):** the New Case screen builds the dynamic script from the case
number, and has a "Case number" box so a number can be entered at launch. Reroll picks a
new case number. Checked in `tools/test_ui.gd`.

Options considered:
1. **Derive the dynamic script from the case seed** in the UI, as the sweep does. Then
   one number reproduces a whole case. The New Case screen's reroll button would then
   change the case seed rather than only the script.
2. Keep them separate but show the script's seed ("Dynamic #NNN") with the case seed,
   and let a seed entry restore both.
