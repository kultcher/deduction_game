# Agent handoff log

Shared notes between Claude (checks, tests, Git) and Argon (main coding). Newest entry
first. Each entry: who, when, base commit, status, next actor, and anything the other
agent must know before starting.

Ground rules (from Nov 3, until Michael changes them):

- Argon delivers work as a zip on Drive (full files plus a manifest) and names the
  `base_commit` it was built on. Claude unpacks it on a branch from that commit, so later
  fixes are merged, never overwritten.
- `main` only moves when everything is green: `dotnet build`, the selected suites, and
  (from C1 on) a golden capture identical to `tools/golden/baseline_82faa5b` at `--tol 0`.
  Otherwise the work stays on its branch and the entry says why.
- Two failed attempts at the same problem: stop, mark `BLOCKED_NEEDS_MICHAEL`, write the
  exact error. No force pushes, nothing irreversible.

---

## 2026-11-04 ~16:00 ET, Claude: patch_011 checked, green after one test fix, on main; new baseline

- **Base:** `2e91218` as declared; unpacked on `argon/patch-011-chunks-2-3`. Keeps M1, the
  refresh cleanup, the Seer guard and the 165ce09 config; includes my 010 branch fixes.
- **Your four fixes land:** Registrar slate (seeds 9397/9400), Town Hall `theory_fit`,
  Clerk/Archivist `ROLE_IN_GROUP`, warm-greeting check: all pass.
- **One more fix (Claude):** `test_backlog_batch4` "help is read-only" / "developer summary
  formatting does not change the game" required `state == "day"`, but seed 4242 now opens
  on an approach (the new roles change the deal). They compare the state before and
  after instead.
- **Build:** 0 errors; one warning, `RoleConstraints.cs:1108` CA2014 (stackalloc inside a
  loop, possible stack overflow). Worth hoisting it out of the loop.
- **Suites:** 37 (CI fast list + chunk 2/3, role_def_poc, roster, buildings, case_script,
  UI, batch4, dialogue, legacy_migration, tuning_hoist, fixes, social, peer gossip...):
  all pass. All 286 scripts parse.
- **Golden:** new baseline `baseline_4f7ba7f` (CI updated): two GDScript captures
  identical, C# identical. Passive A/B (seeds 2000-2011): good wins 25% -> 42% at 7 NPCs,
  33% -> 8% at 10. Twelve seeds is noisy, but the 10-NPC drop deserves a bigger sweep.
- **Pushed to `main`.** Next actor: Argon (CA2014), or meeting plan M2 / M3a.

## 2026-11-04, Argon: Rebased `argon/patch-010-chunks-2-3` onto `2e91218` + Fixed All 4 Failing Checks (`patch_011_chunks2_and_3_on_2e91218.zip`)

- **Base:** `main` at `2e91218f973eada8e7fdc8bba3044a6b3199f6dd` (`2e91218`, M1 peer role gossip + Seer fix + refresh cleanup + `baseline_165ce09`).
- **Deliverable:** `patch_011_chunks2_and_3_on_2e91218.zip` in Google Drive (`Demonologist Patches`), containing all replacement/new repo files relative to `2e91218` plus `MANIFEST_CHUNKS2_AND_3_ON_2E91218.md`.
- **Supersedes:** `patch_010_chunks2_and_3_on_bdd1dc0.zip` (renamed `SUPERSEDED_patch_010_chunks2_and_3_on_bdd1dc0.zip` on Drive) and incorporates all build/parse/test-key fixes from `argon/patch-010-chunks-2-3` (`dfd7769`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`, `test_buildings_tavern_town_hall`, `test_role_def_poc`, `test_dialogue_batches_5_6_7`, `test_peer_role_gossip`, `test_case_script`, `test_ui`, `test_backlog_batch4`, `test_roster`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and intentional recapture of `tools/golden/baseline_*`).
- **Next actor:** **Claude**.

### 1. Clean 3-Way Rebase onto `2e91218`

- Preserved all `dfd7769` branch fixes (`SolverKernel.cs:739` `specInts[5] != 0`, `chronicler.gd` & `executor.gd` `ongoing_info_claim_term`, `jury.gd` `C` preload, untyped `registrar.gd:pick_targets`, baseline delta check on `SolverBackend.get_verify_mismatches()`, and `gift_accuracy:<source>:<night>` channel keys).
- Preserved all `2e91218` `main` additions and cleanups: M1 peer role gossip (`sim/social.gd`, `sim/evil.gd`, `sim/tuning.gd`, `tools/test_peer_role_gossip.gd`), `game/workshop_ownership.gd` plan reuse, `workshop/jury.gd` shallow case copy (`attention.case.duplicate(false)`), `sim/roles/seer.gd` solo-evil guard + `clean_asked` self-filter, and unioned `tools/ci_fast_suites.txt` (`test_peer_role_gossip`, `test_case_script`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`). Verified all 20 `C.GOOD_ROLES` belong to a `C.HINT_PACKAGES` family for M1 peer hints.

### 2. Root Causes & Fixes for the 4 Red Checks

1. **`test_chunk3_executor_registrar` ("Registrar Night 0 slate ... guarantees >=1 role in play", seeds `9397` & `9400`): `sim/roles/registrar.gd`, `tools/test_chunk3_executor_registrar.gd`:**
   - **Root cause:** On Night 0 in `sim/world.gd:resolve_night()`, `Poisoner` poisons a target (`by_id[poison_t].poisoned = true`) *before* `_receive_info()` runs. On seeds `9397` and `9400`, the Poisoner blind-poisoned the Registrar on Night 0, so `n.gift_broken()` was `true` and `draw_slate(w, broken = true)` intentionally took the `if broken:` branch (`registrar.gd:97-105`), drawing 3 out-of-play roles (`[dowser, seer, scion]` / `[scion, dowser, gravedigger]`) and caching them permanently into `n.registrar_roles`.
   - **Fix:** Like `Executor`'s permanent Night 0 charge, `Registrar`'s permanent 3-role register (`n.registrar_roles`) now treats only permanent `Delusional` (`n.secret_mod == "delusional"`) as broken at Night 0 slate generation (`_ensure_slate` and `w.day == 0` in `generate_reading`). A single Night 0 blind poison no longer permanently bricks the Registrar across Nights 1+ or causes `RoleConstraints`'s forced `>= 1 in-play` invariant to reject the true world on later unpoisoned nights; Night 1+ Poison still corrupts that night's target check (`reported_yes`). Added explicit regression checks for seeds `9397` and `9400`.
2. **`test_buildings_tavern_town_hall` (`CaseEval` `theory_fit == 0.000`): `workshop/case_eval.gd`:**
   - **Root cause:** `_theory_fit` called `Solver.Roles.fits_table(view, universe, cards, {}, case_data.get("answers", {}))` with `bluffs = false` (default), treating both `cl_0` (`p0` claims Seer) and `cl_1` (`p1` claims Clerk) as non-bluff true claims simultaneously alongside `th_1` (`[seer, clerk]`), leaving `0` compatible worlds.
   - **Fix:** Passed `listener.get("knowledge", {})` into `_theory_fit` (from both `_evaluate_posterior_gd` and `_evaluate_posterior_cs`) and called `Solver.Roles.fits_table` with `bluffs = Domain.live(view)` plus the same report-to-declaration fallback used by `_fits_over`, yielding `0.0 < theory_fit < 1.0` when `in_play_role` rules out one of two rival claims.
3. **`test_role_def_poc` ("Workshop solver/assessment validates Clerk and Archivist ROLE_IN_GROUP readings"): `tools/test_role_def_poc.gd`:**
   - **Root cause:** `_give()` hot-swapped roles after `g.new_case(9103, 7)` (which had already run Night 0 Poisoner, `_assign_secret_mod()`, and Day 1 Morning `_pre_pair()` conversations) without clearing `poisoned` or `known_claims` (and without clearing `delusional` on `clerk`/`arch`, even though lines 172 & 175 passed unused `{"poisoned": false}` expecting healthy readings). After Chunk 2's Night 0 RNG shift, stale pre-swap `known_claims` / Night 0 `poisoned` or `delusional` state on seed `9103` made `[c_card, a_card] + private_evidence` unsatisfiable in `Solver.solve`.
   - **Fix:** Cleared `poisoned`, `known_claims`, and `believed_roles` on both `holder` and `n` in `_give()`, and cleared `delusional` on `[clerk, arch, grave]` (and `marked` on `subject_good`) in `_test_role_in_group_hooks()`.
4. **`test_dialogue_batches_5_6_7` ("Second talk after one-shot murder greeting falls back to warm rapport greeting"): `tools/test_dialogue_batches_5_6_7.gd`:**
   - **Root cause:** `Mind.greeting_line(g.w, speaker, {})` defaults to `roll_attitude = true`, rolling `rng.randf() <= (1.0 - composure) * 0.9` (`0.90` even when `composure = 0.0`, failing 10% of the time into `greet_neutral`), and Chunk 2's Night 0 RNG count shift pushed seed `5605`'s draw into that 10% tail.
   - **Fix:** Passed `roll_attitude = false` (`Mind.greeting_line(g.w, speaker, {}, false)`) on line 332 (1-draw RNG parity with `greeting_cue` is already tested right above on lines 312-318).

## 2026-11-04 ~05:15 ET, Claude: meeting plan M1 (peer role gossip) and new golden baseline, on main

- **M1** (`sim/social.gd`, `sim/evil.gd`, `sim/tuning.gd`): NPCs privately hint at their
  gift's family to friends (bond >= 0.55) or claim it outright (bond >= 0.68, or >= 0.55
  under pressure), even with no readings; evil uses its agreed bluff with the same
  formulas. Claims fill `known_claims` (with `first_claimed_day`) and go through
  `Mind.hear_claim`; hints are remembered. Gift talk isn't relayed peer to peer. Evil
  listeners log the speaker as a threat. Good NPCs with an untold gift count as having
  news on Days 1-2. The player hears second-hand claims and hints through gossip and
  `ask about <role>`. `IDLE_CHAT_WEIGHT` 0.30 -> 0.18. Not done: the `answer_opinion`
  second-hand note.
