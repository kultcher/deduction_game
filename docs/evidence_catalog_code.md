# Evidence catalog: code pointers

Companion to `docs/evidence_catalog.md`, keyed by the same entry numbers. File and function names, not line numbers, so it survives edits. As of main `407069d`, Nov 9 2026.

## The systems

| System | Where |
|---|---|
| World enumeration | `workshop/cs/WorldDomain.cs` (`EnumerateWorlds`), `workshop/world_domain.gd` (`healthy`, `gift_time`, `rumor`), `workshop/solver.gd` (`universe`, `_build_universe`) |
| Reading content per world | `workshop/solver.gd` (`report_table`, `_report_content_impl`, `_testimony_content`, `source_valid`, `CONTENT_ROLES`) |
| Reading likelihood | `workshop/case_eval.gd` (`chance_content`, `_chance_content_fixed`, `ROLE_CONTENT_FIXED`, `reading_error`, `_route_credit`), `workshop/cs/CaseEvalKernel.cs` |
| Channel model (reference oracle) | `workshop/evidence_channels.gd` (`compile`, `materialize`), `workshop/channel_likelihood.gd` (`assess`), `workshop/factored_channels.gd` |
| Role table | `workshop/role_constraints.gd` (`fit_weight`, `bluff_weights`, `_FIXED_ROLES`), `workshop/cs/RoleConstraints.cs` (`FitsViewSingle`, `SeerRhWeight`, `AssignRole`, `BluffWeightsTemporal`) |
| Movement | `workshop/live_activity.gd` (`routes`, `factors`, `score`, `evaluate_trace_for_person`), `workshop/cs/LiveActivity.cs`, `workshop/movement_model.gd` (fixture experiment) |
| Public factors | `workshop/public_evidence.gd` (`factors`, `victim_ratio`) |
| Speech factors | `workshop/speech_evidence.gd` (`factors`) |
| Circumstantial hub | `workshop/circumstantial.gd` (`extract_hub_incidents`, `evaluate_union`, `stage1_gate`, `evaluate_smear_backlash`) |
| Attention | `workshop/reasoner.gd` (`_prepare`, `_salience`), `sim/recency.gd` (`salience`, `topic`, `refresh_cards`), `sim/mind_meeting.gd` (`recall_cited`) |
| Hearing weights and reliability | `workshop/shared_ledger.gd` (`_prepare_impl`: `reading_reliability`, sighting `hearing_weight`), `sim/mind.gd` (`hear_claim`, heard-reading weight) |
| Game evidence to solver cards | `workshop/live_assessment.gd` (`prepare`, `activity_card`, `medium_card`, `testimony_card`, `reading_valid`) |
| Evidence normalisation | `workshop/live_evidence.gd` (`normalize_card`, `REPORT_FIELDS`, `KINDS`) |
| Tuning | `sim/tuning.gd`: `Mind` (hearing weights, `SOURCE_REL_*`, `SIGHTING_*`), `Workshop` (`DEFAULT_ERR`, `OWN_ERR`, `LR_*`, `BLUFF_WEIGHT`, `NIGHT_OUT_RATES`, `VIGIL_MISS`, `DEMON_VICTIM_GOOD`, `REFUSAL_LR`, `CIRCUMSTANTIAL_*`, `RECENCY_*`) |

## A. Gift readings

Every role's reading is produced by its role file, `sim/roles/<role>.gd` (night or day hooks), and described by its shape fields in `sim/role_def.gd`. Player-facing text is in `sim/gifts.gd` (`short_text`).

