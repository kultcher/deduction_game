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
