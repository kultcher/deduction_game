# Demonologist: Master Orchestration & Migration Plan

**Status:** Roadmap, refreshed Nov 8 against `main` (`7aa4176`) with Michael's settle/defer
review. It also restores what the Nov 5 refresh dropped from the Nov 3 plan (v8): the
learning-resources zone (tooltips, in-game wiki, tutorial), the extra role designs, the
Storyteller items and the stretch simulation goals. The zone table carries the current
status, section 1a has what's next and section 1b what's deferred. The phase text further
down is the original Oct 28 plan, kept for its ordering rationale.
**Updated:** 2026-11-08

This document tracks the work zones across the project, sequences them into six dependency-ordered milestones, and records the slice-by-slice extraction plan for `game/game.gd` (done Nov 3).

## 1. Master Work Zone Inventory

| Zone | Work Zone | Status (Nov 8) | Primary Files & Surfaces | Where it stands |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Dialogue & Cast Voices** | **Done** (batches 2–7) | `sim/dialogue*.gd`, `sim/mind_dialogue.gd`, `sim/mind_meeting.gd`, `docs/DIALOGUE_DESIGN.md` | All 15 voice packs share one ~230-key schema with no `[PH]` left. Open targets (variation, consolidation, serious mode, relationship interplay) are in DIALOGUE_DESIGN section 10. |
| **2** | **Multi-Part Evidence Rework** | **Done** (Oct 30, PRs #33–#37) | `sim/world.gd`, `game/game_day_night.gd`, `workshop/live_activity.gd`, `workshop/trace_solver.gd` | Token and scent traces at 3:1, profile receipts, second passer traces. The 78148 / 77388 challenge follow-ups are still in BACKLOG section 2. Haunts are learned firsthand (PR #94). |
| **3** | **New Roles & Script Expansion** | **In progress** | `sim/roles/*.gd`, `sim/role_def.gd`, `sim/script_def.gd`, `sim/script_builder.gd`, `workshop/role_constraints.gd` | 23 town roles and 5 minions are live, plus the Muddler; scripts, the editor, the New Case screen and dynamic random scripts are live. Not built: Tracker, Clairvoyant, Beckon, Tallyman, Bellringer, Bellwether; Framer/Forger, Blackmailer, Hexer, Informant, the Sower; the Debtor secret; Demon resilience (Dusk Compulsion / Mesmerize). Bellwether, the Sower and Dusk Compulsion are v8 designs with no write-up in role_exploration.md yet. Script follow-ups: an `is_demon` helper for a second demon type, builder rules, remembering the last script. The off-script tell was dropped (Nov 8: such a claim should never happen). DESIGN.md still lacks the Monitor, Psychologist and Confessor. |
| **4** | **Code & Scene Migrations** | **`game.gd` done; `ui/` scenes not started** | `game/game*.gd`, `ui/main.gd`, `ui/*.tscn` | `game.gd` is ~1,020 lines with its domain helpers. `ui/main.gd` still builds its tree in code; the `.tscn` files are stubs. |
| **5** | **UI Polish & Text Formatting** | **Partly paused** | `ui/board_view.gd`, `ui/text_formatter.gd`, `docs/text_formatting.md` | Text steps 1–3 are live. Board card sizing, zoom and badges (private / in confidence) come first; text steps 4–5 (board cards, Card List) wait on them. The UI control-flow pass (presentation lock, paced stage, day pane) is on main (PR #101). |
| **6** | **VN / Ace Attorney Layer** | **Built; extras deferred** | `ui/vn_portraits.gd`, `ui/day_conversation_view.gd`, `ui/courtroom_stage.gd`, `ui/meeting_view.gd` | Daytime conversations and the courtroom stage are live, paced and synced with the log, with an optional auto-advance. Daytime talks in a building sit in its papercraft interior (PR #103). Contradiction callouts and poses are **deferred** (Nov 8). Not built: Workshop presentations at meetings routed through the stage. |
| **7** | **Circumstantial Evidence System** | **Stage 2 hub done; Stage 1B open** | `workshop/circumstantial.gd`, `workshop/jury.gd`, `game/workshop_ownership.gd` | The circumstantial hub is live. Stage 1B (votes, nominations and defences as per-world likelihood factors) is not built. |
| **8** | **Meeting Flow Overhaul** | **Done** (M0–M4) | `sim/mind_meeting.gd`, `sim/mind_support.gd`, `sim/mind_podium.gd`, `game/game_meeting.gd`, `ui/meeting_view.gd`, `docs/meeting_flow_plan.md` | All slices are on main, including the M4 bot (PR #84) and its sweep. The live seat-by-seat player vote (stretch A) is **deferred** (Nov 8). Rare NPC mini-cases (stretch B) stay a stretch goal (zone 17). |
| **9** | **Social & Vote Conversion Tuning** | **Vote carry-through settled; balance pass open** | `sim/mind_meeting.gd`, `sim/evil.gd`, `sim/tuning.gd`, `TUNING_NARRATIVE.md` | **Settled (Nov 8, Michael):** NPCs carrying agreement through to their votes, and evil's voting strategy, are in a good place; those backlog items moved to BACKLOG_COMPLETED. Balance target (DESIGN.md): a skilled player wins 70–75% and names the Demon in 85–90%. The bot wins about 53% at 10 NPCs and 57% at 7. Open: the 7-NPC bot drop since Nov 6, the 10-NPC passive drop, a re-sweep of main after #99/#100, the oracle sweep, Tally's Night Watch and Medium bluff checks, and the decided levers in BACKLOG (night sightings too decisive, evil sometimes truthful, evil meeting frequency, vigil strength, trace weight). |
| **10** | **Roguelike Randomization & Storyteller** | **Tier 2 started** | `sim/script_builder.gd`, `ui/new_case_screen.gd`, `role_exploration.md` | Tier 1 (traits, occupations, roles) and Tier 2's scripts and dynamic random scripts are live. Not built: a Storyteller/director that picks plausible poisoned and Delusional readings (instead of inverting them), curated Medium visits, and the setup solvability check. Tier 3 (procedural towns) is **deferred** (Nov 8). |
| **11** | **Progression & Meta-Game** | **Early concept** | `DESIGN.md`, `BACKLOG.md` (section 4) | Toolbox unlocks (Autopsy, Séance, Scry, Binding Circle), demon breeds with a bestiary and true-name exorcism wins, outcome scoring. |
| **12** | **Solver Latency, Legacy Cutover & Bot Tooling** | **Cutover done; latency ongoing** | `workshop/`, `workshop/cs/`, `tools/autoplay.gd`, `tools/analyst.gd` | Legacy belief code is gone; the solver kernel runs in C#. Nov 7: step 3's graded challenges cut from 71 s to ~20 s per passive 10-NPC game (#99, #100). Open: the bot doesn't search for drops or totems, or offer wards and vigils; re-measure late-game meeting cost. |
| **13** | **Movement & Routing Rework** | **Tabled** | `sim/content.gd`, `workshop/movement_model.gd`, `workshop/live_activity.gd` | Destination-only vigils are live. Passing-through vs stopping and live Demon detours stay parked. |
| **14** | **Premises Pass (cases and challenges)** | **Steps 0–3 done; step 4 deferred** | `workshop/shared_ledger.gd`, `workshop/reasoner.gd`, `workshop/jury.gd`, `workshop/case_eval.gd`, `workshop/reading_challenges.gd`, `docs/premises_plan.md` | Steps 0, 0b, 1, 2 and 3 are on main (PRs #81, #86, #92, #93, #95), with step 3's speed fixes (#99, #100) and its A/B (Project `claude/premises-ab-2026-11-07.md`). Step 4 (Scion/Revenant and movement premises) is **deferred** (Nov 8). Recency ("the topic of the day", card age, recall on presentation) and the headline-blend fix are built on PR #96 (refreshed onto main Nov 8); its own A/B is next. |
| **15** | **Learning Resources: Tooltips, In-Game Wiki & Tutorial** | **Not started** (restored from v8, Nov 8) | `ui/text_terms.gd`, `ui/formatted_text_label.gd`, a wiki window (new), a tutorial controller (new), one shared term registry | (1) A tooltip and term spine: `text_terms.gd` extended from roles and people to the mechanics (Marked, Delusional, On the Block, Vigil, Ward, Clemency, Traces, Circumstantial, traits, night order) plus UI control tooltips. (2) A searchable, hyperlinked in-game wiki / field manual replacing the plain Help text, opened from terms in the log, speech and cards. (3) A guided tutorial: a curated 7-NPC case with light coach marks. (1) and (2) are UI and data only and can go any time; build (3) once meetings and premises settle. |
| **16** | **Presentation: Art & Audio** | **In progress** (new, Nov 8) | `assets/art/`, `ui/map_view.gd`, `ui/soundtrack.gd`, `assets/audio/` | Live: the bespoke papercraft town map, buildings, per-NPC cottages and building interiors (PR #103); a background soundtrack (PR #102). Open: the portrait restyle (Michael, in ChatGPT); sound effects (shortlist in the Project artifacts); an options menu with a music volume control; interiors for homes and crime scenes if wanted. |
| **17** | **Simulation Depth** *(stretch)* | **Stretch concept** | `sim/evil.gd`, `sim/social.gd`, `sim/mind_dialogue.gd`, `BACKLOG.md` | From v8: evil backing into bluffs and double claims (Michael, Nov 7: likely messy and expensive), good NPCs lying tactically, smarter scapegoating (bussing a Revenant with a live totem, evil Martyr and Warden bluffs, deliberate Scion succession), rare NPC mini-cases at the trial (1–2 a game), and 12–13 NPC towns. |

## 1a. Next (Nov 8)

- **Who does what:** Claude-Bailiff runs checks, tests and Git and does UI and presentation work. Claude-Tally runs sweeps, A/Bs, balance checks and playtest analysis. Claude-Quill drafts plans and docs and built the premises pass. Argon (Gemini) sends role patches through Drive. Every agent signs `docs/handoff_log.md`.
- **Suggested order:**
  1. **Balance (zone 9):** the re-sweep of main, the 7-NPC bot drop and the 10-NPC passive drop, then the oracle sweep and bluff checks, then the decided levers one at a time.
  2. **Premises recency** ("the topic of the day", zone 14): built on PR #96; its own A/B against main.
  3. **Case board visuals** (zone 5), then text steps 4–5; **tooltips and the wiki** (zone 15, layers 1–2) fit alongside, since all of it is UI and data.
  4. **Roles** (zone 3) once balance is steadier; each needs a hint package and solver support.
- **Baseline rule:** one behaviour change lands at a time, each with its own golden baseline. UI-only and docs-only changes must match the current baseline (`baseline_9a09894` once PR #96 lands; `baseline_7034f36` before) at `--tol 0`.

## 1b. Deferred (Michael, Nov 8)

Off the active list until Michael brings them back:
- premises step 4 (Scion/Revenant and movement premises);
- contradiction callouts and poses on the courtroom stage;
- the live seat-by-seat player vote (meeting plan stretch A);
- procedural towns (zone 10, tier 3).

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
