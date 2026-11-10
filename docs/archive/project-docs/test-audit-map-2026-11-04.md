# Test audit (2026-11-04)

Branch `claude/test-audit`. Tools:
- `python3 tools/run_gd_tests.py … --timings out.json` records seconds per suite.
- `python3 tools/test_map.py --timings … --md out.md` builds the static map below.

## Result: full run 84 min → 21 min

Both runs used two suites side by side on one machine.

| | Before | After |
|---|---|---|
| Full run | 84 min (122 suites) | 21 min (123 suites) |
| PR fast list | 5.1 min | 3.8 min |
| `main` suites | 54 min | 17.5 min |
| Slow tier | `test_trace`, 25 min+ | none |

What changed:
- **`test_trace` retired.** The trace tool is parked, and the suite is still in git history.
- **Legacy Purge suites retired** (~30 min → under 2 min):
  - The checks that old code is gone, and the slow whole-game replays, were dropped. The golden captures cover the replays: fixed seeds every PR, fallbacks recorded.
  - Phase 3's quick 4-seed smoke run stays, now also checking that the outside layer stays flat and that refreshes draw no RNG.
  - The live checks moved into three new suites:
    - `test_shared_model`: ledger receipts and ownership, source doubt, Seer clearing, impossible Gravedigger reports, recovering from a failed refresh, the smoke run.
    - `test_execution_aftermath`: Gravedigger rapport, the Revenant's curse, grief resentments, a freed soul's restoration.
    - `test_workshop_vote_and_alibi`: vote shielding, Night Watch vs alibi.
  - `phase2a` became `test_meeting_reasons`; its passive check plays two 7-person games instead of four mixed-size ones. `test_legacy_migration` became `test_presentation_contracts`.
- **Slow sweeps trimmed, every check kept:**

  | Suite | Before | After | Change |
  |---|---|---|---|
  | `test_workshop_profile_traces` | 251 s | 25 s | 36 seeds instead of 200 |
  | `test_fixes` | 210 s | 52 s | 7-person towns, fewer seeds |
  | `test_shadow` | 273 s | 28 s | 7-person towns to day 3, one 10-person to day 2 |
  | `test_meeting_stream` | ~270 s | 57 s | two 7-person towns |

  `test_meeting_stream`'s 10-person seed alone had taken ~250 s.

## Still failing (same on `main` at fdf4760, not caused by the audit)

- `test_playtest_regressions`: "Evil._fake_dead_reading safely returns {} for roles without custom fabricated Medium relays".
- `test_phase4_3_framing_and_vigil_physics`: "case_against cites Hollis's private Gravedigger reading whenever the shared model suspects Odette". It now cites a Surveyor reading instead.

## Next candidates

- The slowest suites now:

  | Suite | Time |
  |---|---|
  | `test_backlog_batch3` | 80 s |
  | `test_trace_solver` | 60 s |
  | `test_roster` | 58 s |
  | `test_meeting_stream` | 57 s |
  | `test_fixes` | 52 s |
  | `test_shared_model` | 52 s |
  | `test_npc_interactions` | 51 s |

  The same treatment (7-person towns, fewer seeds) would likely halve these.
- 25 date-named suites remain (backlog batches, phase4_*, playtest_*, claude_*, csharp_slice_*). Sorting their checks into feature suites is the tidy-up step; it saves little time.
- The duplicated solver-channel pairs (`channel_likelihood` / `factored_channels`, `channel_classes` / `factored_classes`).

## Suite map (after)

123 suites · 3467 checks · 26538 lines · 21 min measured

## Every suite

