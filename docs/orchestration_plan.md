# Demonologist: Master Orchestration & Migration Plan

**Status:** Active Orchestrator Roadmap  
**Updated:** 2026-10-28  
**Suggested repository location:** `docs/ORCHESTRATION_PLAN.md`

This document tracks the 13 active, ready-to-build, conceptual, and tabled work zones across the project, sequences them into six dependency-ordered milestones, and defines the slice-by-slice extraction plan for `game/game.gd` and the procedural `ui/` scenes.

## 1. Master Work Zone Inventory

| Zone | Work Zone | Current Status | Primary Files & Surfaces | Scope & Key Notes |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Dialogue & Cast Voices** | **Active Build** (Baseline + Batch 2 complete) | `sim/dialogue*.gd`, `sim/mind_dialogue.gd`, `sim/mind_meeting.gd`, `docs/DIALOGUE_DESIGN.md` | All 15 cast voices are live on core composer hooks plus Batch 2 (375 lines across role disclosures, opinions, block self-defence, trust economy, and role-guess pushback). Remaining for Batch 3: Workshop Jury solver-speak, gallows `last_words`, sleepwalking excuse, gift requests, and haunt/trait banter. |
| **2** | **Multi-Part Evidence Rework** | **Theorycrafted / Ready to Build** | `sim/world.gd`, `game/game.gd`, `workshop/live_activity.gd`, `workshop/case_graph.gd` | Replaces flat one-step evening-block traces (`World._kill`) with a `HINT_PACKAGES`-style multi-category physical evidence model (`home_block`, `work`, `haunts`, `traits`) that eliminates ~2 to 3 Demon candidates per clue in a 10-NPC town (4 to 6 across two clues) and fixes the evening-shift Demon vulnerability. Also groups the `78148` / `77388` challenge follow-ups. |
| **3** | **New Roles & Script Expansion** | **~5 Ready / More in Concept** | `sim/roles/*.gd` (20 files), `sim/role_def.gd`, `workshop/role_constraints.gd`, `role_exploration.md` | 15 good gifts and 4 minions exist in `sim/roles/`. ~5 roles are ready for implementation and testing (Tracker, Clairvoyant, Bellringer, Framer/Forger, plus Sexton/Psychologist/Rumormonger integration passes), with Hexer, Informant, Blackmailer, and Debtor in concepting. |
| **4** | **Code & Scene Migrations** | **Ready to Execute** | `game/game.gd` (2,718 LOC), `ui/main.gd` (1,260 LOC), `ui/*.tscn` (four 12-line stubs) | `game/game.gd` has already shed `game_board.gd` (573 LOC) and `game_presentation.gd` (452 LOC), but still holds ~2,200 lines of conversation, meeting, day/night, and screen logic. All four `.tscn` files are 12-line stubs building UI trees procedurally in GDScript. |
| **5** | **UI Polish & Text Formatting** | **Ongoing (Partly Paused)** | `ui/board_view.gd` (697 LOC), `ui/text_formatter.gd`, `docs/text_system_handoff.md` | Rich-text formatting Steps 1 to 3 (log and profiles) and Batch 4 UI polish are merged. Steps 4 to 5 (board cards, pinned deductions, tray, Card List) and private/confidential card badges await fixing card zoom, text clipping, and row-height jumps in `ui/board_view.gd`. |
| **6** | **VN / Ace Attorney Layer** | **Concepted / Prototyping Soon** | `sim/dialogue_contract.gd`, `game/game_presentation.gd`, `ui/main.gd`, `ui/meeting_view.gd` | Visual novel staging for 1-on-1 interrogations, pressing ("Hold it!" contradictions), and courtroom-style town meetings. Plugs into `dialogue_contract.gd` once `game/game.gd` and `ui/main.gd` are split into modular controllers and scenes. |
| **7** | **Circumstantial Evidence System** | **Early Concept** | `workshop/consequences.gd`, `workshop/jury.gd`, `workshop/public_evidence.gd`, `game/workshop_ownership.gd` | Two-stage Case Workshop extension: Stage 1B adds per-world likelihood factors for public actions (votes, nominations, defences); Stage 2 adds a gated additive "vibes" layer (shared location with a Breathstealer silencing, pressure tells, corroborated walking routes) scaled by Stage 1 movement and stored in a separately retractable ownership vector. |
| **8** | **Meeting Flow Overhaul** | **Early Concept (Steps 1-2 Built)** | `sim/mind_meeting.gd` (1,107 LOC), `ui/meeting_view.gd`, `docs/meeting_flow_plan.md` | Steps 1 to 2 (nominator case + nominee self-defence) and streamed testimony are built. Steps 3 to 6 (supporters queue, 3-speaker trial director, reactive interjections when named, selective vote talk, and last words) should be co-designed with the VN courtroom view. |
| **9** | **Social & Vote Conversion Tuning** | **Decided / Needs Balance Pass** | `sim/mind.gd` (1,661 LOC), `sim/evil.gd` (824 LOC), `sim/tuning.gd` (493 LOC), `TUNING_NARRATIVE.md` | Resolves the playtest `54875` / `61251` agreement-to-vote gap (where NPCs agree 1.0 with a case but vote no against a 0.43 threshold). Covers premise-weighted belief updates, execution-priority vote terms, late-game urgency scaling, evil cover priorities, and Privacy double-counting fixes. |
| **10** | **Roguelike Randomization** | **Layered (Live -> Concept)** | `sim/content.gd`, `sim/world.gd`, `role_exploration.md` | Tier 1 (NPC trait, occupation, and role shuffling) is live. Tier 2 (script randomization + Storyteller solvability check) awaits the Phase 4 role pool. Tier 3 (procedural town blocks, buildings, and road topology) is a horizon concept. |
| **11** | **Progression & Meta-Game** | **Early Concept** | `DESIGN.md`, `BACKLOG.md` (Section 4) | Unlockable Demonologist toolbox (Autopsy, Seance, Scry, Binding Circle), distinct Demon breeds with bestiary entries and true-name exorcism alternate wins, and granular post-case outcome scoring. |
| **12** | **Solver Latency, Legacy Cutover & Bot Tooling** | **Ongoing Infrastructure** | `workshop/solver.gd` (870 LOC), `sim/argue.gd` (1,582 LOC), `tools/autoplay.gd`, `ui/decision_window.gd` | Keeps Day 3 and Day 4 meeting evaluations under the 2-second budget (~45 static caches in `solver.gd`), teaches `autoplay.gd` to interpret physical evidence and build Workshop cases, and retires the 1,582-line legacy template engine (`sim/argue.gd`). |
| **13** | **Movement & Routing Rework** | **Tabled** | `sim/content.gd`, `workshop/movement_model.gd`, `workshop/live_activity.gd` | Destination-only block vigils (`C.vigil_sees_path`) resolved the immediate vigil dominance issue. Full passing-through vs. stopping sighting semantics and live Demon detours remain parked unless post-evidence playtesting requires them. |

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
| **`ui/main.gd`** | Zone 4 (Scene splits), Zone 5 (UI polish), Zone 6 (VN layer) | Extract `ui/` sub-scenes before prototyping the VN stage so visual layout changes do not collide with action-picker or log logic. |