- **Tests:** new `test_peer_role_gossip` (20 checks, in the fast CI list); 30 suites pass.
- **Passive A/B** (seeds 2000-2011, C#): good wins 33% -> 25% at 7 NPCs, 17% -> 33% at 10;
  executions similar. Noise-level for 12 seeds; M4's 150-seed sweep is the real measure.
  (A first run showed 0% for M1: that worktree's C# build was stale from the 010 branch.
  Rebuild C# after switching branches before any `--backend csharp` run.)
- **New golden baseline `baseline_165ce09`** (CI `BASELINE` updated): two GDScript
  captures identical, C# identical. See `docs/golden_baseline.md`.
- **Next actor: Argon** for patch_010 (rebase on this main; four checks listed in the
  010 entry). Next meeting-plan work: M2 trial engine (or M3a UI).

## 2026-11-04 ~04:30 ET, Claude: five failing suites fixed, Seer fix, refresh cleanup (M2 item), on main

- **Seer bluff** (`sim/roles/seer.gd`, Argon's seed-2004 trace): a lone evil Seer bluffer
  no longer "clears its teammate" (itself), and asked targets never put the bluffer in
  its own pair. None of the five golden seeds hits this, so the golden is unchanged.
- **The five suites outside CI that failed on main** (all pass now):
  - `test_dialogue_batches_5_6_7`: `DayConversationView` builds its nodes on first use
    (idempotent `_build()`), so it works before entering a running tree.
  - `test_dialogue`, `test_legacy_migration`: checked old wording replaced by voiced
    lines; now check the substance (the lie accusation; "at the meeting", no question used).
  - `test_tuning_hoist`: deleted `NIGHT_SIGHTING_ELSEWHERE` / `_NEAR_DEATH` /
    `_WALK_DISCOUNT`, unused since Phase 4 removed `night_sighting_scale`.
  - `test_legacy_purge_phase2c`: not broken, just slow (40 to 60 minutes here); passes
    with `--timeout 3600`.
- **Refresh cost cleanup** (meeting plan M2's first item): the "after" refresh reuses the
  first plan when its source doubt and candidate suspicion are exactly unchanged, and
  `Jury._consequences_eval` copies the case shallowly per person. Seed 42 to Day 4:
  `outer_prep` 280 -> 207 calls, 975 -> 835 ms self time (GDScript; wall time was noisy,
  other jobs running). I kept the before/after API for now (the golden and profiler hooks
  use it); folding it is a separate small change.
- **Checks:** 31 suites (fast list + the five + touched), plus 8 ownership/jury suites
  after the cleanup. Golden: two GDScript captures identical, C# identical, and identical
  to `baseline_82faa5b` (`--ignore engine,sus_why,sus_src`), so the baseline stands; it
  is re-recorded with M1, the first change that moves it.

## 2026-11-04 ~03:45 ET, Claude: patch_010 checked, NOT merged (5 suites red), fixes on branch

- **Base:** `bdd1dc0` as declared; unpacked on `argon/patch-010-chunks-2-3` (supersedes
  009; my 009 branch is abandoned). Merged `claude/seer-fix-rebaseline` (your equivalent
  Seer fix kept; the parameter is `n` on main now, not `_n`).
- **Didn't build or load as delivered (fixed on the branch):**
  - `SolverKernel.cs:739` `bool convEvilAtObs = specInts[5];` (CS0029).
  - `chronicler.gd` / `executor.gd` use `Tuning.Roles.ONGOING_INFO_LATER_CLAIM` and
    `ONGOING_INFO_REVEAL_COST`, which don't exist (the patch has no `tuning.gd`). Both now
    use the base `ongoing_info_claim_term(w.day)` while the gift is pending (D1 -0.45,
    D2 -0.20, 0 after), one-shot bonus once spent. Change it if you meant other numbers.
  - `jury.gd:825` uses `C` without preloading `content.gd`.
  - `registrar.gd` `pick_targets(...) -> String`: the parent has no return type, so the
    override doesn't parse.
  - Tests called `SolverBackend.reset_verify_mismatches()` (doesn't exist; the counters
    live in the C# bridge). They now compare against the count at the start.
- **Test fixes (on the branch):** channel rates keyed `accuracy:<id>:<day>:<phase>`
  (the channels use `gift_accuracy:<source>:<night>`); Magistrate bluff check passed the
  real Magistrate's nomination, which a bluffer may use; `w.secret_mod_kind` isn't a
  World field.
- **Still red, for Argon:**
  1. `test_chunk3_executor_registrar` "Registrar Night 0 slate ... guarantees >=1 role in
     play": fails on seeds 9397 and 9400 (script town archivist/clerk/dowser/gravedigger/
     seer/warden/registrar, minions poisoner/scion). Slates `[dowser, seer, scion]` and
     `[scion, dowser, gravedigger]` with the Poisoner in play: `draw_slate` took the
     `m_pick in in_minions` branch (random town pair), so at draw time it counted the
     Scion as in play. Probably the minion's role or `initial_minion_ids` isn't final yet
     when Night 0 draws.
  2. `test_buildings_tavern_town_hall` CaseEval check: `theory_fit` is now 0.000 (was 1.0
     on main). Your `_theory_fit` change adds `Roles.fits_table(view, universe, cards, {},
     answers)` with bluffs off, so the two claims count as true and no world fits.
  3. `test_role_def_poc` "Workshop solver/assessment validates Clerk and Archivist
     ROLE_IN_GROUP readings": no worlds (passes on main).
  4. `test_dialogue_batches_5_6_7` "Second talk after one-shot murder greeting falls back
     to warm rapport greeting" (passes on main; `game_conversation.gd` / greeting change?).
- Everything else in the CI fast list plus the chunk/buildings/case-script/UI suites
  passes; chunk 2 passes after the fixes.
- **Next actor: Argon.** Rebase onto `main` (it moves tonight: Seer fix, refresh cleanup,
  new golden baseline) and fix 1-4.

## 2026-11-04, Argon: Rebased Chunk 2 + Chunk 3 (Executor & Registrar) on Script-Customization Baseline (`patch_010_chunks2_and_3_on_bdd1dc0.zip`)

- **Base:** `main` at `bdd1dc0b3a0d7b9a35530b4014ad5981daa9f863` (`bdd1dc0`, Case Scripts / Script Customization push).
- **Deliverable:** `patch_010_chunks2_and_3_on_bdd1dc0.zip` in Google Drive (`Demonologist Patches`), containing all 62 replacement/new repo files plus `MANIFEST_CHUNKS2_AND_3_ON_BDD1DC0.md`.
- **Supersedes:** `patch_009_chunk2_world_mask_roles.zip` (which targeted `3340da8` right before `bdd1dc0` landed and has been renamed `SUPERSEDED_patch_009_chunk2_world_mask_roles_3340da8.zip` on Drive so you only need to unpack `patch_010` cleanly on `bdd1dc0`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_chunk3_executor_registrar`, `test_case_script`, `test_ui`, `test_backlog_batch4`, `test_role_def_poc`, `test_roster`, `test_buildings_tavern_town_hall`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and **intentional recapture** of `tools/golden/baseline_*`).
- **Next actor:** **Claude**.

### 1. Rebase onto `bdd1dc0` (Case Scripts Integration)

1. **`ScriptDef.DEFAULT_TOWN` vs `C.GOOD_ROLES` (`sim/script_def.gd`, `sim/content.gd`):**
   - `C.GOOD_ROLES` and `ScriptDef.roster().town` hold all **20** ready town roles (`15` starter + `augur`, `chronicler`, `executor`, `magistrate`, `registrar`), so `LiveAssessment`, `SharedLedger`, `ScriptEditor`, and `ScriptBuilder` recognize and offer the full expanded roster.
   - `ScriptDef.DEFAULT_TOWN` preserves the **15**-role starter Default script (`TOWN_SIZE = 15`), keeping `ScriptDef.default_script()` at `15 / 4 / 4 / 1` with zero warnings (`test_case_script.gd` green).
   - Updated `tools/test_ui.gd` (`:471,:498`) and `tools/test_backlog_batch4.gd` (`:940`) to compare `roles_box` row counts against `g.w.case_script` sizes (matching `ui/main.gd:556-564` from `bdd1dc0`), and added `ScriptDef.tags` to all five Chunk 2 + Chunk 3 roles.
   - Merged `bdd1dc0` changes cleanly with Chunk 2 in `sim/world.gd`, `game/game_screens.gd`, `sim/roles/dowser.gd`, `sim/roles/seer.gd`, and `sim/roles/surveyor.gd`.

### 2. Chunk 3 Summary — Executor & Registrar (Sim + UI + Lockstep GDScript/C# Solver)

1. **Executor (`sim/roles/executor.gd` + `.uid`, `sim/world.gd`, `workshop/live_history.gd`, `workshop/source_doubt.gd`):**
   - **Night 0:** Learns one other townsperson (`data: {"target": id, "assigned": true}`), recorded as a shareable Night 0 reading. Delusional Executors still get a real charge on Night 0 and only receive a corrupted role on death.
   - **Morning Post-Death Trigger (`_morning_executor_gifts` in `start_phase()`):** On `Morning` (`day >= 1`), if the Executor's charge died yesterday or last night (`executed`, `demon`, or `martyr`), learns their role (`data: {"target": id, "role": role}`). Checks `gift_broken()` on that Morning (honoring Night `d-1` Poison, which wears off on Night `d`), applies Gravedigger's 30% `Marked` evil-role misread scoped to `w.case_script`, and supports Scion promotion when an executed original Demon (`alive_before >= 5`) is read as `"demon"`.
   - **Workshop & C# Lockstep (`RoleExecutor = 11`):** Enforces target consistency across Night 0 + Morning Executor cards (`executorTargetToken`), `History.died_before_morning` timeline verification (`(death_tick / 4) + 1 == morning_day`), `SourceDoubt` caught-lie/sincerity rules, and `PoolAny` + Scion-promotion role assignment.
2. **Registrar (`sim/roles/registrar.gd` + `.uid`, `game/game_conversation.gd`, `ui/main.gd`, `workshop/role_constraints.gd`, `workshop/cs/RoleConstraints.cs`):**
   - **Night 0 Slate:** Learns 3 distinct roles drawn strictly from `w.case_script` (`town` minus `"registrar"`, plus at most 1 from `minions` at 50% odds, never `"demon"`), with **at least 1 role guaranteed in play** (`data: {"roles": [r0, r1, r2]}`). A Delusional Registrar draws 3 out-of-play script roles when available.
   - **Night 1+ Target Checks & Player Requests:** Checks one other person each night (`data: {"roles": [...], "target": id, "yes": bool}`), supporting player `"ask check <name>"` / `"ask register <name>"` requests and UI picker. `Marked` triggers a 50% false `Yes` **only** when a Minion role is on the 3-role slate, and never suppresses a true good-role match.
   - **Workshop & C# Lockstep (`RoleRegistrar = 12`, `CardStride = 24`, zero `SolverBridge.cs` signature changes):** Enforces slate consistency across cards, `~regNoMask` exclusion on all 3 slate roles (automatically catching fake claims of any listed good role), `Yes` branching across the 3 roles + `Marked` (clearing Demon on any `Yes`, clearing all Evil on a 3-good-role `Yes`, and deducing `Marked` if the same target reads both `Yes` and `No` on a Minion-bearing slate), and **forced 1+ in-play slate matching** composed directly with `TownHallMatches` and `FactoredChannels` (`town_hall_pool`).

## 2026-11-04, Argon: Roster & Mechanics Chunk 2 - World-Mask Townsfolk + Dowser Public Fix (`patch_009_chunk2_world_mask_roles.zip`)

- **Base:** `main` at `3340da8575198d878a90bbe819ab5ca506791b73` (`3340da8`, 11:43 PM EST archive with `patch_008` + Town Hall art merged).
- **Deliverable:** `patch_009_chunk2_world_mask_roles.zip` in Google Drive (`Demonologist Patches`), containing all 45 replacement/new repo files plus `MANIFEST_CHUNK2_WORLD_MASK_ROLES.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_chunk2_world_mask_roles`, `test_role_def_poc`, `test_roster`, `test_buildings_tavern_town_hall`, `tools/ci_fast_suites.txt`, `--tol 0` C#/GDScript parity check, and **intentional recapture** of `tools/golden/baseline_*` since Chunk 2 changes `GOOD_ROLES`, `IDENTIFIER_ROLES`, `HINT_PACKAGES`, `Dowser` public-only eligibility, `Surveyor` Night-0 gift semantics, and `seer.gd` solo-evil bluffs).
- **Next actor:** **Claude**.

### 1. Answers to Claude's `patch_008` Handoff Notes

1. **Town Hall `theory_fit` (`case_eval.gd:410,477` & `test_buildings_tavern_town_hall.gd:326`):**
   - Confirmed: in `CaseEval`, `_fits_over` passes `{}` (empty answers) to `Solver.Roles.fits_weights`, so `post` is intentionally NOT conditioned on `case_data.answers`; instead, `_theory_fit` measures the share of `post` consistent with `case_data.answers`.
   - It returned `1.0` in `patch_008` only because `case_eval.gd` lines 410 (`_evaluate_posterior_gd`) and 477 (`_evaluate_posterior_cs`) gated `_theory_fit` on `not a.get("positive", []).is_empty() or not a.get("blocks", []).is_empty()`, missing `or str(a.get("in_play_role", "")) != ""` when `positive` and `blocks` were empty. Added that check to both `.gd` and `.cs` callers in `case_eval.gd` and restored `ev_res.theory_fit > 0.0 and ev_res.theory_fit < 1.0` in `tools/test_buildings_tavern_town_hall.gd`.
2. **Solo-evil Seer bluff self-pair fix (`sim/roles/seer.gd:184,196`):**
   - Included in this patch (`mate != _n` on line 196 and `x != _n.id` on `asked` at line 184) since Chunk 2 already requires a fresh golden baseline capture. Covered by regression test in `tools/test_chunk2_world_mask_roles.gd`.

### 2. Chunk 2 Summary (Sim + UI + Lockstep GDScript/C# Solver)

1. **Dowser Public-Area Fix (`sim/roles/dowser.gd`):**
   - Both the Dowser and counted blockmates must be in a public location (`not at_home()`), in both real `generate_reading` and evil `generate_bluff_reading`. Updated `tools/test_role_def_poc.gd` accordingly.
2. **Surveyor Rework (`sim/roles/surveyor.gd`, `workshop/scenario.gd`):**
   - Starts knowing (Night 0) whether all residents on a random block (**not their own**, **at least 2 residents**) share the same alignment (`data: {"block": blk, "same": bool}`). `Marked` registers evil 50%.
   - Preserves legacy `data: {"count": int}` (`ContentSurveyor = 6`) in `Scenario.generate` and `Solver`/`CaseEval` so frozen Workshop v5 fixtures (`test_workshop*`, `test_csharp_slice_c3`) stay untouched; restricts `"unlikely"` reading-challenge mode to legacy `count` Surveyor cards.
3. **Chronicler (`sim/roles/chronicler.gd` + `.uid`):**
   - Night 3 only (`w.day == 3`, `phase == "night"`), `cannot_hold_solo_secret = true`, never targets self. Reads **case-start state** (`initial_minion_ids`, `initial_evil_ids`, `initial_secret_holders`, with `Marked` always in the secret-holder slot): 3 other townsfolk (living or dead) comprising 1 ordinary townsfolk, 1 secret-holder, and 1 minion (`data: {"trio": [a, b, c]}`).
4. **Augur (`sim/roles/augur.gd` + `.uid`, `sim/world.gd`):**
   - Evening `run_day_gift` (`Day 1+`, start of Evening before player Evening action and meeting): Yes/No reading (`data: {"yes": bool}`) on whether the Augur shared a **public block** (`not at_home()`) with the Demon during **Morning or Afternoon** earlier that day (Evening excluded). `Marked` triggers 50% (no persistent Red Herring).
5. **Magistrate (`sim/roles/magistrate.gd` + `.uid`, `sim/world.gd`, `game/workshop_bridge.gd`):**
   - Night `1+`: learns whether the **first non-player, non-Magistrate nomination** that day shared an alignment (`data: {"nominator", "nominee", "same"}`), evaluated at nomination time (before any end-of-meeting Revenant curse activation on that ballot, while honoring active curses from earlier days). Produces no reading (real or bluff) if no eligible nomination occurred. Stamps `"nomination"` and `"meeting"` public events with `"evening"` phase for public timeline validation.
6. **Lockstep GDScript & C# Kernels (`workshop/solver.gd`, `workshop/cs/SolverKernel.cs`, `workshop/case_eval.gd`, `workshop/cs/CaseEvalKernel.cs`, `workshop/cs/WorldDomain.cs`):**
   - `WorldDomainKernel.GiftTime`: added `chronicler` (Night 3) and `augur` (Evening Day 1+).
   - `SolverKernel` / `solver.gd`: added `ContentParityGroup = 7` (new Surveyor + Magistrate), `ContentChronicler = 8`, and `ContentAugur = 9`, bypassing `sig_groups` when `contentMode in {8, 9}` since `sig_groups` collapses `world.Demon`.
   - `CaseEvalKernel` / `case_eval.gd`: uses `CoarseMasks` whenever `rolesOn || seer` (`seer_flag` includes `augur`) and scores `Augur` daytime overlap via `moveFactorSpecs` `kind = 2` using exact 0-ULP IEEE-754 dyadic slot probabilities (`{0.0, 0.1875, 0.25, 1.0}`, `p_ref = 87/256` or `169/256`) with zero changes to `SolverBridge.cs` method signatures.

## 2026-11-04 ~00:30 ET, Claude: patch_008 checked, green after test fixes, on main

- **Base:** `35b3861` as declared; unpacked on `argon/patch-008-buildings`.
- **Art:** Town Hall sprite (Michael's) at `assets/art/buildings/town_hall.png`, in
  `map_view.BUILDING_ART`, replacing the blank square. It sits third on the Square,
  clickable like the other buildings. With three buildings on a block the tavern's sign
  reads "Tavern" (`SHORT_SIGNS`) so it doesn't run into the well's.
- **Fixes (tests only, besides one):**
  - `test_dialogue_batches_5_6_7`: missing `Tuning` preload (the file didn't parse).
  - `test_buildings_tavern_town_hall`:
    - The fixture turned someone evil by setting `alignment` directly (no bluff, no
      shadow), which crashed meetings (`mind_meeting.gd:123` bluff lookup, `:1445`
      `role_def(...)` on Nil). It now uses `w.turn_evil`.
    - The clash and in_play_role checks assumed claims could be bluffs, but `Solver.solve`
      takes every selected card as true. Rewritten: Town Hall [Seer, Clerk] + true claims
      of both = no worlds (the claims alone have worlds); picking "seer" rules out a true
      Clerk claim, picking "clerk" keeps it.
    - **Argon, please confirm:** the CaseEval check required `theory_fit < 1.0`; it's 1.0
      because the in_play_role answer also constrains the posterior. Relaxed to `> 0`.
      Tighten it if you meant a case where the answer isn't conditioned on.
- **Suites** (.NET Godot): the CI fast list plus `test_dialogue_batches_5_6_7`,
  `test_backlog_batch4`, `test_workshop_presentation`, `test_buildings_tavern_town_hall`,
  `test_fixes`, `test_board`, `test_town_ui`, `test_ui`, `test_claude_batch`,
  `test_workshop_slice5_voices_and_bot`, `test_mechanics_claims`: all pass. `dotnet build` 0
  warnings; all scripts parse.
- **Golden** vs `baseline_82faa5b`, `--tol 0` (`--ignore engine,sus_why,sus_src`):
  identical in both modes, C#/GDScript parity identical, no script errors.
- **Pushed to `main`.** Next actor: **Argon** (the theory_fit question above; the Seer
  `mate != n` fix from your seed-2004 diagnosis when a baseline change is acceptable).

## 2026-11-03, Argon: Phase 4 Test Fixes + Rebased Chunk 1 Buildings (`patch_008_buildings_and_phase4_fixes.zip`)

- **Base:** `main` at `35b38614a00fec608b0f9e3da7aee4ba3ae596ac` (`35b3861`, post-PR #53 Legacy Purge Phase 4 + Analyst Bot).
- **Deliverable:** `patch_008_buildings_and_phase4_fixes.zip` in Google Drive (`Demonologist Patches`), containing all 40 replacement/new files plus `MANIFEST_BUILDINGS_AND_PHASE4_FIXES.md`. Supersedes `patch_007_buildings_tavern_town_hall.zip` (which was built on pre-Phase-4 `96fb5ea` and has been renamed `SUPERSEDED_patch_007_buildings_tavern_town_hall_96fb5ea.zip` on Drive so there are zero merge conflicts against Phase 4's deleted `sim/argue.gd`, `link`/`conclude`, and rewritten `tools/autoplay.gd`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, the 3 previously red suites `test_dialogue_batches_5_6_7`, `test_backlog_batch4`, `test_workshop_presentation`, plus `test_buildings_tavern_town_hall` + `tools/ci_fast_suites.txt`, `--tol 0` golden check vs `tools/golden/baseline_82faa5b`, and Town Hall sprite placement in `ui/map_view.gd`).
- **Next actor:** **Claude**.

### 1. Fixes for All 5 Test Failures Flagged on `main` (`35b3861`)

1. **`tools/test_dialogue_batches_5_6_7.gd:412-423` ("Accepted hint follow-up voices `hint_why_lead` and `hint_why_confidential` without `[PH]`"):**
   - Uses a clean fixture game (`_game(5702, 10)`), resets `h_speaker.ledger = {}`, records `Mind.hear_claim(..., "seer", ..., "own")`, appends the Night 0 Seer reading, and calls `Mind.update_from_own_info(g_hint.w)` (matching `tools/test_fixes.gd:_setup_private_reading`) so `reason_status` resolves `"private"` through the shared model instead of colliding with the speaker's previously dealt role claim or unapplied `info_log`.
2. **`tools/test_backlog_batch4.gd:206` ("the repeated gift refusal has a different line"):**
   - Checks `first != second` on rendered output alongside `Speech.said(...)` on the emitted `speech` event in `a.last_events` (`"You've had my answer"` or `"puts a target on my back"`), keeping gameplay checks decoupled from character voice pack phrasing per `tools/speech.gd`.
3. **`tools/test_backlog_batch4.gd:682` ("arrival narration adds no phase advance or RNG draws"):**
   - Added `roll_attitude: bool = true` to `Mind.greeting_line` / `MindDialogue.greeting_line` and passed `false` on `"divulge"` `accept` in `game/game_conversation.gd:103` (where the NPC already approached and spoke their divulge lines). Preserves the VN stage greeting speech event while consuming **0 RNG draws** and **0 phase advances**; ordinary `talk` visits still perform the exact single `greeting_attitude_visible` roll.
4. **`tools/test_workshop_presentation.gd:69-70` (`_trapped_group_response`, 2 checks):**
   - In `game/workshop_presentation.gd`, preserved the full `text` (`trapped_voiced` + `" About <name>: <note>"` + optional `hub_voiced_tail`) in both `spoken_line["text"]` and `descriptor["special"]` when `trapped_out` is active, while keeping `trapped_canonical` + tails on `spoken_line["statement"]`. All non-`trapped_out` presentation descriptors (`Speech.said(line) == dialogue.special`) remain untouched.

### 2. Diagnosis of Seed 2004 Shared-Model Warning (`Incomplete or invalid reading payload`)

- Traced `fact:9a9474...` on Seed 2004 (7 NPCs, Day 3): in `sim/evil.gd:685-687`, when one evil member has been executed so the survivor is alone (`Evil.mate(w, n) == null`), `evil.gd` sets `mate = n`. On an even night (`w.day == 2`, read on Day 3), `sim/roles/seer.gd:196-197` (`elif mate.alive and w.chance(...)`) fabricates `pair = [mate.id, w.pick(others_m)]` = `[n.id, other]`, putting the Seer bluffer inside their own `data.pair`, which `workshop/live_assessment.gd:822` (`receipt.source in data.pair`) rightly rejects as impossible for a real Seer. (Also noted a dormant copy-paste in benched `sim/roles/hearthwitch.gd:66,73` `fake_medium_reading` writing `"group"` instead of `"nbrs"`.)
- Left `sim/roles/seer.gd` untouched in this patch so `baseline_82faa5b` stays bit-exact at `--tol 0` for immediate merge; adding `mate != n` on `sim/roles/seer.gd:196` (and `x != n.id` on `asked` at line 184) will eliminate that invalid payload class whenever we next recapture goldens or verify none of the 5 golden seeds hit solo-evil Seer bluff on an even night.

### 3. Rebased Roster & Mechanics Chunk 1 - Tavern Gossip Rework & Town Hall

- Cleanly rebased all 36 code/test files from `patch_007` onto `35b3861` (`Deduction.filing_problem`, `PresentationReply`, `Mind.card_implicates` / `card_clears` / `card_weight_against`, deleted-card check in `game_conversation.gd`, and Analyst-powered `tools/autoplay.gd` + `WorkshopCanvas.view` excluding `tavern_gossip` / `workshop_usable == false` cards so the Analyst juror never ingests unattributed rumours):
  1. **Evening-Only Tavern Gossip (`sim/tuning.gd`, `sim/world.gd`, `sim/social.gd`, `sim/mind.gd`, `sim/mind_dialogue.gd`, `sim/deduction.gd`, `game/game_day_night.gd`, `game/game_board.gd`, `game/game_conversation.gd`, `game/game_presentation.gd`, `game/card_model.gd`, `ui/board_view.gd`, `ui/main.gd`, `ui/case_view.gd`, `ui/workshop_drawer.gd`, `ui/live_case_workshop.gd`, `tools/autoplay.gd`):** Evening-only phase action, resolves evening `_post_pair` once via `World.finish_evening_conversations`, harvests 3-5 two-tier anonymized items from `w.daily_npc_shares` + unlearned haunt/public-bond backfill (never Secret Lovers), marks board cards `source = "rumour"`, `tavern_gossip = true`, `workshop_usable = false`, `pressable = false` with `"rumour|"` `fact_id` isolation and `"dotted"` timeline markers (`?` in CLI `timeline`).
  2. **Town Hall & Lockstep GDScript/C# Solver (`sim/content.gd`, `sim/world.gd`, `game/game.gd`, `game/game_day_night.gd`, `game/card_model.gd`, `game/workshop_canvas.gd`, `ui/map_view.gd`, `ui/main.gd`, `ui/workshop_canvas_view.gd`, `workshop/live_evidence.gd`, `workshop/live_assessment.gd`, `workshop/canvas_model.gd`, `workshop/session.gd`, `workshop/case_graph.gd`, `workshop/solver.gd`, `workshop/case_eval.gd`, `workshop/factored_channels.gd`, `workshop/role_constraints.gd`, `workshop/cs/RoleConstraints.cs`, `tools/test_buildings_tavern_town_hall.gd`, `tools/ci_fast_suites.txt`):** `C.PLAYER_BUILDINGS["town_hall"]` on `the Square` (blank square placeholder in `ui/map_view.gd`, `C.LOCATIONS` untouched), Morning/Afternoon only, 3 uses/case, 6 unique roles (`[in_play, out_of_play]` from `initial_good_roles`), lockstep `.gd`/`.cs` `KindTownHall = 6` solver + `FactoredChannels` role-pool merging + Workshop `in_play_role` chips.

## 2026-11-03 ~23:30 ET, Claude: legacy purge Phase 4 (purge + analyst bot)

- **Branch:** `claude/phase4-purge-bot`, merged with `main` at `96fb5ea` (Argon's dialogue
  batches 5–7 and the trace art). Plan: `docs/legacy_retirement_plan.md` Phase 4.
- **What's gone:** `sim/argue.gd`, the link templates and their matcher, `link` /
  `conclude` / `deduce`, `find_links` / `link_cards`, the template parts of
  `file_deduction` (cases are filed only through the Workshop now), every role
  `card_strength` / `defend_strength` / `reading_strength` hook, `night_sighting_scale`,
  46 legacy tuning keys, `sus_why` / `sus_src`, and the legacy-only tests (`test_argue`,
  template parts of `test_roster`, `test_fixes`, `test_playtest_regressions` and others).
- **What replaced it:**
  - `sim/presentation_reply.gd`: repeat counting and the evil mask with the shadow self,
    moved unchanged. **Argon:** your patch_006 change to `Argue.evaluate`'s shadow-self
    block (same-stance reuse, `render_evil_override` lines) is ported here; `argue.gd` is
    deleted, so edit `presentation_reply.gd` from now on.
  - A good listener the Workshop can't serve answers socially (protect/spare or bare
    belief, from trust and lean), feeding only social preferences. There's no template
    fallback any more.
  - `Mind.card_implicates` / `card_clears` (card structure) decide presentation direction
    and self-support; `Mind.card_weight_against` (the shared model's own reason weight,
    or `Tuning.Dialogue.UNMODELLED_CARD_WEIGHT`) sets press strength.
  - The merge conflict in `Mind.hear_defence` resolves to Argon's voiced lines with the
    structural `card_clears` test.
- **Visible changes:** "has a secret" and "red herring" conclusions can no longer be
  presented (blocked with a reason: the town can't weigh them). Press outcomes move a
  little.
- **Analyst bot** (`tools/analyst.gd`, used by `tools/autoplay.gd`): a neutral juror reads
  the player's board through the shared model (CaseEval) and gives everyone a posterior;
  ranking, nominating, voting and case building use it. Cases are built greedily (each
  card must raise the juror's ratio by 3%, at most 8 cards, presented at ratio 1.45 or
  more, hub at 1.55 or more), conclusion "evil" only. `--insight 0.6` makes it miss 40%
  of cards. `--backend csharp` for sweeps.
- **Checks:** all scripts parse. Before the merge: the CI fast list plus every touched
  suite were green (after two test fixes: legacy template checks removed from
  `test_roster`; the analyst passes the hub picker a signed lean instead of a 0–1
  probability). Golden vs `baseline_82faa5b`: identical in both modes with
  `--ignore engine,sus_why,sus_src`, and C#/GDScript parity identical. After the merge:
  see Result.

### Bot baselines (seeds 2000–2011, C# backend, 2 runs at a time on 2 cores)

| Setup | NPCs | Good wins | Wrongful exec / game | Evil exec / game | Demon identified | s / game |
|---|---|---|---|---|---|---|
| Passive | 7 | 4/12 (33%) | 1.08 | 0.67 | – | 6 |
| Old bot (`9df96cc`) | 7 | 3/12 (25%) | 1.25 | 0.58 | 6 | 16 |
| Analyst, insight 0.6 | 7 | 5/12 (42%) | 1.00 | 0.67 | 5 | 23 |
| Analyst | 7 | 7/12 (58%) | 0.75 | 0.92 | 10 | 53 |
| Passive | 10 | 2/12 (17%) | 2.00 | 1.08 | – | 77 |
| Old bot (`9df96cc`) | 10 | 5/12 (42%) | 1.58 | 1.50 | 9 | 128 |
| Analyst, insight 0.6 | 10 | 3/12 (25%) | 1.50 | 1.58 | 8 | 162 |
| Analyst | 10 | 6/12 (50%) | 1.50 | 1.33 | 8 | 247 |

- 12 seeds is noisy (one game is 8 points). The analyst clearly beats the old bot at 7
  NPCs; at 10 it's only slightly ahead, and its wrongful executions stay high (1.5 a game),
  so the town's votes, not the bot's reading, look like the limit there.
- The old bot did worse than passive at 7 NPCs.
- Juror cost: about 200 evaluations a game at 7 NPCs (41 s) and 240 at 10 (137 s), so most
  of the analyst's time is the juror. A smaller `MAX_CANDIDATES` or caching single-card
  ratios across a day are the obvious speedups if sweeps get too slow.
- **For Argon (shared model):** seed 2004 at 7 NPCs, Day 3: 12 "kept last good vector"
  events, all `Incomplete or invalid reading payload` for one fact
  (`fact:9a9474…`), at `ownership_before` / `preflight_union` / `preflight_assessment`.
  The old bot also triggers this class (45 events across 3 seeds at 10 NPCs), so it
  predates Phase 4, but it's a card the shared model can't read.

### Result

- **`main` is already red.** PR #52 (patch_006, dialogue batches 5–7) was merged with
  three suites failing: `test_dialogue_batches_5_6_7` (8 failures plus script errors),
  `test_backlog_batch4` (2), `test_workshop_presentation` (2). I ran them on `96fb5ea`
  itself and got exactly the same failures as on this branch, so Phase 4 adds none.
- **Fixed on this branch:**
  - `dialogue_presentations._pick_rival_pair`: on a "now" claim a dead starting Demon was
    still picked as the accomplice. The pool now holds the living only.
  - `test_dialogue_batches_5_6_7`: the test hand-built `workshop_case` dictionaries in a
    shape the game never files (a `root` key, board numbers instead of card ids), which
    caused all the script errors. It now files real cases through `WorkshopCanvas.file`.
    The self-support checks passed cards that don't concern the listener (a 0.1 or 0.15
    old strength, under the 0.2 bar, so they'd fail on the old system too); each listener
    now gets their own claim.
- **Still failing (Argon, patch_006; 2-attempt cap reached on the first):**
  1. `test_dialogue_batches_5_6_7` "Accepted hint follow-up…": the test writes a Seer
     reading straight into `speaker.info_log`. The shared model never sees it, so
     `reason_status` is "none" even after `Mind.refresh_beliefs` and the speaker declines.
     The reading needs to go in the way a real one does (or the test needs a mind
     whose reading came from a real night).
  2. `test_backlog_batch4:206` "the repeated gift refusal has a different line" and
     `:682` "arrival narration adds no phase advance or RNG draws". Voiced lines likely
     replaced the expected English text; the second may be a real RNG draw added to
     arrival narration (the golden didn't move, but it doesn't cover arrivals).
  3. `test_workshop_presentation:69–70`: the group-response text no longer starts with
     the expected admission / isn't shown in full.
- Golden: identical to `baseline_82faa5b` in both modes after the merge
  (`--ignore engine,sus_why,sus_src`), C#/GDScript parity identical, no script errors.
- **Not pushed to `main`** (rule: `main` moves only when green). Opened a PR from
  `claude/phase4-purge-bot` instead. It makes `main` strictly better (fixes 3 checks, adds
  no failures), so Michael may merge it as is; otherwise it waits for Argon's fixes
  to the five checks above. **Next actor: Argon** (patch_006 failures), or Michael (merge).
- **Update 22:15 ET:** Michael said to merge as is; merged to `main` as PR #53 (`3ea25b5`).
  **Next actor: Argon** (the five patch_006 checks above).

## 2026-11-03, Argon: Combined Dialogue Batches 5, 6 & 7 delivered (`patch_006_dialogue_batches_5_6_7.zip`)

- **Base:** `main` at `9df96cc7f7f64f567cf99c5fd060cc44bfc4799a` (`9df96cc`).
- **Deliverable:** `patch_006_dialogue_batches_5_6_7.zip` in Google Drive (`Demonologist Patches`), containing full replacement/new files plus `MANIFEST_DIALOGUE_BATCHES_5_6_7.md` (supersedes `patch_006_dialogue_batches_5_6.zip`).
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `test_dialogue_batches_5_6_7` + targeted dialogue/UI/Workshop/role suites + `ci_fast_suites.txt`, and `--tol 0` golden capture check vs `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_006_dialogue_batches_5_6_7.zip`

1. **Full 230-Key Symmetric Cast Voice Pack (`sim/dialogue_voices.gd` - 143 -> 230 keys per character, zero `[PH]` codebase-wide):**
   - **Batch 5 (+31 keys):** Workshop case-presentation reactions, BotC 2-suspect rival framing, movement/trace/role-fit tails, repeats, and self-support replies.
   - **Batch 6 (+8 keys):** `greet_neutral` (x3), `greet_cold` (x2), `greet_warm` (x2), and 5 contextual overrides (`greet_friend_killed`, `greet_after_murder`, `greet_after_execution`, `greet_after_friction`, `greet_after_protection`).
   - **Batch 7 (+46 new keys + 2 completed cast hooks):** Populates the remaining 14 characters on `private_reveal_early` and `doubted_visual` (so all 15 characters share an identical 230-key schema) and adds bespoke character voices for all 25 remaining `[PH]` sites across conversations, `press` edge cases, 1st/2nd-press night-walking duty reconfirmations (`warden`, `nightwatch`, `lamplighter`, `medium`), all 5 `HINT_PACKAGES`, fear-withheld readings, protection-promise trust, `_repeat_refusal` pushbacks, role queries (`answer_about_role` / `answer_is_role`), Seer Red Herring defence, Warden door/save reports, and town-meeting anonymous relays and block pleas.
   - Zero `[PH]` tags remain anywhere across `sim/`, `game/`, `workshop/`, or `ui/`; `"data"` remains exclusive to Nisha; `greet_neutral` avoids burning `Dialogue.TICS` caps; zero `"when it's safer"` or `"stand by it"` boilerplate on Batch 7 lines.
2. **Batch 5 - Voiced Case-Presentation Composer & Good/Evil Parity (`sim/dialogue_presentations.gd`, `game/workshop_presentation.gd`, `sim/argue.gd`, `sim/mind.gd`, `sim/evil.gd`):**
   - Keeps `workshop/` (`jury.gd`, `reasoner.gd`, C# solver kernels) and `WorkshopPresentation._belief_stance_text` 100% untouched; canonical diagnostic strings remain on `spoken_line["statement"]` and `descriptor["special"]`.
   - Uses BotC-style top-Demon + `#2` highest-suspicion `{accomplice}` rival framing (never naming a 3rd evil, promoting a living evil successor if the starting Demon died on `"now"` claims, and appending `present_alt_marked` only when Marked explains an attended ping/conclusion) and unifies Good and Evil presentation phrasing.
   - **Merge note for Claude's Purge Phase 4 (`sim/argue.gd` retirement):** All presentation and Evil-override voicing lives in `sim/dialogue_presentations.gd` (with zero dependency on `sim/argue.gd`). When Phase 4 deletes `sim/argue.gd`, retain `Presentations.render_evil_override(...)` in the unified presentation path and reuse `sr.dialogue.voiced_text` when Evil adopts its shadow's assessment.
3. **Batch 6 - VN Conversation Intro & Greeting System (`sim/mind_dialogue.gd`, `sim/mind.gd`, `game/game_conversation.gd`, `game/game_day_night.gd`, `game/game.gd`, `ui/day_conversation_view.gd`):**
   - `Mind.greeting_line(w, n, context)` consumes the exact same single `greeting_attitude_visible` Composure RNG draw as `Mind.greeting_cue`, emits spoken `speech` events with 5-state VN portrait expressions (`neutral`, `warm`, `harsh`, `concerned`, `sorrowful`) on `talk` entry and `divulge` `accept`, removes `"Choose a question to begin."`, and preserves zero-cost `bye`.
4. **Batch 7 - Final `[PH]` Sweep (`sim/mind_dialogue.gd`, `sim/social.gd`, `sim/mind_meeting.gd`, `sim/role_def.gd`, `sim/roles/seer.gd`, `sim/roles/warden.gd`, `sim/roles/nightwatch.gd`, `sim/roles/lamplighter.gd`, `sim/roles/medium.gd`, `game/game_conversation.gd`):**
   - Preserves `C.role_def(f_role).pressed_night_line(...)` as the canonical `statement` (keeping `test_role_def_poc` green) while adding `pressed_night_slots(...)` to feed `pressed_<role>_night` / `pressed_<role>_night_alt`.
   - Normalizes relayed `known_claims` readings in `Social.answer_about_role` via `C.third_person(e["text"])` while retaining canonical `statement` on all voiced lines.
5. **New Unified Suite:** `tools/test_dialogue_batches_5_6_7.gd` (`uid://c5w7mp3qn8kvr`).

---

## 2026-11-03 ~18:30 ET, Claude: `game.gd` separation checked, green, no fixes, on main

- **Base:** `b061bb3` as declared; unpacked on `refactor/game-gd-separation`, no changes
  needed. `game.gd` 2,886 to 1,020 lines; four new helpers (conversation, meeting,
  day/night, screens). This is also meeting-plan slice **M0**.
- **Static checks:** every function, `var` and `const` that was on `Game` still is. All
  91 moved function bodies are identical to the originals once `self.`/implicit member
  access is rewritten as `g.` (mechanical comparison), and all 91 forwarders call the
  same-named helper with `self` plus the same arguments (3 that never touched instance
  state correctly omit `self`). `dotnet build` 0 errors; all 268 scripts parse.
- **Suites** (.NET Godot, targeted per Michael): `test_npc_interactions`,
  `test_dialogue_decisions`, `test_social`, `test_playtest_followups`,
  `test_mechanics_defences`, `test_outcomes`, `test_backlog_batch3`,
  `test_mechanics_sightings`, `test_mechanics_curse`, `test_town_ui`, `test_text_ui`,
  `test_ui`, `test_fixes`, `test_role_def_poc`, `test_workshop_slice5_voices_and_bot`:
  15/15 pass.
- **Golden** `--mode gdscript` vs `baseline_82faa5b`, `--tol 0`: identical on all five
  seeds, 0 script errors. Not re-run in csharp mode (no `workshop/` changes; CI's parity
  job covers it on the push).
- **Active play, which the golden doesn't exercise:** 3 active bot games (seeds
  1000-1002, 7 NPCs) at `b061bb3` and at this branch. Transcripts identical line for line
  and dev logs byte-identical.
- **Pushed to `main`.** Next actor: Claude (bot rewrite + final legacy purge, Phase 4).

---

## 2026-11-03, Argon: `game/game.gd` 4-slice separation delivered (`patch_005_game_separation.zip`)

- **Base:** `main` at `b061bb3f7e3054b4f922cdb08189070dd322fe3e` (`b061bb3`).
- **Deliverable:** `patch_005_game_separation.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_GAME_SEPARATION.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, domain suites + `ci_fast_suites.txt`,
  and 5-seed `--tol 0` golden capture in both `gdscript` and `csharp` modes vs
  `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_005_game_separation.zip`

1. **All 4 `game/game.gd` static domain helper extractions (100% simulation-neutral):**
   - `game/game_conversation.gd` (856 LOC, `uid://c4m8kq2vx7pbn`): `# --- approaches` and
     `# --- conversation` (`_maybe_approach`, `_promised_to`, `_maybe_divulge`, `_approach_command`,
     `_protect_approach_answer`, `_grant_protection`, `_phase_header`, `_remember_dialogue_exchange`,
     `_talk_options`, `_repeat_refusal`, `_talk_command`, `_record_trace_profile_haunts`,
     `_answer_request`, `_answer_request_now`, `_gift_request`, `_grievance_menu`, `grievance_text`,
     `_offer_command`, `offer_text`, `_settle_offers`, `OBSERVABLE_TRAITS`, `TRAIT_WORDS`,
     `MAX_BONDS_TOLD`, `_maybe_tell_haunts`, `_record_trait_receipt`, `sync_bereaved_traits`,
     `_maybe_tell_trait`, `_maybe_tell_relationships`, `_remember_spoken_relationship`,
     `known_relationship_notes`, `known_haunt_names`, `_close_conversation`).
   - `game/game_meeting.gd` (321 LOC, `uid://c7n3rw5tb2kdm`, **Meeting Overhaul Slice M0**):
     `# --- meeting` (`_start_meeting`, `meeting_streaming`, `testimony_step`, `_testimony_turn`,
     `_meeting_opened`, `_meeting_command`, `_next_npc_nomination`, `_defend_pending`,
     `vote_requirement_text`, `_show_nomination`, `_nomination_command` coroutine with `await`,
     `_after_vote`, `_last_words`, `_close_meeting` passing bound `g._last_words` to
     `g.w.end_meeting`).
   - `game/game_day_night.gd` (495 LOC, `uid://b8p6vy3qf4hlk`): `# --- day` and `# --- night`
     (`unseen_at`, `unseen_at_ui`, `can_see`, `can_see_ui`, `_present`, `_resolve_go`,
     `_best_location_on`, `_day_command`, `_warn_busy_visit`, `_who_here`, `_observe`, `_search`,
     `_end_phase`, `_night_homes`, `_night_command`, `_resolve_night`, `_fallbacks_text`,
     `_morning_report`).
   - `game/game_screens.gd` (614 LOC, `uid://c2t5wx8jm3rqp`): `# --- info screens` and
     player theory/prediction/debug/profile helpers (`_intro`, `_help`, `_look`, `_card_workers`,
     `_card_conversations`, `_map`, `_cast`, `_profile`, `_script`, `_tools`, `_board`, `_ending`,
     `_grimoire`, `_exchanges`, `_lies`, `_write_logs`, `set_note`, `set_guess`,
     `set_secret_guess`, `capture_prediction`, `theory_status`, `_outcome_text`,
     `set_debug_overlay`, `_spread`, `debug_card_text`, `debug_npc_text`, `named_in`,
     `_death_text`, `_claim_text`, `profile_data`).
2. **Refactored `game/game.gd` (2,886 LOC -> 1,020 LOC):**
   - Retains all 72 session variables, all 25 existing constants/preloads (preserving `g.Argue`,
     `g.Mind`, `Game.OBSERVABLE_TRAITS`, `g.OBSERVABLE_TRAITS`, and static `Game.grievance_text`),
     adds `GameConversation`, `GameMeeting`, `GameDayNight`, and `GameScreens` preloads, and
     delegates all extracted functions via 1-line forwarders (including
     `await GameMeeting._nomination_command(self, verb, rest, progress)`).

---

## 2026-11-03 ~17:00 ET, Claude: slice C3 checked, green after 2 small fixes, on main

- **Base:** `4077dce` as declared; unpacked on `csharp/slice-c3`, main merged in (meeting
  plan + CI parity change, `9c4affd`), no conflicts.
- **Build:** `dotnet build -c Debug`: 0 warnings, 0 errors. All 264 scripts parse. The C2
  gotchas held: no `Packed*Array` consts, C2's `.get("source")` fixes kept, `GdFloor1e30` shared.
- **Fixes needed (2), both in the C3 test's fixture paths, not the live game:**
  1. **`Solver._movement_cs` night keys.** The GDScript twin keys `nights` by `str(night)`;
     the C# wrapper used `str(int(night))`. The checkpoint v5 fixtures are JSON, so their
     nights are floats and the keys came out `"1.0"` vs `"1"` (counts and forced-out
     lists were identical). In-game nights are ints, so the golden never saw it. The
     wrapper now keeps the cards' own key. **General rule for C4+:** where a GDScript
     result is keyed or formatted from a value, format the original value, not a converted one.
  2. **Warden report without `block`.** `live_activity._paths` read `card.block` on Warden
     self-reports; the fixture's `r_ward` has none, so GDScript crashed while C# treated it
     as "no match" (`wBlk >= 0` fails). Now `card.get("block", "")`, same result as C#.
- **Suites** (.NET Godot, Linux): all 24 from the manifest plus `ci_fast_suites.txt` pass,
  including `test_csharp_slice_c0`..`c3`, `test_case_eval`, `test_channel_sum_product`,
  `test_workshop_factored_channels`/`_classes`, `test_prior_mapping`.
- **Golden, `--tol 0`, 0 script errors:** `--mode gdscript` and `--mode csharp` both identical to
  `baseline_82faa5b` on all five seeds, and csharp identical to gdscript (the new CI parity
  check); csharp re-run after fix 1, still identical. Side by side: GDScript 823 s, C# 242 s
  (**3.4x**; C2 was 1.8x).
- **VERIFY:** profile_c0 seed 42, 21,750 boundary calls, 0 mismatches.

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms | C2 CSHARP ms |
|---|---:|---:|---:|
| outer_prep | 990 | 1001 | 1477 |
| pack_inputs | 0 | 396 | 725 |
| world_domain | 6684 | 923 | 703 |
| live_activity | 3138 | 358 | 391 |
| case_eval_compile | 344 | 103 | 570 |
| channel_sum_product | 264 | 161 | 256 |
| reason_attribution | 251 | 253 | 243 |
| **total self** | **11672** | **3195** | **4365** |
| **wall** | **12109** | **3662** | **4937** |

`world_domain` now includes the `Solver.*` work you re-attributed, so its C# rise from 703
to 923 ms is a relabel, not a regression (GDScript's rose the same way, 5825 to 6684).

### Notes for Argon

1. **C# is 3.3x faster end to end on seed 42** (wall 12.1 s to 3.7 s).
2. **C4 (`reason_attribution`):** 253 ms self in C# over 26 calls (9.7 ms each), above the
   150 ms threshold you set, and unchanged since C1. Its inclusive time is 653 ms. By that
   test C4 is worth doing, but the bigger targets are `outer_prep` (1.0 s, 31% of C# self,
   still pure GDScript) and `pack_inputs` (396 ms over 15,792 calls). `LiveActivity.routes`
   is still the top packer (126 ms, 613 calls at 206 us) despite the env memo, so card
   packing is now the cost there; `fits_weights` is next (113 ms, 754 calls).
3. **CI change you should know about (`9c4affd`):** a new required `parity` job diffs the
   csharp capture against the gdscript capture of the same commit. The diff against
   `baseline_82faa5b` is now a warning, because meeting-overhaul slices will change behaviour
   on purpose and re-record the baseline. For your slices nothing changes in practice:
   both must still be identical. See `docs/golden_baseline.md`.
4. **Kernel changes are now two-sided:** until the GDScript solver is retired, any change
   to a ported file (including new roles touching possible worlds, bluffs or movement)
   needs both implementations. Worth planning when the GDScript copies can be deleted.

### Result

- **Pushed to `main`.** Next actor: **Argon** (C4 or the `outer_prep`/packing work; your call).

---

## 2026-11-03, Argon: slice C3 + C2 profile follow-ups delivered (`patch_004_slice_c3.zip`)

- **Base:** `main` at `4077dcedb0aef0a4a8a2463a739214a8aa389eba` (`4077dce`).
- **Deliverable:** `patch_004_slice_c3.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C3.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `ci_fast_suites.txt`
  including `test_csharp_slice_c3`, `test_case_eval`, `test_channel_sum_product`,
  `test_workshop_factored_channels`, `test_workshop_factored_classes`, `test_prior_mapping`,
  Seed 42 Day 4 `tools/profile_c0.gd` run, and `--tol 0` golden capture vs
  `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_004_slice_c3.zip`

1. **Slice C3 C# kernels (`workshop/cs/`):**
   - `workshop/cs/SolverKernel.cs` (+ `.uid`, `uid://do19o1k4et4jx`) & `workshop/solver.gd`:
     1:1 bit-exact C# port of `world_bits`, `sig_groups` (cached per universe handle on
     `SolverContext`), `valid_table`, `report_table` (all `CONTENT_ROLES`, `positive` /
     `blocks` / `marked` answers, `testimony_only` shapes `ROLE_IN_GROUP` / `PING` /
     `SECRET_PAIR`, and `curse` events across live and fixture universes), `_solve`
     candidate & position filtering, fixture `_movement` bitmask enumeration,
     `question_table` (`misled` & `unreliable`), and `premise_mask`.
   - `workshop/cs/CaseEvalKernel.cs` (+ `.uid`, `uid://dnwp18om6galx`) & `workshop/case_eval.gd`:
     1:1 bit-exact (`--tol 0`) C# port of `_index`, `compile` (ternary card-state codes,
     64-bit `long` vs tuple class keys, `group` / `group_bits`, `test_hold`, and fused C#
     class movement scoring directly via registered `LiveActivity` factor handles),
     `_own_counts` (preserving `tools/test_case_eval.gd`'s synthetic `_own_cache` override),
     `_team_prior` (passing dynamic `CaseEval.prior_k`, preserving `prior_k = -1.0` probe
     mode), `_class_like`, and the full `evaluate` posterior marginalization pass (`own_like`
     in reverse `ko-1..0` order, `test_like`, `theory_bias`, `_class_share`, `_people`,
     `_joint`, `_pivotal`, and `_expand`).
   - `workshop/cs/ChannelSumProduct.cs` (+ `.uid`, `uid://dwr8kf4qmbl8z`),
     `workshop/channel_sum_product.gd`, & `workshop/factored_channels.gd`:
     1:1 bit-exact (`--tol 0`) C# port of `ChannelSumProduct.compile` (preserving insertion-
     order variable tie-breaking), `evaluate` (forward + zero-safe reverse adjoints),
     `circuit` (constant-folded register DAG registered in `SolverContext`), `run`, and
     batched `FactoredChannels.assess` (`FactoredAssessBatch`, pre-populating missing coarse
     signatures once and running all worlds/representatives + signature memoization +
     marginals in a single C# call).
   - `workshop/cs/SolverContext.cs`, `workshop/cs/SolverBridge.cs`, & `workshop/caches.gd`:
     Added `UniverseMeta` per-handle caches plus `CompiledCaseEntry`, `CompiledProgram`, and
     `CompiledCircuit` arenas, all cleared atomically in `WorkshopCaches.clear_all()`.
2. **Follow-ups on Claude's C2 profile notes (`pack_inputs` 725 ms & `outer_prep` 1,477 ms):**
   - **Handle propagation on subset & solver role checks:** Fixed
     `RoleConstraints._fits_weights_dispatch` so non-empty `sub_indices` (`personal` open
     subsets in `CaseEval._class_fits` and `ReasonAttribution._subset_fits`) map
     `miss_sub.append(sub_indices[i])` against `u_handle` instead of repacking `miss_worlds`;
     passed `u_handle` (+ surviving `PackedInt32Array` indices) in `Solver._solve`,
     `Solver.question_table`, and `ReadingChallenges._fraction`.
   - **`LiveActivity._pack_view_env` memoization:** Cached `_pack_view_env` on `LiveActivity`
     (cleared in `WorkshopCaches.clear_all()`) so the 613 `routes` calls per Seed 42 game
     reuse the packed homes/deaths/timeline arrays instead of rebuilding them per call.
   - **`outer_prep` reductions:** Added O(1) indexed `Solver.card_by_id` lookup (safe under
     in-place `view.cards.append(...)` and mutations), attributed `Solver.*` work to
     `world_domain`, and made `Jury`'s recursive `JSON.stringify(_canonical(...))`
     `common_key` lazy so it only runs when `confidence_mode == "persistence"` (or legacy
     engine), skipping unused stringification on live refreshes.
   - **C2 gotchas enforced:** Zero `Packed*Array()` in GDScript `const`, safe `.get(...)` on
     card fields, shared `SolverContext.GdFloor1e30` (`0x39B4484BFEEBC29FL`), and a float
     literal `var_to_bytes()` + `VerifyFloat64Buffer` audit at the start of
     `tools/test_csharp_slice_c3.gd` (`uid://dsjyh3rxwvsyc`, registered in
     `tools/ci_fast_suites.txt`).

---

## 2026-11-03 ~15:00 ET, Claude: slice C2 checked, green after fixes, on main

- **Base:** `0498fce` as declared; unpacked on `csharp/slice-c2`, main merged in (CI
  test_trace park), no conflicts.
- **Build:** `dotnet build -c Debug`: 0 errors.
- **Fixes needed (4):**
  1. **Parse errors in 8 scripts.** `const _EMPTY_INT32 := PackedInt32Array()` and
     `_EMPTY_INT64` in `role_constraints.gd` and `live_activity.gd` are not constant
     expressions in Godot 4.7, so both scripts (and everything preloading them) failed to
     compile. Replaced with inline `PackedInt32Array()` / `PackedInt64Array()`.
  2. **Crash on cards without `source`.** `role_of`, `role_hearing` and the two
     `hearing_weight` lambdas in `live_activity.gd` read `card.source` directly; `context`
     cards have none. Now `card.get("source", "")`. No behaviour change for cards that
     have a source (the golden never hit the crash), but the C2 test's fixtures did.
  3. **1-ULP VERIFY mismatches in `LiveActivity.scores`** (values around 1e-29, seen in
     test_csharp_slice_c1/c2 and profile_c0). Cause: **Godot parses the literal `1e-30`
     one ULP low** (`0x39B4484BFEEBC29F`; IEEE nearest, which C# uses, is `...C2A0`). The
     floor in `_base_score` therefore differed. `LiveActivity.cs` now uses Godot's bits
     (`GdFloor1e30`). I checked the other exponent literals in the C# ports: `1e-12`,
     `1e-20` (and `1e-9`, `1e-6`) parse identically in both. **For C3:** check every
     float literal you port against GDScript's bits, not the decimal text.
  4. **test_csharp_slice_c2 fixtures:** it read `Ownership.reasons_for(...)`'s return
     value (it returns nothing; it fills `workshop_state.reasons`) and its passive player
     used `g.actions_left`, which doesn't exist. It now reads the state and uses
     `golden_capture.gd`'s passive player.
- **Suites** (.NET Godot, Linux): `test_csharp_slice_c0`, `c1`, `c2`,
  `test_workshop_live_activity`, `test_lamplighter_drops`, `test_workshop_profile_traces`,
  `test_mechanics_sightings`, `test_workshop_integration`, `test_workshop_reading_challenges`,
  plus (before fix 3) mechanics_warden/curse, workshop_ownership/efficiency, headline,
  claude_audit_cleanup: all pass. VERIFY 0 mismatches on the passive seeds 42 and 54875
  (2.1M boundary checks on 54875).
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in both
  `--mode gdscript` and `--mode csharp`, 0 script errors (re-run after the fixes).
  Before the fixes, side by side: GDScript 776 s, C# 433 s (about 1.8x).

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms | C1 CSHARP ms |
|---|---:|---:|---:|
| outer_prep | 1434 | 1477 | 1654 |
| pack_inputs | 0 | 725 | 1932 |
| world_domain | 5825 | 703 | 892 |
| live_activity | 3309 | 391 | 3329 |
| case_eval_compile | 560 | 570 | 1168 |
| channel_sum_product | 279 | 256 | (0 calls) |
| reason_attribution | 280 | 243 | 309 |
| **total self** | **11687** | **4365** | |
| **wall** | **12248** | **4937** | **9918** |

`case_eval_compile` halved because `CaseEval.evaluate` now records under
`channel_sum_product` (note 3), not because it got faster.

### Notes for Argon

1. **C# is now 2.5x faster end to end on seed 42** (wall 12.2 s to 4.9 s). `live_activity`
   dropped 8.5x and `pack_inputs` 2.7x.
2. **`pack_inputs` is still 725 ms over 19,036 calls (38 us each).** The heaviest packers
   by boundary table: `fits_weights` (232 ms, 754 calls), `coarse_masks` (196 ms, 819),
   `LiveActivity.routes` (130 ms, 613 calls at 212 us). Routes repack the view env and cards
   per call; a per-refresh handle like the universe arena would remove most of it.
3. **`outer_prep` (1.5 s) is now the largest stage in C# mode**, about a third of self time,
   and unchanged by C1/C2. Worth a look alongside C3's `solver.gd` + `case_eval.gd` move.
4. **Literal bits** (fix 3 above): the cheapest guard is a C0-style audit that prints
   `var_to_bytes()` for each constant a slice ports and compares it with the C# value.

### Result

- **Pushed to `main`.** Next actor: **Argon** (slice C3).

---

## 2026-11-03, Argon: slice C2 + C1 packing handles delivered (`patch_003_slice_c2.zip`)

- **Base:** `main` at `0498fce6c5def9f70f15c0015ac8e8e1cb403ab2` (`0498fce`).
- **Deliverable:** `patch_003_slice_c2.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C2.md`.
- **Status:** Ready for Claude verification (`dotnet build -c Debug`, `ci_fast_suites.txt`
  including `test_csharp_slice_c2`, Seed 42 Day 4 `tools/profile_c0.gd` run, and `--tol 0`
  golden capture vs `tools/golden/baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_003_slice_c2.zip`

1. **Follow-ups on all 5 notes from Claude's C1 report:**
   - **Note 1 (`pack_inputs` 1,932 ms bottleneck):** Added a handle-based packed universe
     arena in `SolverContext.cs` (`RegisterPackedUniverse`, `RegisterIndexedSubUniverse`,
     `ResolveWorlds`) and `SolverBackend` (`get_universe_handle`, `get_sub_universe_handle`),
     cleared atomically in `WorkshopCaches.clear_all()`. Wired `u_handle` / `cc_reps_handle`
     and `sub_idx` / `failed_cc_idx` through `CaseEval._coarse`, `CaseEval._fits_over`, and
     `RoleConstraints` (`coarse_masks`, `fits_weights`, `fits_table`, `bluff_weights`), so
     the 5,040- / 15,120-world universe and each equivalence-class `cc.rep` table pack once
     per key instead of repacking ~2,000 times per Seed 42 game.
   - **Note 2 (`VERIFY` skipping `coarse_masks`):** `RoleConstraints.fits_weights` in
     `VERIFY` mode previously delegated to `_fits_weights_gd`, whose coarse-mask cache hit
     skipped calling `RoleCoarseMasks`. `VERIFY` now explicitly invokes
     `RoleCoarseMasksByHandle` + `VerifyInt64Buffer("RoleConstraints.coarse_masks", ...)` on
     every `fits_weights` call alongside `VerifyFloat64Buffer("RoleConstraints.fits_weights")`.
   - **Note 3 (`channel_sum_product` showing 0 calls):** Live `CaseEval` evaluates posterior
     marginals over compiled equivalence classes in `CaseEval.evaluate`, whereas the
     treewidth sum-product circuit (`FactoredChannels` / `ChannelSumProduct`) only runs in
     circuit/probe suites. `CaseEval.evaluate` now records under `channel_sum_product` while
     `CaseEval.compile` stays under `case_eval_compile`, cleanly separating class compilation
     from per-listener posterior evaluation ahead of Slice C3.
   - **Note 4 (`live_activity` 2,904 ms):** Ported in full below as Slice C2.
   - **Note 5 (`profile_c0.gd` `refreshes=0`):** Promoted `_refreshes` from a value-captured
     local `int` inside the lambda to a `SceneTree` member variable (matching
     `golden_capture.gd`).
2. **Slice C2 (`LiveActivity.cs` + batched `LiveActivity.scores`):**
   - `workshop/cs/LiveActivity.cs` (+ `.uid`, `uid://dwxl3uolgi3pa`) & `workshop/live_activity.gd`:
     1:1 bit-exact C# port of `routes` / `_paths` (4-block pairwise bitmask `PathSpec`,
     Medium `relay_source` hearth checks, complete vigils, `guard_claim`, `coverage`,
     Night Watch / Warden / Medium / Lamplighter strict reports, Lamplighter walker counts +
     `positive` answers, and `dropped` / `item_drop` Hall matching), single & all-person
     batched `_likelihood` (`LiveAllProfiles`), single & scene-batched
     `crossing_probability` (`LiveSceneCrossings`), pre-registered compiled movement factor
     handles (`LiveRegisterMovementFactor`, cleared atomically in `WorkshopCaches.clear_all()`),
     and single + handle-batched world scoring (`LiveScoreWorld`, `LiveScoreWorldsByHandle`)
     covering Revenant `converted` profiles, 1-trace & 2-trace passer contractions, and Scion
     succession splits.
   - Wired `CaseEval._movement_scores` (`workshop/case_eval.gd`) to score all equivalence-class
     representatives `rep` in a single `LiveScoreWorldsByHandle(u_handle, rep, ...)` call per
     `CaseEval.compile` (1 boundary crossing and 0 `pack_world` loops instead of ~1,000).
   - Added `tools/test_csharp_slice_c2.gd` (+ `.uid`, `uid://dbbsd0qc7quhn`) and registered
     `test_csharp_slice_c2` in `tools/ci_fast_suites.txt`.

### Notes for Claude's check pass

- Pure .NET 8 BCL + `GodotSharp` only (zero external NuGet dependencies).
- Please post the updated `tools/profile_c0.gd` Seed 42 Day 4 table so we can see how much of
  both `pack_inputs` (`1,932 ms`) and `live_activity` (`2,904 ms` / `3,329 ms`) dropped before
  Slice C3 moves `solver.gd` + `case_eval.gd` compilation & marginalization into C#.

---

## 2026-11-03 ~13:30 ET, Claude: slice C0b + C1 checked, green, on main

- **Base:** `1821db3` as declared; unpacked on `csharp/slice-c1`, no conflicts, no
  changes needed to Argon's code.
- **Build:** `dotnet build -c Debug`: 0 warnings, 0 errors. All 262 scripts parse on the
  .NET binary.
- **Suites** (.NET Godot, Linux): all 13 from the manifest checklist pass, plus
  `test_workshop_ownership` and `test_headline`.
- **Golden vs `baseline_82faa5b`, `--tol 0`:** identical on all five seeds in **both**
  `--mode gdscript` (default) and `--mode csharp`; 0 script errors. Captures ran side by
  side under equal load: GDScript 750 s total, C# 568 s (about 24% faster end to end).
- **VERIFY:** `profile_c0` reports 18,207 boundary calls, 0 mismatches.

### Profile, seed 42 (7 NPCs, to Day 4), self time

| Stage | GDSCRIPT ms | CSHARP ms |
|---|---:|---:|
| outer_prep | 1406 | 1654 |
| pack_inputs | 0 | 1932 |
| world_domain | 5701 | 892 |
| live_activity | 2904 | 3329 |
| case_eval_compile | 1094 | 1168 |
| reason_attribution | 267 | 309 |
| **wall** | **11923** | **9918** |

(Profiled while a suite run used the other core, so absolute numbers are noisy; the
ratios are the useful part.)

### Notes for Argon

1. **Packing is now the bottleneck of what C1 moved.** `world_domain` dropped 6.4x
   (5.7 s to 0.9 s), but repacking inputs per call costs 1.9 s, about 1 ms per call for
   `coarse_masks` (819 calls), `bluff_weights` (314), `bluff_weights_temporal` (132) and
   `fits_weights` (754). The universe and role tables are the same across most of those
   calls within one refresh, so packing them once per refresh (or per universe key) and
   passing a handle should recover most of the 1.9 s. Same rule as before: key the cache
   on everything that varies, and clear it in `clear_context`.
2. **VERIFY barely exercises `coarse_masks`:** 4 calls in VERIFY against 819 in CSHARP.
   VERIFY seems to take a path where cached masks skip the comparison. Worth checking that
   VERIFY compares on every call, or it can miss a mismatch that CSHARP mode would ship.
3. **`channel_sum_product` shows 0 calls** in both modes on seed 42, so either that path
   doesn't run in this game or the timers are on functions that aren't the hot entry
   points. Confirm before C3 targets it.
4. **`live_activity` (2.9 s) is now the largest pure-GDScript stage after outer prep**,
   which supports C2 as the next slice, per the plan.
5. **The profile header says `refreshes=0`:** the refresh counter in `profile_c0.gd` isn't
   wired (the golden capture counts 67 for this seed). Cosmetic.

### CI (new, Michael's go-ahead)

`.github/workflows/ci.yml` now runs on every pull request and on main:

- builds the C# project on the Godot .NET binary;
- runs suites (`tools/ci_fast_suites.txt` on PRs, everything on main, 4 shards);
- diffs golden captures (gdscript and csharp modes) against `baseline_82faa5b` at
  `--tol 0`, failing on any `SCRIPT ERROR`.

A Windows golden job runs on main and manual runs and is informational until it first
agrees with Linux. Add new C# slice suites to `tools/ci_fast_suites.txt`.

Next actor: **Argon** (C2 `live_activity`, after the packing cache in note 1 if it's quick).

---

## 2026-11-03 11:55 ET, Argon: slice C0b + C1 delivered (`patch_002_slice_c1.zip`)

- **Base:** `main` at `1821db368bf22ec5d3436b8aa5407a54c6b3db86` (`1821db3`).
- **Deliverable:** `patch_002_slice_c1.zip` in Google Drive (`Demonologist Patches`), with
  full replacement/new files plus `MANIFEST_SLICE_C1.md`.
- **Status:** Ready for Claude verification (`dotnet build`, suites, Seed 42 profile run,
  and `--tol 0` golden capture vs `baseline_82faa5b`).
- **Next actor:** **Claude**.

### What's in `patch_002_slice_c1.zip`

1. **C0b hierarchical stage profiler & `tools/profile_c0.gd`:**
   - `workshop/solver_backend.gd` now maintains a re-entrant stage stack (`begin_stage` /
     `end_stage`) tracking both exclusive (`Self (ms)`) and inclusive (`Incl (ms)`) time
     with zero nested double-counting, plus per-boundary-function call counts and packing
     microseconds (`record_boundary_call` -> `pack_inputs`). Completely inert when
     `SolverBackend.profiling_enabled == false`.
   - Wired across `shared_ledger.gd`, `jury.gd`, `circumstantial.gd` (`outer_prep`),
     `world_domain.gd` & `role_constraints.gd` (`world_domain` + `pack_inputs`),
     `live_activity.gd` (`live_activity`), `case_eval.gd` (`case_eval_compile`),
     `channel_sum_product.gd` & `factored_channels.gd` (`channel_sum_product`), and
     `reason_attribution.gd` (`reason_attribution`).
   - Added `tools/profile_c0.gd` (+ `.uid`): plays Seed 42 (7 NPCs) to Day 4 across
     `GDSCRIPT`, `CSHARP`, and `VERIFY` modes, exercising lazy meeting `reasons_for`,
     asserting bit-exact state parity and 0 `VERIFY` mismatches, and printing
     `SolverBackend.format_profile_report`.
2. **C0b full kernel math call-site audit:**
   - Audited every `exp`, `log`, `pow`, `snappedf`, and `lerpf` call site in `workshop/`
     and recorded the full table in `docs/csharp_solver_migration.md` (Section 4).
   - Added `SolverBridge.GodotLerpf` (`from + (to - from) * weight` in `double`) +
     `EvalLerpfBatch`, and expanded `tools/test_csharp_slice_c0.gd` from 164 samples to
     the full kernel argument grid (`prior_k * suspicion`, `pow(2.0, log2_ratio)`,
     `pow(3.0, k)`, `log(x)`, `snappedf(..., 1e-9)`, and all `lerpf` endpoints) at 0 ULP.
3. **Slice C1 (`WorldDomain` + `RoleConstraints` + `SolverContext`):**
   - `workshop/cs/SolverContext.cs` (+ `.uid`): 8-byte `WorldEntry` struct (`Pack = 1`,
     58-bit layout inside `long Raw` covering up to 18 people, lossless distinction
     between absent vs `-1` `demon`/`converted`/`modifier` fields) and `SolverContext`
     universe cache cleared atomically by `SolverBridge.ClearContext()`.
   - `workshop/cs/WorldDomain.cs` (+ `.uid`) & `workshop/world_domain.gd`: 1:1 C# port of
     `worlds`, 64-bit `key`, `claims_compatible`, `healthy`, `gift_time`, and `rumor`,
     wired for `GDSCRIPT | CSHARP | VERIFY`.
   - `workshop/cs/RoleConstraints.cs` (+ `.uid`) & `workshop/role_constraints.gd`: 1:1 C#
     port of 64-bit `coarse_mask` + batched `coarse_masks` (wired into `CaseEval._coarse`
     so compilation crosses the boundary once per universe instead of 5,040 times),
     `fits` / `fit_weight` / `fits_table` / `fits_weights` (supporting both `reuse = true`
     and `reuse = false`, hoisted `Activity.routes` / Veteran `demon_routes` masks,
     Medium relays, Sleepwalker claims, Martyr, Sexton, Revenant curse/totem, all
     `ROLE_IN_GROUP` RoleDefs, and Seer Red Herring marginalization), and simple +
     temporal/curse `bluff_weights`.
   - Added `tools/test_csharp_slice_c1.gd` (+ `.uid`): tests 8-byte `WorldEntry`, cache
     reset, 7- & 10-NPC `WorldDomain`, 64-bit `coarse_masks`, every role constraint family,
     all 4 `Session` fixtures, and multi-day passive games on Seed 900 (7 NPCs) and Seed
     54875 (10 NPCs) across `GDSCRIPT`, `CSHARP`, and `VERIFY` at `--tol 0`.

### Notes for Claude's check pass

- Zero external NuGet packages used (pure .NET 8 BCL + `GodotSharp`).
- Keep `Demonologist.csproj` and `tools/run_gd_tests.py` (`Debug` build) as you adjusted
  in C0; neither file is touched by this slice.
- `tools/golden_capture.gd` now accepts `--mode csharp` (and `--mode verify`), while
  defaulting to `GDSCRIPT` when `--mode` is omitted. So you can capture C# golden output
  directly via `golden_capture.gd -- --out /tmp/golden_c1 --mode csharp` and diff against
  `tools/golden/baseline_82faa5b` at `--tol 0`. Please also post the `tools/profile_c0.gd`
  output table here so we have the Seed 42 Day 4 stage & marshaling numbers before Slice C2.

## 2026-11-03 05:43 ET, Claude: no new slice yet

- Checked Drive and `main`: no slice newer than `patch_001_slice_c0.zip`, and no new
  notes from Argon. `main` is still at the C0 entry below. Nothing to apply; stopping
  until Michael or Argon picks this up.
- Next actor: **Argon** (slice C1, or a C0b that wires the profiler first).

## 2026-11-03, Claude: slice C0 checked

- **Base:** `main` at `2273c8f` (PR #50: purge 2c/3, tuning hoist, post-purge baseline).
- **Patch:** `patch_001_slice_c0.zip` applied on `csharp/slice-c0`.
- **Status / next actor:** see the result section at the bottom of this entry.

### Container toolchain (works, offline)

- .NET SDK 8.0.133 from Ubuntu's archive; Godot 4.7.2 .NET build from GitHub releases.
- NuGet (`api.nuget.org`) and Microsoft's download sites are blocked here. The build
  resolves `Godot.NET.Sdk`, `GodotSharp` and `Godot.SourceGenerators` from the packages
  bundled with the Godot .NET download (`GodotSharp/Tools/nupkgs`) through a user-level
  NuGet config. **So C# code can't depend on any other NuGet package**: anything beyond
  the .NET base library and GodotSharp won't build in the test container.
- Tests and golden captures now run on the .NET Godot binary.

### Changes Claude made to C0

1. `project.godot`: `dotnet/project/assembly_name` changed from
   `"Demonologist (text prototype)"` to `"Demonologist"`. Godot looks for
   `<assembly_name>.csproj`, and the project file is `Demonologist.csproj`. **Michael's
   Windows editor will regenerate its own `.godot/mono` output under the new name; if it
   had a `Demonologist (text prototype).csproj` locally, that file is now unused.**
2. `tools/run_gd_tests.py`: builds `Demonologist.csproj` before running suites. It uses
   **Debug**, not Release as the manifest said: the editor binary (what headless test
   runs use) loads `.godot/mono/temp/bin/Debug`. A failed build fails the whole run.
3. `workshop/caches.gd`: `SolverBackend.clear_context()` added at the end of
   `clear_all()`, as the manifest asked.

### Notes for Argon

- **Static calls work.** GDScript calls the C# static methods on the loaded script
  (`SetMode`, `ClearContext`, `EvalMathBatch`, `VerifyFloat64Buffer`) without trouble on
  4.7.2, and `PackedFloat64Array`/`PackedInt32Array` marshal to `double[]`/`int[]`.
  Keep that pattern for C1.
- **The profiler isn't wired yet.** `SolverBackend.record_stage` and the stage list exist,
  but nothing calls them, so the C0 deliverable "late-game stage breakdown and marshalling
  budget" hasn't been measured. Suggest C1 (or a small C0b) adds timers around the real
  call sites (jury/shared_ledger outer prep, world_domain, live_activity `_likelihood`,
  case_eval compile, channel sum-product, reason attribution) behind
  `SolverBackend.profiling_enabled`, plus call counts per boundary function, and
  a `tools/profile_c0.gd` that plays seed 42 to Day 4 and prints
  `format_profile_report`. Claude will run it and post the numbers here.
- **The math audit covers a sample, not the kernel.** `test_csharp_slice_c0` checks 164
  hand-picked inputs at 0 ULP (all pass on Linux). The kernels' actual `exp`/`log`/`pow`
  call sites and argument ranges still need listing before C1; any that differ at a
  boundary need the shared implementation the plan describes.
- **Windows vs Linux check** (plan section 1.2) needs Michael's machine: run
  `tools/golden_capture.gd` there and diff it against `baseline_82faa5b`. Until then,
  only the Linux container is a valid golden platform.
- **Integer widths for C1:** `case_eval` world codes (`radix = 3^k`, `rm_bound`) need
  `long`. `Math.Round` must be `MidpointRounding.AwayFromZero` everywhere (the bridge
  does this). Pack people/cards in the same order GDScript iterates its dictionaries.
- **Golden runs need a clean log:** Godot keeps running when a script fails to compile, so
  check a capture's log for `SCRIPT ERROR` before trusting a diff. That's how two broken
  purge scripts got through on Nov 2.

### Result

- `dotnet build`: succeeds, 0 warnings (Debug and Release).
- Suites on the .NET Godot binary: `test_csharp_slice_c0` (164 checks, 0 ULP),
  `test_headline`, `test_workshop_ownership`, `test_legacy_purge_phase3`,
  `test_role_def_poc`, `test_beliefs`, `test_workshop_tuning_probe`: all pass.
  All 260 scripts parse.
- Golden capture on the .NET binary vs `baseline_82faa5b`, `--tol 0`: **all five seeds
  identical**, no script errors. So the .NET build of Godot plays the same game as the
  standard one, and C0 changed nothing.
- **Pushed to `main`.** Next actor: **Argon** (slice C1, or a C0b that wires the
  profiler first; see notes above). Claude checks Drive again around 05:40 ET.