| Suite | Tier | Time (s) | Checks | Lines | Areas | Exact text | Absence | Dup checks | Cases | Nearest overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| test_backlog_batch3 ⌚ | main | 80 | 81 | 515 | game, sim, ui | 13 | 0 | 0 | 2 | test_sighting_followup 0.18, test_backlog_batch4 0.18 |
| test_trace_solver | main | 60 | 28 | 293 | game, sim, ui, workshop | 1 | 0 | 0 | 8 | test_workshop_two_traces 0.40, test_workshop_profile_traces 0.33 |
| test_roster | main | 58 | 37 | 490 | game, sim | 0 | 0 | 0 | 20 | test_role_def_poc 0.15, test_lamplighter_drops 0.10 |
| test_meeting_stream | main | 57 | 5 | 64 | game | 2 | 0 | 0 | 1 | test_prior_mapping 0.29, test_tuning_hoist 0.15 |
| test_fixes ⌚ | main | 52 | 84 | 678 | game, sim, ui | 9 | 1 | 0 | 23 | test_playtest_regressions 0.18, test_sighting_followup 0.16 |
| test_shared_model | pr | 52 | 31 | 407 | game, sim, workshop | 0 | 1 | 0 | 8 | test_workshop_tuning_probe 0.27, test_phase4_3_framing_and_vigil_physics 0.27 |
| test_npc_interactions | main | 51 | 50 | 366 | game, sim | 0 | 0 | 0 | 12 | test_fixes 0.13, test_role_def_poc 0.10 |
| test_decision_inspector | main | 42 | 53 | 333 | game, sim, ui | 2 | 0 | 0 | 4 | test_backlog_batch2 0.15, test_backlog_batch3 0.09 |
| test_backlog_batch4 ⌚ | main | 33 | 161 | 1042 | game, sim, ui | 24 | 2 | 0 | 5 | test_backlog_batch3 0.18, test_fixes 0.16 |
| test_meeting_reasons | main | 30 | 15 | 377 | game, sim, workshop | 0 | 0 | 0 | 9 | test_workshop_vote_and_alibi 0.23, test_workshop_presentation 0.23 |
| test_workshop_integration | pr | 28 | 37 | 205 | game, sim, workshop | 0 | 0 | 0 | 8 | test_workshop_reading_identity 0.24, test_mechanics_conclusions 0.20 |
| test_playtest_regressions ⌚ ✕ | main | 28 | 37 | 337 | game, sim, workshop | 0 | 0 | 0 | 16 | test_fixes 0.18, test_sighting_followup 0.14 |
| test_shadow | main | 28 | 31 | 219 | game, sim | 0 | 0 | 0 | 5 | test_execution_aftermath 0.25, test_tuning_hoist 0.17 |
| test_chunk3_executor_registrar | pr | 25 | 32 | 481 | game, sim, workshop | 0 | 0 | 8 | 7 | test_chunk2_world_mask_roles 0.37, test_workshop_factored_channels 0.21 |
| test_workshop_profile_traces | main | 25 | 17 | 248 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_two_traces 0.54, test_trace_solver 0.33 |
| test_workshop_live_canvas | main | 24 | 77 | 339 | game, sim, ui, workshop | 5 | 1 | 0 | 4 | test_workshop_reading_challenges 0.26, test_presentation_contracts 0.23 |
| test_case_script | pr | 19 | 22 | 116 | game, sim | 0 | 0 | 0 | 1 | test_chunk3_executor_registrar 0.12 |
| test_dialogue_decisions | main | 19 | 20 | 93 | game, sim | 1 | 1 | 0 | 2 | test_phase4_2_balanced_execution_priority 0.18, test_presentation_contracts 0.17 |
| test_workshop_factored_classes | main | 16 | 5 | 69 | workshop | 0 | 0 | 4 | 0 | test_workshop_channel_classes 0.83, test_workshop_factored_channels 0.38 |
| test_workshop_channel_classes | main | 15 | 5 | 68 | workshop | 0 | 0 | 4 | 0 | test_workshop_factored_classes 0.83, test_workshop_channel_likelihood 0.29 |
| test_phase4_2_balanced_execution_priority ⌚ | main | 14 | 12 | 299 | game, sim, workshop | 0 | 0 | 0 | 5 | test_workshop_action 0.29, test_phase4_3_framing_and_vigil_physics 0.23 |
| test_ui | main | 14 | 113 | 630 | game, sim, ui | 10 | 1 | 0 | 2 | test_backlog_batch4 0.15, test_day_conversation_view 0.15 |
| test_playtest_followups ⌚ | main | 14 | 49 | 350 | game, sim, ui | 4 | 0 | 0 | 1 | test_decision_inspector 0.07, test_workshop_tuning_probe 0.07 |
| test_workshop_two_traces | main | 13 | 9 | 173 | game, sim, workshop | 0 | 0 | 0 | 4 | test_workshop_profile_traces 0.54, test_trace_solver 0.40 |
| test_workshop_tuning_probe | main | 12 | 35 | 379 | game, sim, workshop | 0 | 1 | 0 | 9 | test_phase4_3_framing_and_vigil_physics 0.30, test_shared_model 0.27 |
| test_workshop_remaining ⌚ | main | 11 | 60 | 328 | sim, ui, workshop | 0 | 1 | 0 | 0 | test_workshop_consequences 0.37, test_workshop_canvas 0.30 |
| test_workshop_reading_challenges | pr | 11 | 41 | 220 | game, ui, workshop | 0 | 0 | 0 | 4 | test_workshop_martyr_sexton 0.53, test_workshop_lamplighter 0.43 |
| test_phase2_bug_sweep ⌚ | main | 10 | 30 | 321 | game, sim, workshop | 3 | 0 | 0 | 7 | test_claude_audit_cleanup 0.17, test_workshop_tuning_probe 0.15 |
| test_social | main | 10 | 30 | 346 | game, sim | 3 | 0 | 0 | 16 | test_dialogue_batches_5_6_7 0.15, test_fixes 0.12 |
| test_phase4_3_framing_and_vigil_physics ⌚ ✕ | main | 10 | 23 | 441 | game, sim, workshop | 0 | 0 | 0 | 5 | test_workshop_tuning_probe 0.30, test_workshop_vote_and_alibi 0.29 |
| test_dialogue | main | 10 | 133 | 664 | game, sim, ui | 35 | 0 | 0 | 2 | test_playtest_regressions 0.12, test_dialogue_batches_5_6_7 0.11 |
| test_workshop_vote_and_alibi | pr | 10 | 11 | 194 | game, sim, workshop | 0 | 0 | 0 | 4 | test_presentation_contracts 0.30, test_phase4_3_framing_and_vigil_physics 0.29 |
| test_tuning_hoist | main | 10 | 12 | 195 | game, sim, workshop | 0 | 0 | 0 | 2 | test_prior_mapping 0.19, test_shadow 0.17 |
| test_workshop_ui | main | 10 | 25 | 133 | ui | 0 | 0 | 0 | 0 | test_workshop_consequences 0.18, test_workshop_canvas 0.17 |
| test_day_conversation_view | main | 10 | 59 | 181 | sim, ui | 6 | 1 | 0 | 0 | test_ui 0.15, test_prior_mapping 0.09 |
| test_defence_repeats | main | 10 | 14 | 167 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_provenance 0.33, test_workshop_reading_identity 0.29 |
| test_buildings_tavern_town_hall | pr | 10 | 34 | 366 | game, sim, ui, workshop | 0 | 2 | 0 | 4 | test_chunk2_world_mask_roles 0.24, test_workshop_card_adapters 0.18 |
| test_prior_mapping | main | 9 | 5 | 99 | game, sim, workshop | 0 | 0 | 0 | 2 | test_warden_credit 0.33, test_meeting_stream 0.29 |
| test_mechanics_conclusions | main | 9 | 17 | 115 | game, ui, workshop | 0 | 0 | 0 | 1 | test_workshop_card_adapters 0.27, test_workshop_votes 0.23 |
| test_execution_aftermath | pr | 9 | 24 | 275 | game, sim | 2 | 0 | 0 | 6 | test_shadow 0.25, test_workshop_ownership 0.24 |
| test_dialogue_batches_5_6_7 ⌚ | main | 8 | 50 | 542 | game, sim, ui | 21 | 0 | 0 | 10 | test_social 0.15, test_backlog_batch3 0.14 |
| test_backlog_batch2 ⌚ | main | 8 | 39 | 278 | game, sim | 7 | 0 | 0 | 2 | test_decision_inspector 0.15, test_backlog_batch3 0.15 |
| test_claude_batch ⌚ | main | 7 | 37 | 281 | game, sim, workshop | 5 | 1 | 0 | 11 | test_workshop_vote_and_alibi 0.19, test_workshop_two_traces 0.18 |
| test_presentation_contracts | main | 7 | 24 | 168 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_vote_and_alibi 0.30, test_workshop_slice5_voices_and_bot 0.27 |
| test_phase4_1_reveal_and_rumor_pacing ⌚ | main | 7 | 22 | 387 | game, sim | 0 | 1 | 0 | 5 | test_phase4_2_balanced_execution_priority 0.17, test_phase4_3_framing_and_vigil_physics 0.15 |
| test_phase3_credibility_and_trust ⌚ | main | 7 | 17 | 294 | game, sim, workshop | 0 | 0 | 0 | 3 | test_workshop_live_cognition 0.25, test_workshop_reading_identity 0.22 |
| test_headline | pr | 6 | 7 | 79 | game, workshop | 0 | 0 | 0 | 1 | test_warden_credit 0.57, test_prior_mapping 0.27 |
| test_sighting_followup ⌚ | main | 6 | 32 | 174 | game, sim | 1 | 0 | 0 | 7 | test_backlog_batch3 0.18, test_fixes 0.16 |
| test_workshop_presentation | main | 6 | 73 | 385 | game, sim, workshop | 0 | 0 | 0 | 10 | test_workshop_nested_cases 0.25, test_presentation_contracts 0.25 |
| test_text_ui | main | 6 | 20 | 138 | sim, ui | 5 | 0 | 0 | 0 | test_town_ui 0.33, test_evidence_context 0.08 |
| test_workshop_consequences | main | 6 | 42 | 220 | ui, workshop | 1 | 0 | 0 | 0 | test_workshop_remaining 0.37, test_workshop_reasoning 0.33 |
| test_claude_audit_cleanup ⌚ | main | 6 | 15 | 254 | game, sim, workshop | 0 | 0 | 0 | 5 | test_warden_credit 0.20, test_beliefs 0.17 |
| test_town_ui | main | 6 | 34 | 145 | sim, ui | 0 | 0 | 0 | 0 | test_text_ui 0.33, test_evidence_context 0.07 |
| test_workshop_live_ui | main | 6 | 11 | 91 | game, ui | 5 | 0 | 0 | 1 | test_workshop_attention 0.15, test_workshop_hints 0.12 |
| test_workshop_efficiency | pr | 5 | 15 | 158 | workshop | 0 | 0 | 0 | 0 | test_workshop_reasoning 0.21, test_workshop 0.20 |
| test_workshop_circumstantial_hub | main | 5 | 30 | 429 | game, sim, ui, workshop | 1 | 0 | 0 | 10 | test_workshop_slice5_voices_and_bot 0.43, test_workshop_reading_challenges 0.30 |
| test_warden_credit | main | 5 | 9 | 79 | game, sim, workshop | 1 | 0 | 0 | 4 | test_headline 0.57, test_prior_mapping 0.33 |
| test_workshop_live | main | 5 | 23 | 107 | game, sim, workshop | 1 | 0 | 0 | 1 | test_mechanics_warden 0.30, test_workshop_attention 0.25 |
| test_outcomes | main | 5 | 23 | 109 | game | 0 | 0 | 0 | 2 | test_dialogue_decisions 0.12, test_phase2_bug_sweep 0.11 |
| test_workshop_reading_identity | main | 5 | 14 | 97 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_provenance 0.38, test_workshop_psychologist 0.36 |
| test_beliefs | pr | 5 | 14 | 287 | game, sim | 0 | 0 | 0 | 1 | test_execution_aftermath 0.23, test_defence_repeats 0.21 |
| test_social_trust | main | 5 | 15 | 98 | game, sim | 0 | 0 | 0 | 4 | test_phase3_credibility_and_trust 0.17, test_warden_credit 0.07 |
| test_workshop_clerk_archivist_seer | pr | 5 | 41 | 216 | game, ui, workshop | 0 | 0 | 0 | 3 | test_workshop_protection 0.45, test_workshop_medium 0.45 |
| test_workshop_profile_receipts | main | 5 | 23 | 163 | game, sim, ui, workshop | 0 | 0 | 0 | 8 | test_workshop_reading_challenges 0.25, test_trace_solver 0.25 |
| test_mechanics_curse | pr | 5 | 16 | 120 | game, sim, workshop | 0 | 0 | 0 | 1 | test_mechanics_defences 0.21, test_mechanics_relays 0.16 |
| test_board | main | 4 | 40 | 248 | game, sim, ui | 0 | 1 | 0 | 12 | test_sighting_followup 0.14, test_fixes 0.09 |
| test_mechanics_defences | main | 4 | 7 | 89 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_public_evidence 0.29, test_workshop_refusals 0.27 |
| test_workshop_canvas | main | 4 | 48 | 225 | ui, workshop | 1 | 0 | 0 | 0 | test_workshop_remaining 0.30, test_workshop_consequences 0.30 |
| test_workshop_live_cognition | main | 4 | 34 | 213 | game, sim, workshop | 2 | 1 | 1 | 8 | test_workshop_ownership 0.38, test_workshop_reading_identity 0.28 |
| test_workshop_votes | main | 4 | 10 | 79 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_hints 0.31, test_workshop_card_adapters 0.29 |
| test_workshop_ownership | pr | 4 | 48 | 263 | game, sim, workshop | 0 | 0 | 0 | 2 | test_workshop_live_cognition 0.38, test_workshop_reading_identity 0.27 |
| test_workshop_psychologist | main | 4 | 9 | 83 | game, sim, workshop | 0 | 1 | 0 | 1 | test_workshop_secrets 0.46, test_workshop_hints 0.42 |
| test_workshop_slice5_voices_and_bot ⌚ | main | 4 | 19 | 233 | game, sim, workshop | 3 | 0 | 0 | 5 | test_workshop_circumstantial_hub 0.43, test_workshop_profile_traces 0.31 |
| test_workshop_refusals | main | 4 | 16 | 114 | game, sim, workshop | 2 | 0 | 0 | 1 | test_workshop_hints 0.73, test_workshop_psychologist 0.33 |
| test_mechanics_sharing | main | 4 | 14 | 81 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_provenance 0.23, test_workshop_reading_identity 0.20 |
| test_workshop_public_evidence | main | 4 | 41 | 226 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_card_adapters 0.32, test_workshop_refusals 0.30 |
| test_evidence_context | main | 4 | 13 | 96 | game, sim, ui, workshop | 2 | 0 | 0 | 1 | test_text_ui 0.08, test_town_ui 0.07 |
| test_mechanics_warden | main | 4 | 10 | 52 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_live 0.30, test_workshop_hints 0.23 |
| test_workshop_card_adapters | main | 4 | 30 | 211 | game, sim, workshop | 0 | 1 | 0 | 9 | test_workshop_public_evidence 0.32, test_workshop_refusals 0.32 |
| test_workshop_hints | main | 4 | 13 | 95 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_refusals 0.73, test_workshop_psychologist 0.42 |
| test_workshop_provenance | main | 4 | 21 | 113 | game, sim, workshop | 1 | 0 | 0 | 1 | test_workshop_reading_identity 0.38, test_defence_repeats 0.33 |
| test_workshop_reasoning | main | 4 | 44 | 257 | workshop | 1 | 0 | 1 | 0 | test_workshop 0.62, test_workshop_cases 0.45 |
| test_mechanics_relays | main | 4 | 9 | 60 | game, sim, workshop | 0 | 1 | 0 | 1 | test_workshop_provenance 0.23, test_mechanics_defences 0.23 |
| test_peer_role_gossip | pr | 4 | 23 | 232 | game, sim | 0 | 3 | 0 | 8 | test_phase4_1_reveal_and_rumor_pacing 0.15, test_mechanics_sharing 0.08 |
| test_workshop_action | main | 4 | 16 | 115 | game, sim, workshop | 1 | 0 | 0 | 2 | test_phase4_2_balanced_execution_priority 0.29, test_defence_repeats 0.23 |
| test_workshop_martyr_sexton | pr | 4 | 26 | 116 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_lamplighter 0.69, test_workshop_medium 0.60 |
| test_workshop_secrets | main | 4 | 17 | 138 | game, ui, workshop | 0 | 0 | 0 | 1 | test_workshop_nested_cases 0.53, test_workshop_psychologist 0.46 |
| test_dialogue_opinion_pass | main | 4 | 30 | 131 | game, sim | 7 | 0 | 0 | 1 | test_dialogue 0.11, test_dialogue_batches_5_6_7 0.10 |
| test_mechanics_sightings | main | 4 | 8 | 70 | game, sim, workshop | 0 | 0 | 0 | 1 | test_defence_repeats 0.23, test_workshop_psychologist 0.21 |
| test_social_phase2 ⌚ | main | 4 | 11 | 67 | game, sim, workshop | 0 | 0 | 0 | 1 | test_execution_aftermath 0.04 |
| test_chunk2_world_mask_roles | pr | 3 | 35 | 522 | game, sim, workshop | 0 | 0 | 8 | 6 | test_chunk3_executor_registrar 0.37, test_buildings_tavern_town_hall 0.24 |
| test_lamplighter_drops | main | 3 | 5 | 48 | game, sim | 0 | 0 | 0 | 1 | test_roster 0.10, test_buildings_tavern_town_hall 0.03 |
| test_nomination_and_evil_tuning | main | 3 | 18 | 159 | game, sim | 0 | 0 | 0 | 5 | test_workshop_action 0.20, test_phase4_3_framing_and_vigil_physics 0.15 |
| test_workshop | main | 3 | 40 | 176 | workshop | 0 | 1 | 0 | 0 | test_workshop_reasoning 0.62, test_workshop_cases 0.55 |
| test_workshop_cases | main | 3 | 39 | 201 | workshop | 0 | 0 | 0 | 0 | test_workshop 0.55, test_workshop_reasoning 0.45 |
| test_workshop_medium | pr | 3 | 25 | 138 | game, workshop | 0 | 1 | 0 | 1 | test_workshop_martyr_sexton 0.60, test_workshop_nightwatch_gravedigger 0.50 |
| test_workshop_nightwatch_gravedigger | pr | 3 | 30 | 121 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_medium 0.50, test_workshop_martyr_sexton 0.50 |
| test_workshop_protection | pr | 3 | 23 | 130 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_martyr_sexton 0.50, test_workshop_live_activity 0.50 |
| test_mechanics_claims | main | 3 | 11 | 60 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_reading_identity 0.25, test_mechanics_sharing 0.20 |
| test_role_def_poc ⌚ | pr | 3 | 110 | 442 | game, sim, workshop | 5 | 0 | 0 | 6 | test_roster 0.15, test_chunk2_world_mask_roles 0.12 |
| test_workshop_lamplighter | main | 3 | 19 | 89 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_martyr_sexton 0.69, test_workshop_live_activity 0.65 |
| test_workshop_live_activity | main | 3 | 29 | 143 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_lamplighter 0.65, test_workshop_protection 0.50 |
| test_workshop_nested_cases | main | 3 | 17 | 115 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_secrets 0.53, test_workshop_martyr_sexton 0.47 |
| test_workshop_attention | main | 3 | 13 | 76 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_hints 0.30, test_workshop_live 0.25 |
| test_workshop_checkpoint | main | 3 | 0 | 96 | workshop | 0 | 0 | 0 | 0 | test_workshop 0.33, test_workshop_consequences 0.25 |
| test_csharp_slice_c1 ⌚ | pr | 3 | 18 | 292 | game, sim, workshop | 0 | 0 | 0 | 1 | test_csharp_slice_c2 0.33, test_workshop_efficiency 0.13 |
| test_csharp_slice_c2 ⌚ | pr | 3 | 16 | 392 | game, sim, workshop | 0 | 0 | 0 | 1 | test_csharp_slice_c1 0.33, test_csharp_slice_c3 0.13 |
| test_csharp_slice_c3 ⌚ | pr | 3 | 20 | 455 | game, sim, workshop | 0 | 0 | 0 | 1 | test_case_eval 0.27, test_workshop_factored_classes 0.26 |
| test_social_evidence_boundary | main | 3 | 20 | 112 | game, sim | 0 | 0 | 0 | 2 | test_workshop_action 0.21, test_phase4_2_balanced_execution_priority 0.19 |
| test_workshop_profiling | main | 3 | 17 | 108 | workshop | 0 | 0 | 0 | 0 | test_workshop_efficiency 0.17, test_workshop_cases 0.16 |
| test_workshop_factored_channels | main | 2 | 21 | 154 | workshop | 0 | 0 | 18 | 0 | test_workshop_channel_likelihood 0.80, test_workshop_factored_classes 0.38 |
| test_trace_art | main | 2 | 6 | 40 | sim, ui | 1 | 0 | 0 | 0 |  |
| test_case_eval | main | 1 | 15 | 138 | workshop | 0 | 0 | 0 | 0 | test_csharp_slice_c3 0.27, test_workshop_factor_cache 0.25 |
| test_dialogue_vn_preview | main | 1 | 27 | 70 | ui | 2 | 0 | 0 | 0 |  |
| test_workshop_channel_likelihood | main | 1 | 19 | 118 | workshop | 0 | 0 | 18 | 0 | test_workshop_factored_channels 0.80, test_workshop_channel_classes 0.29 |
| test_workshop_surveyor_answers | main | 1 | 9 | 53 | workshop | 0 | 0 | 0 | 0 | test_case_eval 0.23, test_workshop_factor_cache 0.22 |
| test_workshop_card_answers | main | 1 | 13 | 77 | workshop | 0 | 3 | 0 | 0 | test_mechanics_relays 0.20, test_workshop_channel_likelihood 0.14 |
| test_workshop_factor_cache | main | 1 | 0 | 34 | workshop | 0 | 0 | 0 | 0 | test_workshop_channel_classes 0.25, test_case_eval 0.25 |
| test_workshop_channels | main | 1 | 20 | 102 | workshop | 0 | 0 | 0 | 0 | test_workshop_channel_likelihood 0.14, test_workshop_factored_channels 0.12 |
| test_text_formatter | main | 0 | 30 | 111 | sim, ui | 1 | 0 | 0 | 0 | test_text_terms 0.33, test_playtest_followups 0.03 |
| test_text_terms | main | 0 | 28 | 60 | sim, ui | 1 | 0 | 0 | 0 | test_text_formatter 0.33, test_playtest_followups 0.04 |
| test_channel_sum_product | main | 0 | 7 | 35 | workshop | 0 | 0 | 0 | 0 | test_csharp_slice_c3 0.22 |
| test_csharp_slice_c0 ⌚ | pr | 0 | 0 | 149 | sim | 0 | 0 | 0 | 0 |  |