| # | Content check | Likelihood (`q`) | Other |
|---|---|---|---|
| A1 Seer | role table: `SeerRhWeight` (Red Herring, Marked); `_testimony_content` (PING) | `_chance_content_fixed` (falls through to 0.5) | `seer_flag` |
| A2 Dowser | `_report_content_impl` (site group count, Marked loop) | `chance_content` (table share) | `REPORT_FIELDS.dowser` |
| A3 Surveyor | `_report_content_impl` (`is_parity_surveyor`; legacy block count) | `chance_content` | |
| A4 Augur | `_report_content_impl` (augur), `augur_day_spec`, `augur_world_outcome_prob`, filter in `_solve` | `chance_content` | |
| A5 Confessor | `_report_content_impl` (confessor: good / forgot) | `chance_content` | |
| A6 Chronicler | `_report_content_impl` (trio masks) | `_chance_chronicler` | |
| A7 Magistrate | `_report_content_impl` (parity branch), `_magistrate_nomination_ok` | `chance_content` | |
| A8 Clerk | `RoleConstraints.cs` 6a (`FlagRoleInGroup`, pool good) | fixed 0.5 | `role_def.role_target_pool` |
| A9 Archivist | same, pool minion | fixed 0.5 | |
| A10 Rumormonger | `world_domain.gd` `rumor`; `_report_content_impl` (marked holder in pair) | `_chance_rumormonger` | |
| A11 Gravedigger | `RoleConstraints.cs` 6a (executed group, Scion branch, `FlagGravediggerExecOk`); `live_history.gd` (`executed`) | fixed 0.5 | |
| A12 Executor | `RoleConstraints.cs` 6a (`RoleExecutor`); `_report_content_impl` (executor); `History.died_before_morning` | fixed 0.5 | |
| A13 Registrar | `RoleConstraints.cs` (`RegistrarMatches`, `RegistrarYesStep`); `role_constraints.gd` (`_registrar_roles_ok`) | fixed 0.5 | Town Hall pool: `factored_channels.gd` |
| A14 Monitor | `_report_content_impl` (monitor) | fixed 0.5 | |
| A15 Psychologist | `_solve` (psychologist pair filter), `factored_channels.gd` (`psych_pairs`) | report table share (likely 1) | `live_evidence.gd` `social_reading` |
| A16 Night Watch | `live_activity.gd` `routes`; `_report_content_impl` (NIGHT_ROUTE dead check) | fixed 0.25 | watch claims: `live_assessment.gd` `activity_card` (`watch_claim`) |
| A17 Lamplighter | `live_activity.gd` `routes` (`forced_lamp`); `LiveActivity.cs` (lamp counts) | table share (1) | |
| A18 Medium | `live_assessment.gd` `medium_card`; `evidence_channels.gd` (relay channels); `RoleConstraints.cs` step 2 (visits) | the original's | `Tuning.Evil.MEDIUM_USELESS_CHANCE` |
| A19 Warden | `_report_content_impl` (warden, `saved`); `activity_card` (`guard_claim`, `save_claim`) | fixed 0.5 | |
| A20 Veteran | `RoleConstraints.cs` step 4 (approach); `live_activity.gd` | fixed 0.5 | |
| A21 Martyr | `RoleConstraints.cs` (`KindEventMartyr`, `FlagMartyr*`); `public_evidence.gd` `martyr_receipts` | fixed 0.5 | adapter issue in `live_assessment.gd` `prepare` |
| A22 Sexton | `RoleConstraints.cs` step 3 (knell) | — | |
| A23 Hearthwitch | `_report_content_impl` (site group, `nbrs`) | — | benched in `sim/roles/hearthwitch.gd` |

## B. Statements about roles and gifts

| # | Where |
|---|---|
| B1 Role claim | made: `sim/mind.gd` (`hear_claim`), `sim/mind_dialogue.gd`; weighed: `RoleConstraints.cs` 6a (`KindClaim`, `AssignRole`), `role_constraints.gd` `bluff_weights` / `BluffWeightsTemporal`; auto-citation: `workshop/canvas_model.gd` (`_auto_citations`) |
| B2 Gift-family hint | `sim/content.gd` (`HINT_PACKAGES`); `live_assessment.gd` `activity_card` (`gift_hint`); `speech_evidence.gd` |
| B3 Secret confession | `sim/content.gd` (`SECRETS`, `SECRET_MODS`); `activity_card` (`secret_claim`); `RoleConstraints.cs` step 1 (Sleepwalker claim) |
| B4 Refusal | `activity_card` (`refusal`); `circumstantial.gd` (`demeanor_tell`) |
| B5 Town Hall | `sim/world.gd` (`consult_town_hall`); `game/game_day_night.gd` (town hall command); `activity_card` (`town_hall`); `RoleConstraints.cs` (`TownHallMatches`) |

## C. Whereabouts

| # | Where |
|---|---|
| C1 Day sighting / conversation | made: `game/game_day_night.gd` (`_observe`), `sim/social.gd`; card: `activity_card` (`location`, `orig_kind`); used: `circumstantial.gd` (association, Breathstealer proximity) |
| C2 Evening sighting | `activity_card` (`evening`); `live_activity.gd` |
| C3 Night sighting | made: `sim/social.gd`, `sim/mind_dialogue.gd`, Night Watch; card: `activity_card`; weighed: `live_activity.gd` `factors` / `score`; profiles `Tuning.Workshop.NIGHT_OUT_RATES`, `WALKER_CLAIM_*` |
| C4 Home alibi | made: `sim/dialogue.gd`, `sim/mind_dialogue.gd`, `sim/mind_podium.gd`, `sim/mind_support.gd`; channel: `evidence_channels.gd` (`testimony_honesty`); dispute: `Solver.Graph.valid_dispute` (`workshop/case_graph.gd`) |
| C5 Dropped belongings | `game/game_day_night.gd` (`_search`, owner branch: a sighting with `dropped`); `activity_card` (`item_drop`) |
| C6 Mud or soot drop | `_search` (material branch); `activity_card` (`dropped`); `live_activity.gd` (drop owner matching) |
| C7 Vigil | `game/game_day_night.gd` (vigil); `activity_card` (`coverage`, vigil sightings `complete`); `Tuning.Workshop.VIGIL_MISS` (mirrored as `VigilMiss` in `LiveActivity.cs`) |

