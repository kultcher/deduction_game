# Demonologist: Master Orchestration & Migration Plan

**Status:** Roadmap, refreshed Nov 5 late night against `main` (`ce470c3`). Phases 1 and 2
are mostly done. Phase 3's meeting trial flow and courtroom stage are built (meeting plan
M2b–M3a); its bot cutover (M4) is next. Phase 4's bot cutover and legacy retirement are
done, and its balance pass has started (the first overnight sweep, Nov 4–5). The zone table
below carries the current status, and section 1a has what's in flight. The phase text
further down is the original Oct 28 plan, kept for its ordering rationale.
**Updated:** 2026-11-05

This document tracks the work zones across the project, sequences them into six dependency-ordered milestones, and records the slice-by-slice extraction plan for `game/game.gd` (done Nov 3).

## 1. Master Work Zone Inventory

| Zone | Work Zone | Status (Nov 5) | Primary Files & Surfaces | Where it stands |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Dialogue & Cast Voices** | **Done** (batches 2–7) | `sim/dialogue*.gd`, `sim/mind_dialogue.gd`, `sim/mind_meeting.gd`, `docs/DIALOGUE_DESIGN.md` | All 15 voice packs share one ~230-key schema with no `[PH]` left, including greetings, last words, the sleepwalk excuse, gift requests, haunt/trait banter and the voiced Workshop presentation replies (`sim/dialogue_presentations.gd`). Open targets (variation, consolidation, serious mode, relationship interplay) are in DIALOGUE_DESIGN section 10. |
| **2** | **Multi-Part Evidence Rework** | **Done** (Oct 30, PRs #33–#37) | `sim/world.gd`, `game/game_day_night.gd`, `workshop/live_activity.gd`, `workshop/trace_solver.gd` | Token and scent traces at 3:1, hidden profile receipts with a Profile Info node instead of home and haunt cards, a second trace from a passer with joint scoring. The 78148 / 77388 challenge follow-ups are still in BACKLOG. |
| **3** | **New Roles & Script Expansion** | **In progress** | `sim/roles/*.gd`, `sim/role_def.gd`, `sim/script_def.gd`, `sim/script_builder.gd`, `workshop/role_constraints.gd` | 23 town roles are live: the 15 starters, Augur, Chronicler, Executor, Magistrate and Registrar (Nov 4), Psychologist (patch 013), Monitor and Confessor (patch 014), and Sexton (patch 015). There are 5 Minions: Poisoner, Breathstealer, Scion, Revenant, and the Brute (patch 015). The Muddler modifier landed with patch 013. Scripts, the script editor and the New Case screen landed Nov 4 (PR #54); dynamic random scripts merged Nov 4 (PR #58). Tracker, Clairvoyant, Bellringer and Framer/Forger are not built. DESIGN.md still lacks the Monitor, Psychologist and Confessor (playtest 13910, issue 19). |
| **4** | **Code & Scene Migrations** | **`game.gd` done; `ui/` scenes not started** | `game/game*.gd`, `ui/main.gd` (1,514 LOC), `ui/*.tscn` | `game.gd` went from 2,886 to 1,020 lines (Nov 3) with `game_conversation.gd`, `game_meeting.gd`, `game_day_night.gd` and `game_screens.gd`. The `.tscn` files are still stubs that build their trees in code. |
| **5** | **UI Polish & Text Formatting** | **Partly paused** | `ui/board_view.gd`, `ui/text_formatter.gd`, `docs/archive/text_system_handoff.md` | Text steps 1–3 (log and profiles) are live. Steps 4–5 (board cards, Card List) and the private/confidential card badges wait on the card zoom and sizing pass (BACKLOG UI, BACKLOG_POLISH). |
| **6** | **VN / Ace Attorney Layer** | **Conversations and courtroom built** | `ui/vn_portraits.gd`, `ui/day_conversation_view.gd`, `ui/courtroom_stage.gd`, `ui/meeting_view.gd`, `assets/art/cast_expressions/` | Daytime conversations use VN portraits with five expressions for all 15 characters. The meeting's courtroom stage is built (M3a, PR #80, Nov 5), sharing the portraits through `ui/vn_portraits.gd`. Testimony, the accuser's case, the defence, the press, supporters, resistance lines and last words come forward one speaker at a time, with a status pill and a 1.2s dusk arrival. It's only been seen headless; layout and pacing need a look on screen. Contradiction callouts and poses are not built. |
| **7** | **Circumstantial Evidence System** | **Stage 2 hub done; Stage 1B open** | `workshop/circumstantial.gd`, `workshop/jury.gd`, `game/workshop_ownership.gd` | The circumstantial hub (+0.015 per incident, +0.045 cap) is live. Votes, nominations and defences as per-world likelihood factors (Stage 1B) are not built: votes are procedural public events only. |
| **8** | **Meeting Flow Overhaul** | **In progress** (M0–M4 bot done; M4 sweep tonight) | `sim/mind_meeting.gd`, `sim/mind_support.gd`, `sim/mind_podium.gd`, `game/game_meeting.gd`, `ui/meeting_view.gd`, `docs/meeting_flow_plan.md` | Live: nominator's case, defences, streamed testimony, last words, peer role gossip (M1), player nominations, `block_safety`, reactive testimony and crowd fading (M2a), the podium press (M2b), supporters (M2c, PR #76), the player's turn and vote resistance lines (M2d, PR #78), the defence going after a filed case's pivotal card (PR #79) and the courtroom stage (M3a, PR #80). Next: M4, the bot cutover (the bot doesn't yet drive the press or the player's turn) and the 150-seed sweep. M4 bot notes are in the plan. No A/B has been run yet for M2c or M2d. |
| **9** | **Social & Vote Conversion Tuning** | **Partly done; balance pass pending** | `sim/mind_meeting.gd`, `sim/evil.gd`, `sim/tuning.gd`, `TUNING_NARRATIVE.md` | Built since Oct 28: rapport and credibility split, directional Confidence, a balanced execution-priority vote term, late-game urgency, the Scion-aware evil cover rules. Nov 4–5: the first overnight balance sweep ran (Project: `claude/balance-sweep-report-2026-11-05.md` and the deep dive). DESIGN.md now has a balance target: a skilled player wins 70–75% and names the Demon in 85–90%. Evidence honesty fixes (PR #74) removed the Lamplighter bluff's edge (exclusion by vigil, walker claim weights, Medium destinations). NPC openness step 1 merged (PR #77). Open: the oracle sweep (`docs/oracle_sweep_plan.md`), Tally's Night Watch and Medium bluff checks, and the player's +0.125 vote push. |
| **10** | **Roguelike Randomization** | **Tier 2 started** | `sim/script_builder.gd`, `ui/new_case_screen.gd`, `role_exploration.md` | Tier 1 (traits, occupations, roles) is live. Tier 2: scripts, the builder and dynamic random scripts (PR #58) are live; the Storyteller solvability check is not built. Tier 3 (procedural towns) is a horizon concept. |
| **11** | **Progression & Meta-Game** | **Early concept** | `DESIGN.md`, `BACKLOG.md` (section 4) | Unchanged: toolbox unlocks, demon breeds and bestiary, exorcism wins, outcome scoring. |
| **12** | **Solver Latency, Legacy Cutover & Bot Tooling** | **Cutover done; latency ongoing** | `workshop/`, `workshop/cs/`, `tools/autoplay.gd`, `tools/analyst.gd` | The legacy belief system and `sim/argue.gd` are gone (Nov 2–3). The solver kernel runs in C# (slices C0–C3, Nov 3; C4 only if profiling asks for it). The analyst bot builds Workshop cases through a neutral juror. Nov 5: the replay and explanation tools (`tools/replay_log.gd --why`, `tools/explain_case.gd`, PR #72), portable golden paths (PR #68), and test consolidation into feature suites (PRs #70–#71; 112 suites). |
| **13** | **Movement & Routing Rework** | **Tabled** | `sim/content.gd`, `workshop/movement_model.gd`, `workshop/live_activity.gd` | Destination-only vigils are live. Passing-through vs stopping and live Demon detours stay parked. |
| **14** | **Premises Pass (cases and challenges)** | **Steps 0 and 0b done; step 1 next** | `workshop/shared_ledger.gd`, `workshop/reasoner.gd`, `workshop/jury.gd`, `workshop/case_eval.gd`, `workshop/reading_challenges.gd`, `sim/dialogue_presentations.gd`, `docs/premises_plan.md` | Plan settled Nov 5 (`docs/premises_plan.md`, Project `claude/premises-plan.md`). Steps 0 (a bare defence cites no grounds, PR #81) and 0b (one attended set, PR #86) are on main. Next: step 1 (conditioning on the premise, 40–80% Insight spillover, the trust cost, replies from the conditioned result), step 2 (types and secrets), step 3 (graded challenges) and step 4 (Scion/Revenant, movement premises). Playtest 13910's issue 5 waits on step 1. |

## 1a. In flight (Nov 6, early)

- **Who does what:** Claude-Bailiff runs checks, tests and Git, and builds the meeting plan. Claude-Tally runs sweeps, A/Bs, balance checks and playtest analysis. Argon (Gemini) sends role patches through the Drive folder "Demonologist Patches", and Claude checks and lands them. Claude-Quill drafts plans and docs. Claude-Steward does maintenance passes. Every agent signs `docs/handoff_log.md`.
- **Landed tonight:** premises step 0 (#81) and 0b (#86, `baseline_50bd642`), the M4 bot (#84, `--pre-m4` for A/Bs), and the Codex review fixes (#85 tooling, #87 game).
- **Now:** the overnight sweep on main `03bcdd8` (Tally): the M4 bot against `--pre-m4`, plus passive, on dynamic scripts at 7 and 10 NPCs. Compare with `sweep-results/run-42129219721`.
- **Next, in order:**
  1. Read the sweep: M4's effect, then balance against the target in DESIGN.md.
  2. Premises step 1, measured with the M4 bot (attention budgets held fixed between arms).
  3. The oracle sweep and Tally's bluff checks, overnight whenever the runners are free.
- **Baseline rule:** one behaviour change lands at a time, each with its own golden baseline. UI-only and docs-only changes must match the current baseline at `--tol 0`.

## 2. Six-Phase Milestone Sequence

### Phase 1: Structural Decoupling & Core Evidence Foundation
*Goal: Run isolated tracks with zero file overlap to break up the `game.gd` / `ui/main.gd` monoliths while landing the new physical evidence model and non-Workshop dialogue.*

- **Track 1A (Code & Scene Migrations - Zone 4)**: Extract `game_conversation.gd`, `game_meeting.gd`, `game_day_night.gd`, and `game_screens.gd` from `game/game.gd` (retaining 1-line forwarders on `Game`), then extract modular `.tscn` scenes from `ui/main.gd`.
- **Track 1B (Multi-Part Evidence Rework - Zone 2)**: Implement the `HINT_PACKAGES`-style multi-category physical trace and clue chain across `sim/world.gd`, `game/game_day_night.gd` (`_search`), and `workshop/live_activity.gd`, plus the deferred `78148` / `77388` challenge fixes.
- **Track 1C (Dialogue Batch 3 Non-Workshop Surfaces - Zone 1)**: Wire voiced gallows `last_words`, sleepwalking excuses, gift request/counterproposal lines, and haunt/trait banter in `sim/dialogue*.gd` and `sim/mind_*.gd`.

### Phase 2: Case Workshop Stage 2, Voiced Jury & Board UI Polish
*Goal: Extend Case Workshop with soft actions and gated vibes once Stage 1 evidence is stable, voice the resulting Jury feedback, and finish the Case Board text/zoom pass.*

- **Circumstantial Evidence System (Zone 7)**: Add Stage 1B soft-action factors (votes, nominations, defences) in `workshop/public_evidence.gd` and Stage 2 gated impressions (Breathstealer silencing proximity, pressure tells, walking corroboration) in `workshop/jury.gd::_consequences_eval`, tracked in a separate retractable vector in `game/workshop_ownership.gd`.
- **Voiced Workshop Jury Replies (Zone 1 Completion)**: Replace clinical solver strings in `workshop/jury.gd` and `game/workshop_presentation.gd` with 15-character voiced evaluations.
- **Board Card Zoom & Rich Text Steps 4 to 5 (Zone 5)**: Fix card zoom, text clipping, and badge slots (`shared_privately`, `confidential`) in `ui/board_view.gd`, then roll out `ui/text_formatter.gd` spans to board cards, pinned deductions, the tray, and Card List.
- **Solver Cache & Latency Audit (Zone 12 Part 1)**: Profile `replay_54875.gd` and Seed 42 (Days 3 to 4) to ensure the new evidence and Stage 2 channels stay within the 2-second meeting/presentation budget.

### Phase 3: VN / Ace Attorney Presentation & Meeting Trial Overhaul
*Goal: Build the visual stage and courtroom trial flow together on top of the decoupled Phase 1 controllers and scenes.*

- **VN / Ace Attorney Presentation Layer (Zone 6)**: Build the interrogation and courtroom stage components, character expression/pose states, and contradiction callouts over `sim/dialogue_contract.gd` and `game/game_presentation.gd`.
- **Meeting Flow Overhaul Steps 3 to 6 (Zone 8)**: Implement the supporter queue (`Mind.support_queue`), 3-speaker trial director (`Mind.pick_supporters`), reactive interjections when named, and selective vote explanations (`sim/mind_meeting.gd` + `ui/meeting_view.gd`).

### Phase 4: Roster Expansion, Bot Workshop Cutover & Social/Vote Tuning
*Goal: Expand the role pool, upgrade the autoplay bot to use the full Workshop and physical evidence rules, and run a data-backed balance pass.*

- **New Roles Batch (Zone 3)**: Implement and test the ~5 ready roles (Tracker, Clairvoyant, Bellringer, Framer/Forger, plus remaining role adapters) across `sim/roles/` and `workshop/role_constraints.gd`.
- **Bot Cutover & `sim/argue.gd` Retirement (Zone 12 Part 2)**: Upgrade `tools/autoplay.gd` to evaluate multi-category physical clues and greedily construct Workshop cases via the test juror, then retire `sim/argue.gd` and legacy text `link` / `conclude` templates.
- **Social & Vote Conversion Tuning (Zone 9)**: Tune premise-weighted belief updates, execution-priority vote terms, late-game urgency, evil cover stakes, and Privacy openness gates in `sim/tuning.gd`, verified with 150-seed active/passive bot comparisons.

### Phase 5: Script Randomization & Meta-Progression
*Goal: Turn the balanced single-case loop into a replayable roguelike campaign.*

- **Script Randomization & Solvability Director (Zone 10 Part 1)**: Build the script generator over the 20+ role pool with role-category guarantees and a Storyteller solvability check.
- **Progression & Demonologist Toolbox (Zone 11)**: Add unlockable player tools (Autopsy, Seance, Scry, Binding Circle), Demon breeds with bestiary entries and true-name exorcism wins, and post-case attribution scoring.

### Phase 6: Horizon Concepts (Procedural Towns & Movement Rework)
*Goal: Tackle high-disruption spatial systems only after core mechanics and meta-progression are complete.*

- **Procedural Town Generation (Zone 10 Part 2)**: Generate blocks, workplaces, cottages, and road connections per case.
- **Movement & Routing Rework (Zone 13 - Tabled)**: Revisit passing-through vs. stopping sightings and live Demon detours only if post-Phase-4 playtests call for deeper spatial puzzles.

## 3. Collision & File-Ownership Rules for Parallel Threads

| Shared Surface | Competing Work Zones | Isolation Rule |
| :--- | :--- | :--- |
| **`workshop/jury.gd` & `game/workshop_ownership.gd`** | Zone 2 (Multi-Part Evidence), Zone 7 (Stage 2 Vibes), Zone 1 (Voiced Jury) | Never edit in parallel. Land Zone 2 first, Zone 7 second, and Zone 1 Jury voicing last. |
| **`game/game.gd`** | Zone 4 (Migrations), Zone 2 (`_search`), Zone 8 (Meeting flow) | Complete the **4-slice `game.gd` extraction (Section 4)** first so future features edit domain modules (`game_day_night.gd`, `game_meeting.gd`, `game_conversation.gd`) instead of one 2,718-line file. |
| **`ui/main.gd`** | Zone 4 (Scene splits), Zone 5 (UI polish), Zone 6 (VN layer) | The VN stage was built inside `ui/meeting_view.gd` with small hooks in `main.gd` (`_capture_meeting`, `meeting_view.consume`), without the scene split. Keep new UI in its own files and keep the hooks in `main.gd` thin. |
| **`workshop/reasoner.gd`, `shared_ledger.gd`, `jury.gd`, `case_eval.gd`** | Zone 14 (Premises pass), Zone 9 (balance fixes), Zone 7 (Stage 1B) | One branch at a time: premises steps 0, 0b and 1 land in order, each with its own baseline. Evidence-honesty and balance changes to `case_eval.gd` wait for a step to land, or go through the same branch. |
| **`sim/mind_meeting.gd` (defences, votes)** | Zone 8 (meeting M4), Zone 14 (defence grounds) | Defences feed the ledger that step 0 changes. Merge step 0 before M4's sweep, and rebase meeting work on it. |
| **`tools/autoplay.gd`, `tools/analyst.gd`** | Zone 8 (M4 bot cutover), Zone 9 (sweeps) | Bailiff builds the bot changes; Tally runs the sweeps on a merged commit only, so results point at one build. |

## 4. Specific Migration Plan: `game/game.gd` Slices

**Done Nov 3** (Argon's `patch_005`, checked by Claude): `game.gd` is 1,020 lines and the four helpers below exist as planned. The section is kept as the record of what moved where.

### Current State of `game/game.gd` (2,718 Lines)
Two extractions have already succeeded using the **Static Domain Helper + Thin Forwarder** pattern:
- `game/game_board.gd` (573 LOC): Owns card creation, corroboration, board filtering, timeline data, and deduction filing.
- `game/game_presentation.gd` (452 LOC): Owns Workshop snapshots, previews, readiness gates, deduction evaluation, and private/meeting presentation routing.

Because `game/game.gd` keeps 1-line forwarding methods (such as `func add_card(fact: Dictionary) -> int: return GameBoard.add_card(self, fact)`), **all 86 test suites and every UI script continue calling `g.<method>(...)` without breaking**. We will use this exact pattern to extract the remaining ~2,100 lines of domain logic in four sequential, independently testable slices.

### Slice 1: `game/game_conversation.gd` (~740 LOC Extracted)
*Scope: Lines 912 to 1649 (`# --- approaches` and `# --- conversation`). Unblocks Dialogue Batch 3 and the VN Interrogation view.*

- **Functions to Move**:
  - **Approaches & Promises (Lines 912 to 1059)**: `_maybe_approach`, `_promised_to`, `_maybe_divulge`, `_approach_command`, `_protect_approach_answer`, `_grant_protection`, `_phase_header`.
  - **Conversation & Question Routing (Lines 1060 to 1352)**: `_remember_dialogue_exchange`, `_talk_options`, `_repeat_refusal`, `_talk_command`, `_close_conversation`.
  - **Requests, Grievances & Offers (Lines 1353 to 1515)**: `_answer_request`, `_answer_request_now`, `_gift_request`, `_grievance_menu`, `grievance_text`, `_offer_command`, `offer_text`, `_settle_offers`.
  - **Haunts, Traits & Relationships (Lines 1516 to 1640)**: `OBSERVABLE_TRAITS`, `TRAIT_WORDS`, `_maybe_tell_haunts`, `_maybe_tell_trait`, `_maybe_tell_relationships`, `_remember_spoken_relationship`, `known_relationship_notes`, `find_links`, `known_haunt_names`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` for all moved methods (tests and UI directly call `_settle_offers`, `_maybe_tell_relationships`, `_maybe_tell_trait`, `_talk_options`, `_approach_command`, `_maybe_divulge`, `offer_text`, `known_relationship_notes`, `find_links`, and `known_haunt_names`).
- **Verification**: `test_npc_interactions`, `test_dialogue`, `test_dialogue_decisions`, `test_social`, `test_conversation_gifts`, `test_conversation_nights`, `test_ui_controls`.

### Slice 2: `game/game_meeting.gd` (~295 LOC Extracted)
*Scope: Lines 1650 to 1942 (`# --- meeting`). Unblocks Meeting Flow Steps 3 to 6 and the Ace Attorney Courtroom view.*

- **Functions to Move**:
  - **Meeting Lifecycle & Streamed Testimony (Lines 1652 to 1710)**: `_start_meeting`, `meeting_streaming`, `testimony_step`, `_testimony_turn`, `_meeting_opened`.
  - **Floor Commands & Nominations (Lines 1711 to 1797)**: `_meeting_command`, `_next_npc_nomination`, `_defend_pending`, `vote_requirement_text`, `_show_nomination`.
  - **Voting & Trial Resolution (Lines 1798 to 1942)**: `_nomination_command` (coroutine with `await` support for progress callbacks), `_after_vote`, `_last_words`, `_close_meeting`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (noting `await GameMeeting._nomination_command(self, verb, rest, progress)` for async parity). Tests and `ui/main.gd` directly call `meeting_streaming`, `testimony_step`, `vote_requirement_text`, `_start_meeting`, and `_close_meeting`.
- **Verification**: `test_meeting_stream`, `test_outcomes`, `test_mechanics_defences`, `test_defence_repeats`, `test_meeting_flow`.

### Slice 3: `game/game_day_night.gd` (~430 LOC Extracted)
*Scope: Lines 610 to 911 (`# --- day`) and Lines 1943 to 2069 (`# --- night`). Isolates `_search` and `_observe` for the Multi-Part Evidence rework.*

- **Functions to Move**:
  - **Visibility & Movement Helpers (Lines 617 to 674)**: `unseen_at`, `unseen_at_ui`, `can_see`, `can_see_ui`, `_present`, `_resolve_go`, `_best_location_on`.
  - **Day Actions, Observation & Crime-Scene Search (Lines 675 to 911)**: `_day_command`, `_warn_busy_visit`, `_who_here`, `_observe`, `_search`, `_end_phase`.
  - **Night Actions & Dawn Resolution (Lines 1943 to 2069)**: `_night_homes`, `_night_command`, `_resolve_night`, `_fallbacks_text`, `_morning_report`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (UI and tests directly call `can_see`, `can_see_ui`, `unseen_at`, `unseen_at_ui`, `_search`, `_morning_report`, and `_present`).
- **Verification**: `test_mechanics_sightings`, `test_sighting_followup`, `test_roles_night_sight` (Lamplighter drops), `test_roles_shelter` (Warden), `test_roles_evil` (curse), `test_town_ui`.

### Slice 4: `game/game_screens.gd` (~565 LOC Extracted)
*Scope: Lines 2070 to 2386 (`# --- info screens`) and Lines 2472 to 2718 (Theory, Guesses, Debug Overlay, and Profile Data).*

- **Functions to Move**:
  - **Text & CLI Info Screens (Lines 2070 to 2386)**: `_intro`, `_help`, `_look`, `_card_workers`, `_card_conversations`, `_map`, `_cast`, `_profile`, `_script`, `_tools`, `_board`, `_ending`, `_grimoire`, `_exchanges`, `_lies`, `_write_logs`.
  - **Player Theory, Predictions & Debug/Profile Data (Lines 2472 to 2718)**: `set_note`, `set_guess`, `set_secret_guess`, `capture_prediction`, `theory_status`, `_outcome_text`, `set_debug_overlay`, `_spread`, `debug_card_text`, `debug_npc_text`, `named_in`, `_death_text`, `_claim_text`, `profile_data`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (`profile_data`, `set_guess`, `set_secret_guess`, `set_note`, `capture_prediction`, `theory_status`, `set_debug_overlay`, `debug_card_text`, `debug_npc_text`, `named_in`, `_card_workers`, `_help`).
- **Verification**: `test_text_ui`, `test_ui`, `test_profile_panel` / `test_evidence_cards`, `test_outcomes`, `test_trace` (since retired).

### Post-Migration Shape of `game/game.gd` (~600 LOC)
After all four slices land, `game/game.gd` is reduced from **2,718 lines to ~600 lines** and acts purely as the **central state container and command router**:
1. **Session State & Preloads** (Lines 1 to 110)
2. **Event Stream & Output Buffer** (`_ev`, `_headline`, `_narr`, `render`)
3. **Case Lifecycle & Top-Level Command Entry** (`new_case`, `command`, `workshop_command`, `_dispatch`)
4. **Entity Token Parsers** (`find_npc`, `find_location`, `find_role`, `find_block`)
5. **1-Line Forwarders** to `GameBoard`, `GamePresentation`, `GameConversation`, `GameMeeting`, `GameDayNight`, and `GameScreens`.