⌚ named after when it was written (batch, phase, slice, playtest…) rather than what it tests. ✕ failed in the timing run.

## Most-overlapping pairs

Jaccard similarity of the game functions, methods and commands the two suites call (ignoring ones most suites call).

| Similarity | Suite A | Suite B | Shared |
|---|---|---|---|
| 0.83 | test_workshop_channel_classes | test_workshop_factored_classes | 5 |
| 0.80 | test_workshop_channel_likelihood | test_workshop_factored_channels | 4 |
| 0.73 | test_workshop_hints | test_workshop_refusals | 8 |
| 0.69 | test_workshop_lamplighter | test_workshop_martyr_sexton | 9 |
| 0.65 | test_workshop_lamplighter | test_workshop_live_activity | 11 |
| 0.62 | test_workshop | test_workshop_reasoning | 5 |
| 0.60 | test_workshop_martyr_sexton | test_workshop_medium | 9 |
| 0.57 | test_headline | test_warden_credit | 4 |
| 0.55 | test_workshop | test_workshop_cases | 6 |
| 0.54 | test_workshop_profile_traces | test_workshop_two_traces | 13 |
| 0.53 | test_workshop_nested_cases | test_workshop_secrets | 8 |
| 0.53 | test_workshop_martyr_sexton | test_workshop_reading_challenges | 9 |
| 0.50 | test_workshop_medium | test_workshop_nightwatch_gravedigger | 11 |
| 0.50 | test_workshop_martyr_sexton | test_workshop_protection | 8 |
| 0.50 | test_workshop_martyr_sexton | test_workshop_nightwatch_gravedigger | 9 |
| 0.50 | test_workshop_live_activity | test_workshop_protection | 10 |
| 0.50 | test_workshop_live_activity | test_workshop_martyr_sexton | 8 |
| 0.47 | test_workshop_martyr_sexton | test_workshop_nested_cases | 7 |
| 0.47 | test_workshop_lamplighter | test_workshop_protection | 9 |
| 0.47 | test_workshop_lamplighter | test_workshop_medium | 9 |
| 0.46 | test_workshop_psychologist | test_workshop_secrets | 6 |
| 0.45 | test_workshop_clerk_archivist_seer | test_workshop_protection | 10 |
| 0.45 | test_workshop_clerk_archivist_seer | test_workshop_medium | 10 |
| 0.45 | test_workshop_clerk_archivist_seer | test_workshop_live_activity | 10 |
| 0.45 | test_workshop_cases | test_workshop_reasoning | 5 |
| 0.44 | test_workshop_lamplighter | test_workshop_secrets | 7 |
| 0.44 | test_workshop_lamplighter | test_workshop_nested_cases | 8 |
| 0.44 | test_workshop_clerk_archivist_seer | test_workshop_martyr_sexton | 8 |
| 0.43 | test_workshop_medium | test_workshop_protection | 9 |
| 0.43 | test_workshop_live_activity | test_workshop_nightwatch_gravedigger | 10 |
| 0.43 | test_workshop_live_activity | test_workshop_medium | 9 |
| 0.43 | test_workshop_lamplighter | test_workshop_reading_challenges | 9 |
| 0.43 | test_workshop_clerk_archivist_seer | test_workshop_lamplighter | 9 |
| 0.43 | test_workshop_circumstantial_hub | test_workshop_slice5_voices_and_bot | 10 |
| 0.42 | test_workshop_hints | test_workshop_psychologist | 5 |
| 0.41 | test_workshop_lamplighter | test_workshop_nightwatch_gravedigger | 9 |
| 0.40 | test_workshop_clerk_archivist_seer | test_workshop_nightwatch_gravedigger | 10 |
| 0.40 | test_trace_solver | test_workshop_two_traces | 10 |
| 0.39 | test_workshop_protection | test_workshop_reading_challenges | 9 |
| 0.39 | test_workshop_medium | test_workshop_reading_challenges | 9 |