## D. Crime scenes and night events

| # | Where |
|---|---|
| D1 Demon victim | `public_evidence.gd` (`demon_victims`, `victim_ratio`); `Tuning.Workshop.DEMON_VICTIM_GOOD` |
| D2 Trace | made: `sim/world.gd` (`build_actor_trace`, `_build_locations_trace`, `_build_quarter_trace`, `_build_connection_trace`, `actor_fits_trace_truth`, passer traces in the kill); found: `game/game_day_night.gd` `_search`; card: `activity_card` (`trace`); weighed: `live_activity.gd` `evaluate_trace_for_person`, `workshop/trace_solver.gd`; NPC talk: `sim/deduction.gd`, `sim/mind_dialogue.gd` |
| D3 Quiet night | `game/game_day_night.gd` (quiet); `activity_card` (`quiet`) |
| D4 Scorched sigil | `game/game_day_night.gd`; `activity_card` (`attack`); `live_assessment.gd` `prepare` (adds `demon_attack` to the timeline) |
| D5 Totem / curse | `game/game_day_night.gd` `_search` (totem); `activity_card` (`totem`, `curse`, `curse_lifted`); `RoleConstraints.cs` (`KindTotem`, curse); `workshop/chronology.gd` |
| D6 Execution | `activity_card` (`execution`); `workshop/live_history.gd` |
| D7 Silenced | `public_evidence.gd` (silenced factor); `circumstantial.gd` (`breathstealer_proximity`); `sim/roles/breathstealer.gd` |

## E. Public behaviour

| # | Where |
|---|---|
| E1 Vote / nomination | `activity_card` (`vote` context); `circumstantial.gd` (`hostile_vote`, `shielding`); `_magistrate_nomination_ok` |
| E2 Accusation / opinion | rejected in `live_assessment.gd` `prepare`; `live_evidence.gd` `contains_opinion`; NPC side: `sim/mind_meeting.gd` (`nomination_case`, `_public_accusation`, `recall_cited`), `sim/recency.gd` (`topic`) |
| E3 Tavern rumour | rejected in `live_assessment.gd` `prepare` (`tavern_gossip`) |

## F. Profile context

| # | Where |
|---|---|
| F1 Home / work / haunt | `activity_card` (`home`, `work`, `haunt`); trace fit in `live_activity.gd` |
| F2 Trait | `activity_card` (`trait`); `circumstantial.gd` (`demeanor_tell`) |
| F3 Bond | made: `game/game_day_night.gd` (tavern gossip, `add_profile_receipt`); `activity_card` (`bond`); `circumstantial.gd` (`suspicious_association`, `victim_rivalry`) |

## G. Player premises and challenges

| # | Where |
|---|---|
| G1–G6 Premises | menu: `ui/live_case_workshop.gd` (`LIVE_TYPES`); tested: `workshop/solver.gd` (`holds`), `workshop/case_eval.gd` (premise masks); `live_assessment.gd` (`CONCLUSIONS`) |
| G2 Suspicious | `workshop/shared_ledger.gd` (half-weight hearing); `game/workshop_presentation.gd` (pressure); `Tuning.Workshop.SUSPICIOUS_HEARING`, `SUSPICIOUS_PRESSURE_PER_RISE` |
| G4 Secret premise | `workshop/shared_ledger.gd` (`_add_player_words`); `game/credibility.gd` (`_agreement`, track record) |
| G7 Challenges | `workshop/reading_challenges.gd` (`MODES`, `assess`, `graded_challenge`); `workshop/canvas_model.gd`; `live_assessment.gd` (`INCONSISTENT_CAUSES`); `workshop/consequences.gd` and `workshop/jury.gd` (Poisoner candidates); `Tuning.Workshop.CHALLENGE_*` |

## H. Distorters

| Distorter | Where |
|---|---|
| Secrets (Marked, Delusional, Lovers, Sleepwalker, Muddler) | `sim/content.gd` (`SECRET_MODS`); `workshop/cs/WorldDomain.cs`; `workshop/solver.gd` (`_secret_mod_code`) |
| Red Herring | `RoleConstraints.cs` (`SeerRhWeight`) |
| Poisoner | `sim/roles/poisoner.gd`; fixtures only in the solver: `workshop/chronology.gd` (`poison_windows`), `workshop/fixtures.gd` |
| Revenant | `sim/roles/revenant.gd`; `workshop/chronology.gd` |
| Scion | `sim/roles/scion.gd`; `role_constraints.gd` (`_scion_exec_alive_demon_mask`) |
| Brute | `sim/roles/brute.gd`; `sim/world.gd` (who hunts) |
| Breathstealer | `sim/roles/breathstealer.gd`; `public_evidence.gd` |
| Sexton's bell | `sim/roles/sexton.gd`; `RoleConstraints.cs` (knell) |
| Demon types (day-killer) | `workshop/live_activity.gd` (`mix_demon`); `docs/demon_types_plan.md` |
