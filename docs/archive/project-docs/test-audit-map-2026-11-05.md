# Test consolidation (2026-11-05)

Follow-up to the 2026-11-04 audit and the 2026-11-05 maintenance report (section E). PRs #70 (A) and #71 (B), stacked on #69. Every check kept.

## Result

- **128 → 106 suites**, all passing.
- **A: role families.** 20 role suites become 8, grouped by the game's hint packages: `test_roles_official`, `_night_sight`, `_dead`, `_shelter`, `_people`, plus `_evil`, `_secrets` and `_registry`. 1,066 checks.
- **A: solver pairs merged.**
  - `channel_classes` + `factored_classes` → `test_workshop_class_parity`: one exact enumeration per case, both engines checked against it.
  - `channel_likelihood` + `factored_channels` → one spec run on both engines.
- **A: duplicates removed.** The standalone Revenant retraction copy, unused `has_cs` locals and a stale parity label. The VERIFY checks were already gone with the C# cutover.
- **A: sweeps trimmed to what each check needs**, same assertions:
  - roster setups stop once all four secrets have been dealt;
  - fake-Surveyor sampling stops at 30 readings (it used to walk 380 deals every run);
  - `m2b` press-role stops once claim, hint and refusal have all appeared;
  - trace generation uses 20 seeds. The registry checks dropped from 30 s to 9 s.
- **B: date-named suites.** 17 suites become 9 feature suites: `test_conversation_gifts`, `_nights`, `test_dialogue_voices`, `test_meeting_flow`, `test_social_credibility`, `test_evil_play`, `test_evidence_cards`, `test_ui_controls`, `test_workshop_regressions`. 7,311 checks. The `--sweep` manual modes from phase 4 are dropped, since the balance sweep replaced them.
- **Found on the way:** `test_dialogue_batches_5_6_7` was failing on #69, because the voice lines moved to the spoken `{when}` slot and the test still filled `{night}`. Fixed in #69. It wasn't on the PR fast list, so CI missed it.

## Left as they are