## 4. Specific Migration Plan: `game/game.gd` Slices

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
- **Verification**: `test_npc_interactions`, `test_dialogue`, `test_dialogue_decisions`, `test_social`, `test_backlog_batch4`, `test_playtest_followups`.

### Slice 2: `game/game_meeting.gd` (~295 LOC Extracted)
*Scope: Lines 1650 to 1942 (`# --- meeting`). Unblocks Meeting Flow Steps 3 to 6 and the Ace Attorney Courtroom view.*

- **Functions to Move**:
  - **Meeting Lifecycle & Streamed Testimony (Lines 1652 to 1710)**: `_start_meeting`, `meeting_streaming`, `testimony_step`, `_testimony_turn`, `_meeting_opened`.
  - **Floor Commands & Nominations (Lines 1711 to 1797)**: `_meeting_command`, `_next_npc_nomination`, `_defend_pending`, `vote_requirement_text`, `_show_nomination`.
  - **Voting & Trial Resolution (Lines 1798 to 1942)**: `_nomination_command` (coroutine with `await` support for progress callbacks), `_after_vote`, `_last_words`, `_close_meeting`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (noting `await GameMeeting._nomination_command(self, verb, rest, progress)` for async parity). Tests and `ui/main.gd` directly call `meeting_streaming`, `testimony_step`, `vote_requirement_text`, `_start_meeting`, and `_close_meeting`.