## Near-duplicate checks across suites

Check messages that say nearly the same thing (70%+ word overlap): the likeliest real redundancy.

| Suite A | Suite B | Near-duplicates | Example |
|---|---|---|---|
| test_workshop_channel_likelihood | test_workshop_factored_channels | 18 | “eliminating irrelevant channels matches full enumeration for every wor” / “eliminating irrelevant channels matches full enumeration for every wor” |
| test_chunk2_world_mask_roles | test_chunk3_executor_registrar | 8 | “Zero GDScript vs C# VERIFY mismatches across Surveyor tests” / “Zero GDScript vs C# VERIFY mismatches across Executor tests” |
| test_workshop_channel_classes | test_workshop_factored_classes | 4 | “class representatives and eliminated channels preserve every world's p” / “class representatives and eliminated channels preserve every world's p” |
| test_workshop_live_cognition | test_workshop_reasoning | 1 | “decisive contrary evidence can dislodge the live high-confidence theor” / “strong contrary evidence can dislodge the high-confidence theory” |

## Game modules by number of suites that preload them

| Module | Suites |
|---|---|
| game/game.gd | 94 |
| sim/mind.gd | 63 |
| sim/content.gd | 59 |
| workshop/solver.gd | 49 |
| game/workshop_canvas.gd | 36 |
| workshop/canvas_model.gd | 34 |
| sim/tuning.gd | 30 |
| workshop/case_eval.gd | 26 |
| workshop/shared_ledger.gd | 25 |
| workshop/ghost_juror.gd | 22 |
| sim/social.gd | 17 |
| workshop/live_assessment.gd | 17 |
| workshop/jury.gd | 17 |
| sim/evil.gd | 15 |
| workshop/session.gd | 12 |
| workshop/live_activity.gd | 12 |
| ui/main.tscn | 10 |
| workshop/caches.gd | 10 |
| game/workshop_bridge.gd | 10 |
| workshop/channel_likelihood.gd | 8 |
| ui/theme.gd | 7 |
| ui/live_case_workshop.gd | 7 |
| workshop/factored_channels.gd | 6 |
| sim/mind_meeting.gd | 6 |
| workshop/evidence_channels.gd | 6 |
| workshop/support_model.gd | 6 |
| workshop/role_constraints.gd | 5 |
| workshop/live_evidence.gd | 5 |
| workshop/reading_challenges.gd | 5 |
| workshop/world_domain.gd | 5 |
| sim/dialogue.gd | 5 |
| workshop/reasoner.gd | 5 |
| game/card_model.gd | 4 |
| workshop/chronology.gd | 4 |
| game/credibility.gd | 4 |
| ui/card_list.gd | 3 |
| workshop/trace_solver.gd | 3 |
| game/workshop_presentation.gd | 3 |
| game/workshop_ownership.gd | 3 |
| sim/world.gd | 3 |