- `test_workshop_remaining` (mostly canvas and consequence checks).
- `test_csharp_slice_c0`, whether its remainder should go (the report's "check first").
- The legacy fixture shapes (Psychologist `{subject, trusts, suspects}`, Surveyor `{count}`) and `test_workshop_checkpoint` keeping `Jury.engine = "legacy"`. Both are design calls.
- `test_shared_model`'s multi-day smoke run (16 s, kept on purpose).

## Suite map (after)

106 suites · 3700 checks · 28654 lines · 15 min measured

## Every suite

| Suite | Tier | Time (s) | Checks | Lines | Areas | Exact text | Absence | Dup checks | Cases | Nearest overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| test_workshop_class_parity | main | 64 | 5 | 77 | workshop | 0 | 0 | 0 | 0 | test_workshop_channel_likelihood 0.38, test_workshop_factor_cache 0.22 |
| test_workshop_profile_traces | main | 32 | 17 | 248 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_two_traces 0.54, test_trace_solver 0.33 |
| test_meeting_flow | main | 28 | 88 | 1086 | game, sim, workshop | 6 | 1 | 0 | 23 | test_meeting_reasons 0.20, test_workshop_tuning_probe 0.19 |
| test_shared_model | pr | 24 | 31 | 407 | game, sim, workshop | 0 | 1 | 0 | 8 | test_workshop_tuning_probe 0.27, test_roles_shelter 0.21 |
| test_workshop_profile_receipts | main | 19 | 23 | 163 | game, sim, ui, workshop | 0 | 0 | 0 | 8 | test_workshop_reading_challenges 0.25, test_trace_solver 0.25 |
| test_day_conversation_view | main | 19 | 59 | 181 | sim, ui | 6 | 1 | 0 | 0 | test_ui 0.15, test_prior_mapping 0.09 |
| test_meeting_stream | main | 18 | 5 | 64 | game | 2 | 0 | 0 | 1 | test_prior_mapping 0.29, test_tuning_hoist 0.15 |
| test_conversation_gifts | main | 17 | 86 | 960 | game, sim, ui | 11 | 1 | 0 | 13 | test_dialogue_voices 0.19, test_npc_interactions 0.17 |
| test_npc_interactions | main | 17 | 50 | 366 | game, sim | 0 | 0 | 0 | 12 | test_conversation_gifts 0.17, test_conversation_nights 0.11 |
| test_meeting_m2b | pr | 16 | 29 | 228 | game, sim | 0 | 0 | 0 | 15 | test_conversation_nights 0.24, test_sighting_followup 0.23 |
| test_evil_play | pr | 15 | 63 | 673 | game, sim, workshop | 5 | 0 | 0 | 17 | test_roles_dead 0.15, test_workshop_tuning_probe 0.11 |
| test_case_script | pr | 15 | 40 | 199 | game, sim | 0 | 0 | 0 | 1 | test_roles_secrets 0.06, test_roles_evil 0.06 |
| test_workshop_remaining ⌚ | main | 14 | 60 | 328 | sim, ui, workshop | 0 | 1 | 0 | 0 | test_workshop_consequences 0.37, test_workshop_canvas 0.30 |
| test_workshop_live_canvas | main | 14 | 77 | 339 | game, sim, ui, workshop | 5 | 1 | 0 | 4 | test_workshop_reading_challenges 0.26, test_presentation_contracts 0.23 |
| test_roles_dead | pr | 14 | 90 | 752 | game, sim, workshop | 1 | 1 | 0 | 17 | test_roles_official 0.36, test_roles_night_sight 0.31 |
| test_ui_controls | main | 14 | 112 | 776 | game, sim, ui | 15 | 0 | 0 | 11 | test_ui 0.21, test_town_ui 0.10 |
| test_evidence_cards | main | 13 | 86 | 620 | game, sim, ui, workshop | 4 | 2 | 0 | 17 | test_conversation_gifts 0.15, test_sighting_followup 0.14 |
| test_ui | main | 13 | 113 | 630 | game, sim, ui | 10 | 1 | 0 | 2 | test_ui_controls 0.21, test_day_conversation_view 0.15 |
| test_workshop_integration | pr | 13 | 37 | 205 | game, sim, workshop | 0 | 0 | 0 | 8 | test_workshop_reading_identity 0.24, test_mechanics_conclusions 0.20 |
| test_workshop_provenance | main | 12 | 21 | 113 | game, sim, workshop | 1 | 0 | 0 | 1 | test_workshop_reading_identity 0.38, test_defence_repeats 0.33 |
| test_meeting_reasons | main | 12 | 15 | 377 | game, sim, workshop | 0 | 0 | 0 | 9 | test_workshop_vote_and_alibi 0.23, test_workshop_presentation 0.23 |
| test_workshop_regressions | pr | 12 | 59 | 889 | game, sim, workshop | 5 | 1 | 0 | 24 | test_workshop_vote_and_alibi 0.25, test_roles_shelter 0.21 |
| test_roles_night_sight | pr | 11 | 117 | 686 | game, sim, workshop | 2 | 1 | 0 | 13 | test_workshop_live_activity 0.32, test_roles_dead 0.31 |
| test_roles_people | pr | 11 | 77 | 760 | game, sim, workshop | 1 | 4 | 0 | 15 | test_roles_official 0.33, test_roles_dead 0.29 |
| test_shadow | main | 11 | 31 | 224 | game, sim | 0 | 0 | 0 | 5 | test_execution_aftermath 0.25, test_conversation_nights 0.19 |
| test_roles_registry | pr | 11 | 129 | 703 | game, sim, workshop | 5 | 0 | 0 | 9 | test_roles_evil 0.13, test_roles_official 0.12 |
| test_workshop_ui | main | 11 | 25 | 133 | ui | 0 | 0 | 0 | 0 | test_workshop_consequences 0.18, test_workshop_canvas 0.17 |
| test_decision_inspector | main | 11 | 53 | 333 | game, sim, ui | 2 | 0 | 0 | 4 | test_conversation_nights 0.11, test_social_credibility 0.09 |
| test_workshop_profiling | main | 10 | 17 | 108 | workshop | 0 | 0 | 0 | 0 | test_workshop_efficiency 0.17, test_workshop_cases 0.16 |
| test_trace_solver | main | 10 | 28 | 294 | game, sim, ui, workshop | 1 | 0 | 0 | 8 | test_workshop_two_traces 0.40, test_workshop_profile_traces 0.33 |
| test_dialogue_voices | main | 10 | 82 | 880 | game, sim, ui | 31 | 0 | 0 | 18 | test_conversation_gifts 0.19, test_social 0.15 |
| test_social | main | 9 | 30 | 346 | game, sim | 3 | 0 | 0 | 16 | test_conversation_nights 0.24, test_dialogue_voices 0.15 |
| test_workshop_two_traces | main | 9 | 9 | 173 | game, sim, workshop | 0 | 0 | 0 | 4 | test_workshop_profile_traces 0.54, test_trace_solver 0.40 |
| test_workshop_public_evidence | main | 9 | 41 | 226 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_card_adapters 0.32, test_workshop_refusals 0.30 |
| test_roles_official | pr | 9 | 80 | 832 | game, sim, ui, workshop | 0 | 0 | 0 | 9 | test_roles_shelter 0.38, test_roles_dead 0.36 |
| test_workshop_consequences | main | 8 | 42 | 220 | ui, workshop | 1 | 0 | 0 | 0 | test_workshop_remaining 0.37, test_workshop_reasoning 0.33 |
| test_workshop_reading_challenges | pr | 8 | 41 | 220 | game, ui, workshop | 0 | 0 | 0 | 4 | test_workshop_nested_cases 0.36, test_workshop_secrets 0.35 |
| test_workshop_efficiency | pr | 8 | 15 | 158 | workshop | 0 | 0 | 0 | 0 | test_workshop_reasoning 0.21, test_workshop 0.20 |
| test_mechanics_conclusions | main | 8 | 17 | 115 | game, ui, workshop | 0 | 0 | 0 | 1 | test_workshop_card_adapters 0.27, test_workshop_votes 0.23 |
| test_social_credibility | main | 8 | 103 | 1044 | game, sim, workshop | 12 | 0 | 0 | 23 | test_shared_model 0.18, test_meeting_flow 0.16 |
| test_meeting_m2a | pr | 8 | 32 | 219 | game, sim, workshop | 0 | 0 | 0 | 13 | test_presentation_contracts 0.22, test_workshop_live_canvas 0.21 |
| test_conversation_nights | main | 8 | 30 | 411 | game, sim | 2 | 0 | 0 | 13 | test_social 0.24, test_meeting_m2b 0.24 |
| test_dialogue_decisions | main | 7 | 20 | 93 | game, sim | 1 | 1 | 0 | 2 | test_presentation_contracts 0.17, test_workshop_live 0.15 |
| test_workshop_tuning_probe | main | 7 | 35 | 383 | game, sim, workshop | 0 | 1 | 0 | 9 | test_shared_model 0.27, test_trace_solver 0.26 |
| test_roles_evil | pr | 7 | 66 | 544 | game, sim, workshop | 0 | 0 | 0 | 13 | test_roles_dead 0.15, test_roles_night_sight 0.13 |
| test_text_ui | main | 7 | 20 | 138 | sim, ui | 5 | 0 | 0 | 0 | test_town_ui 0.33, test_evidence_context 0.08 |
| test_tuning_hoist | main | 7 | 12 | 195 | game, sim, workshop | 0 | 0 | 0 | 2 | test_prior_mapping 0.19, test_meeting_m2b 0.18 |
| test_workshop_circumstantial_hub | main | 7 | 30 | 429 | game, sim, ui, workshop | 1 | 0 | 0 | 10 | test_workshop_reading_challenges 0.30, test_workshop_refusals 0.26 |
| test_roles_secrets | pr | 7 | 26 | 299 | game, sim, ui, workshop | 0 | 0 | 0 | 9 | test_roles_people 0.09, test_conversation_gifts 0.08 |
| test_dialogue | main | 6 | 133 | 664 | game, sim, ui | 35 | 0 | 0 | 2 | test_conversation_nights 0.18, test_dialogue_voices 0.12 |
| test_town_ui | main | 6 | 34 | 145 | sim, ui | 0 | 0 | 0 | 0 | test_text_ui 0.33, test_ui_controls 0.10 |
| test_workshop_live_ui | main | 6 | 11 | 91 | game, ui | 5 | 0 | 0 | 1 | test_workshop_attention 0.15, test_workshop_hints 0.12 |
| test_buildings_tavern_town_hall | pr | 6 | 33 | 361 | game, sim, ui, workshop | 0 | 2 | 0 | 4 | test_roles_official 0.22, test_roles_people 0.21 |
| test_workshop_hints | main | 6 | 13 | 95 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_refusals 0.73, test_workshop_votes 0.31 |
| test_workshop_presentation | main | 6 | 73 | 385 | game, sim, workshop | 0 | 0 | 0 | 10 | test_workshop_nested_cases 0.25, test_presentation_contracts 0.25 |
| test_workshop_refusals | main | 5 | 16 | 114 | game, sim, workshop | 2 | 0 | 0 | 1 | test_workshop_hints 0.73, test_workshop_card_adapters 0.32 |
| test_execution_aftermath | pr | 5 | 24 | 275 | game, sim | 2 | 0 | 0 | 6 | test_shadow 0.25, test_workshop_ownership 0.24 |
| test_headline | pr | 5 | 7 | 79 | game, workshop | 0 | 0 | 0 | 1 | test_prior_mapping 0.27, test_roles_shelter 0.12 |
| test_defence_repeats | main | 5 | 14 | 167 | game, sim, workshop | 0 | 0 | 0 | 6 | test_workshop_provenance 0.33, test_workshop_reading_identity 0.29 |
| test_mechanics_claims | main | 5 | 11 | 60 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_reading_identity 0.25, test_mechanics_sharing 0.20 |
| test_sighting_followup ⌚ | main | 5 | 32 | 174 | game, sim | 1 | 0 | 0 | 7 | test_meeting_m2b 0.23, test_conversation_nights 0.20 |
| test_workshop_reading_identity | main | 5 | 14 | 97 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_provenance 0.38, test_workshop_refusals 0.31 |
| test_workshop_secrets | main | 5 | 17 | 138 | game, ui, workshop | 0 | 0 | 0 | 1 | test_workshop_nested_cases 0.53, test_workshop_live_activity 0.39 |
| test_presentation_contracts | main | 5 | 24 | 168 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_vote_and_alibi 0.30, test_workshop_presentation 0.25 |
| test_prior_mapping | main | 5 | 5 | 99 | game, sim, workshop | 0 | 0 | 0 | 2 | test_meeting_stream 0.29, test_headline 0.27 |
| test_roles_shelter | pr | 5 | 44 | 326 | game, sim, workshop | 1 | 0 | 0 | 9 | test_roles_official 0.38, test_workshop_live_activity 0.34 |
| test_outcomes | main | 5 | 23 | 109 | game | 0 | 0 | 0 | 2 | test_dialogue_decisions 0.12, test_prior_mapping 0.10 |
| test_trace_art | main | 5 | 6 | 40 | sim, ui | 1 | 0 | 0 | 0 |  |
| test_workshop_canvas | main | 5 | 48 | 225 | ui, workshop | 1 | 0 | 0 | 0 | test_workshop_remaining 0.30, test_workshop_consequences 0.30 |
| test_workshop_live_cognition | main | 5 | 34 | 213 | game, sim, workshop | 2 | 1 | 1 | 8 | test_workshop_ownership 0.38, test_workshop_reading_identity 0.28 |
| test_workshop_vote_and_alibi | pr | 5 | 11 | 194 | game, sim, workshop | 0 | 0 | 0 | 4 | test_presentation_contracts 0.30, test_workshop_circumstantial_hub 0.26 |
| test_board | main | 5 | 40 | 248 | game, sim, ui | 0 | 1 | 0 | 12 | test_sighting_followup 0.14, test_buildings_tavern_town_hall 0.09 |
| test_workshop_checkpoint | main | 4 | 0 | 96 | workshop | 0 | 0 | 0 | 0 | test_workshop 0.33, test_workshop_consequences 0.25 |
| test_workshop_live | main | 4 | 23 | 107 | game, sim, workshop | 1 | 0 | 0 | 1 | test_workshop_attention 0.25, test_workshop_votes 0.20 |
| test_workshop_ownership | pr | 4 | 48 | 263 | game, sim, workshop | 0 | 0 | 0 | 2 | test_workshop_live_cognition 0.38, test_workshop_reading_identity 0.27 |
| test_workshop_reasoning | main | 4 | 44 | 257 | workshop | 1 | 0 | 1 | 0 | test_workshop 0.62, test_workshop_cases 0.45 |
| test_beliefs | pr | 4 | 14 | 287 | game, sim | 0 | 0 | 0 | 1 | test_execution_aftermath 0.23, test_defence_repeats 0.21 |
| test_evidence_context | main | 4 | 13 | 96 | game, sim, ui, workshop | 2 | 0 | 0 | 1 | test_text_ui 0.08, test_town_ui 0.07 |
| test_social_trust | main | 4 | 15 | 98 | game, sim | 0 | 0 | 0 | 4 | test_workshop_tuning_probe 0.07, test_social_credibility 0.07 |
| test_mechanics_defences | main | 4 | 7 | 89 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_public_evidence 0.29, test_workshop_refusals 0.27 |
| test_mechanics_sharing | main | 4 | 14 | 81 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_provenance 0.23, test_workshop_reading_identity 0.20 |
| test_workshop_action | main | 4 | 16 | 115 | game, sim, workshop | 1 | 0 | 0 | 2 | test_defence_repeats 0.23, test_social_evidence_boundary 0.21 |
| test_mechanics_relays | main | 4 | 9 | 60 | game, sim, workshop | 0 | 1 | 0 | 1 | test_workshop_provenance 0.23, test_mechanics_defences 0.23 |
| test_town_vibe | pr | 4 | 11 | 98 | game, sim | 0 | 1 | 0 | 4 | test_shadow 0.14, test_dialogue_decisions 0.13 |
| test_workshop_card_adapters | main | 4 | 30 | 211 | game, sim, workshop | 0 | 1 | 0 | 9 | test_workshop_public_evidence 0.32, test_workshop_refusals 0.32 |
| test_workshop_live_activity | main | 4 | 32 | 151 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_secrets 0.39, test_roles_shelter 0.34 |
| test_workshop_nested_cases | main | 4 | 17 | 115 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_secrets 0.53, test_workshop_reading_challenges 0.36 |
| test_dialogue_opinion_pass | main | 4 | 30 | 131 | game, sim | 7 | 0 | 0 | 1 | test_dialogue_voices 0.11, test_dialogue 0.11 |
| test_peer_role_gossip | pr | 4 | 27 | 263 | game, sim | 0 | 3 | 0 | 9 | test_town_vibe 0.08, test_mechanics_sharing 0.07 |
| test_social_evidence_boundary | main | 4 | 20 | 112 | game, sim | 0 | 0 | 0 | 2 | test_workshop_action 0.21, test_mechanics_sightings 0.15 |
| test_workshop_votes | main | 4 | 10 | 79 | game, sim, workshop | 0 | 0 | 0 | 1 | test_workshop_hints 0.31, test_workshop_card_adapters 0.29 |
| test_mechanics_sightings | main | 3 | 8 | 70 | game, sim, workshop | 0 | 0 | 0 | 1 | test_defence_repeats 0.23, test_workshop_reading_identity 0.20 |
| test_nomination_and_evil_tuning | main | 3 | 18 | 159 | game, sim | 0 | 0 | 0 | 5 | test_workshop_action 0.20, test_social_evidence_boundary 0.14 |
| test_workshop_attention | main | 3 | 13 | 76 | game, workshop | 0 | 0 | 0 | 1 | test_workshop_hints 0.30, test_workshop_live 0.25 |
| test_workshop | main | 3 | 40 | 176 | workshop | 0 | 1 | 0 | 0 | test_workshop_reasoning 0.62, test_workshop_cases 0.55 |
| test_workshop_cases | main | 3 | 39 | 201 | workshop | 0 | 0 | 0 | 0 | test_workshop 0.55, test_workshop_reasoning 0.45 |
| test_workshop_factor_cache | main | 2 | 0 | 34 | workshop | 0 | 0 | 0 | 0 | test_case_eval 0.25, test_workshop_class_parity 0.22 |
| test_workshop_channel_likelihood | pr | 2 | 21 | 173 | workshop | 0 | 0 | 0 | 0 | test_workshop_class_parity 0.38, test_case_eval 0.15 |
| test_case_eval | main | 1 | 15 | 138 | workshop | 0 | 0 | 0 | 0 | test_workshop_factor_cache 0.25, test_workshop_cases 0.25 |
| test_dialogue_vn_preview | main | 1 | 27 | 70 | ui | 2 | 0 | 0 | 0 |  |
| test_workshop_card_answers | main | 1 | 13 | 77 | workshop | 0 | 3 | 0 | 0 | test_mechanics_relays 0.20, test_workshop_channel_likelihood 0.12 |
| test_workshop_channels | main | 1 | 20 | 102 | workshop | 0 | 0 | 0 | 0 | test_workshop_channel_likelihood 0.12, test_workshop_class_parity 0.11 |
| test_text_formatter | main | 1 | 30 | 111 | sim, ui | 1 | 0 | 0 | 0 | test_text_terms 0.33, test_ui_controls 0.02 |
| test_text_terms | main | 1 | 28 | 60 | sim, ui | 1 | 0 | 0 | 0 | test_text_formatter 0.33, test_ui_controls 0.02 |
| test_channel_sum_product | main | 0 | 7 | 35 | workshop | 0 | 0 | 0 | 0 |  |
| test_csharp_slice_c0 ⌚ | pr | 0 | 0 | 149 | sim | 0 | 0 | 0 | 0 |  |

⌚ named after when it was written (batch, phase, slice, playtest…) rather than what it tests. ✕ failed in the timing run.

## Most-overlapping pairs

Jaccard similarity of the game functions, methods and commands the two suites call (ignoring ones most suites call).

| Similarity | Suite A | Suite B | Shared |
|---|---|---|---|
| 0.73 | test_workshop_hints | test_workshop_refusals | 8 |
| 0.62 | test_workshop | test_workshop_reasoning | 5 |
| 0.55 | test_workshop | test_workshop_cases | 6 |
| 0.54 | test_workshop_profile_traces | test_workshop_two_traces | 13 |
| 0.53 | test_workshop_nested_cases | test_workshop_secrets | 8 |
| 0.45 | test_workshop_cases | test_workshop_reasoning | 5 |
| 0.40 | test_trace_solver | test_workshop_two_traces | 10 |
| 0.39 | test_workshop_live_activity | test_workshop_secrets | 7 |
| 0.38 | test_workshop_provenance | test_workshop_reading_identity | 5 |
| 0.38 | test_workshop_live_cognition | test_workshop_ownership | 10 |
| 0.38 | test_workshop_channel_likelihood | test_workshop_class_parity | 3 |
| 0.38 | test_roles_official | test_roles_shelter | 17 |
| 0.37 | test_workshop_consequences | test_workshop_remaining | 10 |
| 0.36 | test_workshop_nested_cases | test_workshop_reading_challenges | 8 |
| 0.36 | test_roles_dead | test_roles_official | 18 |
| 0.35 | test_workshop_reading_challenges | test_workshop_secrets | 7 |

## Near-duplicate checks across suites

Check messages that say nearly the same thing (70%+ word overlap): the likeliest real redundancy.

| Suite A | Suite B | Near-duplicates | Example |
|---|---|---|---|
| test_workshop_live_cognition | test_workshop_reasoning | 1 | “decisive contrary evidence can dislodge the live high-confidence theor” / “strong contrary evidence can dislodge the high-confidence theory” |

## Game modules by number of suites that preload them

| Module | Suites |
|---|---|
| game/game.gd | 80 |
| sim/mind.gd | 59 |
| sim/content.gd | 56 |
| workshop/solver.gd | 40 |
| game/workshop_canvas.gd | 33 |
| workshop/canvas_model.gd | 31 |
| sim/tuning.gd | 26 |
| workshop/case_eval.gd | 22 |
| workshop/shared_ledger.gd | 22 |
| workshop/ghost_juror.gd | 18 |
| sim/social.gd | 15 |
| workshop/live_assessment.gd | 15 |
| sim/evil.gd | 15 |
| workshop/jury.gd | 14 |
| ui/main.tscn | 11 |
| workshop/live_activity.gd | 11 |
| workshop/session.gd | 10 |
| sim/world.gd | 9 |
| ui/theme.gd | 8 |
| workshop/caches.gd | 8 |
| sim/mind_meeting.gd | 7 |
| game/workshop_bridge.gd | 7 |
| ui/live_case_workshop.gd | 7 |
| workshop/channel_likelihood.gd | 6 |
| workshop/factored_channels.gd | 6 |
| sim/script_def.gd | 6 |
| workshop/support_model.gd | 6 |
| workshop/live_evidence.gd | 6 |
| sim/dialogue.gd | 5 |
| workshop/reading_challenges.gd | 5 |
| workshop/reasoner.gd | 5 |
| workshop/world_domain.gd | 5 |
| game/card_model.gd | 4 |
| ui/card_list.gd | 4 |
| workshop/chronology.gd | 4 |
| workshop/evidence_channels.gd | 4 |
| game/credibility.gd | 4 |
| workshop/role_constraints.gd | 3 |
| game/recent_sightings.gd | 3 |
| sim/dialogue_voices.gd | 3 |