- **Verification**: `test_meeting_stream`, `test_outcomes`, `test_mechanics_defences`, `test_defence_repeats`, `test_backlog_batch3`, `test_backlog_batch4`.

### Slice 3: `game/game_day_night.gd` (~430 LOC Extracted)
*Scope: Lines 610 to 911 (`# --- day`) and Lines 1943 to 2069 (`# --- night`). Isolates `_search` and `_observe` for the Multi-Part Evidence rework.*

- **Functions to Move**:
  - **Visibility & Movement Helpers (Lines 617 to 674)**: `unseen_at`, `unseen_at_ui`, `can_see`, `can_see_ui`, `_present`, `_resolve_go`, `_best_location_on`.
  - **Day Actions, Observation & Crime-Scene Search (Lines 675 to 911)**: `_day_command`, `_warn_busy_visit`, `_who_here`, `_observe`, `_search`, `_end_phase`.
  - **Night Actions & Dawn Resolution (Lines 1943 to 2069)**: `_night_homes`, `_night_command`, `_resolve_night`, `_fallbacks_text`, `_morning_report`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (UI and tests directly call `can_see`, `can_see_ui`, `unseen_at`, `unseen_at_ui`, `_search`, `_morning_report`, and `_present`).
- **Verification**: `test_mechanics_sightings`, `test_sighting_followup`, `test_lamplighter_drops`, `test_mechanics_warden`, `test_mechanics_curse`, `test_town_ui`.

### Slice 4: `game/game_screens.gd` (~565 LOC Extracted)
*Scope: Lines 2070 to 2386 (`# --- info screens`) and Lines 2472 to 2718 (Theory, Guesses, Debug Overlay, and Profile Data).*

- **Functions to Move**:
  - **Text & CLI Info Screens (Lines 2070 to 2386)**: `_intro`, `_help`, `_look`, `_card_workers`, `_card_conversations`, `_map`, `_cast`, `_profile`, `_script`, `_tools`, `_board`, `_ending`, `_grimoire`, `_exchanges`, `_lies`, `_write_logs`.
  - **Player Theory, Predictions & Debug/Profile Data (Lines 2472 to 2718)**: `set_note`, `set_guess`, `set_secret_guess`, `capture_prediction`, `theory_status`, `_outcome_text`, `set_debug_overlay`, `_spread`, `debug_card_text`, `debug_npc_text`, `named_in`, `_death_text`, `_claim_text`, `profile_data`.
- **Forwarders Retained on `Game`**: Keep thin forwarders on `game/game.gd` (`profile_data`, `set_guess`, `set_secret_guess`, `set_note`, `capture_prediction`, `theory_status`, `set_debug_overlay`, `debug_card_text`, `debug_npc_text`, `named_in`, `_card_workers`, `_help`).
- **Verification**: `test_text_ui`, `test_ui`, `test_profile_panel` / `test_fixes`, `test_outcomes`, `test_trace`.

### Post-Migration Shape of `game/game.gd` (~600 LOC)
After all four slices land, `game/game.gd` is reduced from **2,718 lines to ~600 lines** and acts purely as the **central state container and command router**:
1. **Session State & Preloads** (Lines 1 to 110)
2. **Event Stream & Output Buffer** (`_ev`, `_headline`, `_narr`, `render`)
3. **Case Lifecycle & Top-Level Command Entry** (`new_case`, `command`, `workshop_command`, `_dispatch`)
4. **Entity Token Parsers** (`find_npc`, `find_location`, `find_role`, `find_block`)
5. **1-Line Forwarders** to `GameBoard`, `GamePresentation`, `GameConversation`, `GameMeeting`, `GameDayNight`, and `GameScreens`.
