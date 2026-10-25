# Backlog cleanup preparation — 2026-10-25

This is a static review of every active entry in [BACKLOG.md](../BACKLOG.md),
including the nested design proposals: **201 numbered preparation notes**. The Closed
section was read and left unchanged. Prep labels describe review findings; they do
not replace the original decisions, tags, priority, or wording. No feature, tuning,
merge, or gameplay batch was performed for this pass. Candidate completion below is
code evidence, not a newly observed passing playtest.

## Snapshot and branch boundaries

- Review base: refreshed `origin/main`, **`9cb87829f3d56072c128bc419869e12c581023ea`**
  (`Role check: key Medium relays on the Medium's delusion only; hoist routes`).
- Preparation branch: `codex/backlog-preparation`, in an isolated managed worktree.
  The shared checkout's dirty files and `codex/case-board-mechanics` were preserved.
- Local `main` and `origin/main` diverged at review start. No fast-forward was safe;
  this review uses the refreshed remote main containing Claude's latest work, without
  merging, resetting, or reconciling either history.
- **Update after review (Claude, Oct 25):** `codex/case-board-mechanics` was merged into
  main right after this snapshot (`0cd2181`, with speed fixes up to `e20a075`). Curse
  epochs, the expanded conclusion types, defence/hearing integration, NPC-to-NPC
  sharing, Warden guard receipts and Demon detours are now **on main**. Notes that
  depended on them (B037, B055, B077, B083, B128, B152, B154, B171, B187, B190, B191)
  were updated; other notes were checked against the merged code where they make
  capability claims. Two entries were added without prep numbers: "Replies must match
  beliefs" and the Performance entry.
- `codex/live-channel-validation` stays a dead reference. Its canceled validation and
  per-person latent-channel work are outside this cleanup.
- [LEGACY_MIGRATION.md](LEGACY_MIGRATION.md) records the current deliberate hybrid;
  [MECHANICS_SUPPORT.md](MECHANICS_SUPPORT.md) on this base is not proof that work on
  the unmerged mechanics branch has landed. Historical milestone/timing language in
  backlog reports must be checked against these boundaries.

## Shared code map

Paths and qualified functions in the inline notes were checked against this snapshot.
These are the main seams; use them to choose a narrow change rather than edit all
callers at once.

| Workstream / prep notes | Entry points and ownership | Main trap |
| --- | --- | --- |
| Card identity, attribution, revisions: B002, B011–B019, B058, B122, B145 | [game/game.gd](../game/game.gd): `add_card`, `_disclose`, `workshop_retract`; [game/workshop_canvas.gd](../game/workshop_canvas.gd): `file`; [game/card_model.gd](../game/card_model.gd) | Observation time differs from disclosure time. Preserve heard versions, original source, relay, and confidentiality history. |
| Beliefs and evidence ownership: B006–B010, B025–B027, B064–B066, B096, B104 | [game/workshop_ownership.gd](../game/workshop_ownership.gd): `_refresh`; [workshop/shared_ledger.gd](../workshop/shared_ledger.gd): `prepare`, `evaluate`, `endorsed_facts`; [sim/mind.gd](../sim/mind.gd): `adjust`, `_recompute_beliefs`, `_final_weight` | One retractable joint posterior vector. Do not also apply scoped reply effects or an extra template/defence bonus for the same facts. |
| Fit checks and live capability: B028–B035, B051, B159–B170, B187–B201 | [workshop/live_assessment.gd](../workshop/live_assessment.gd): `prepare`, `activity_card`, `medium_card`; [workshop/solver.gd](../workshop/solver.gd): `report_table`, `_report_content`; [sim/argue.gd](../sim/argue.gd): `assertions`, `_match_pair`, `_match_support` | A label/template, adapter, world constraint, and explanation are four different layers. Check each. |
| Reply, belief, and execution choice: B022, B037–B042, B060–B068, B123–B124, B154–B169, "Replies must match beliefs" | [workshop/jury.gd](../workshop/jury.gd): `refresh`, `_assess_target_eval`, `_consequences_eval`; [sim/mind.gd](../sim/mind.gd): `_good_nomination_impl`, `_vote_impl`, `execution_priority_contribution`; [sim/content.gd](../sim/content.gd) | Legacy vote formulas are live; only the shared execution-priority weight is zero. Premise salience and relative voting are design changes, not repairs to a missing hook. |
| Dialogue, trust, promises: B014–B020, B045–B053, B069–B079, B087–B100, B116–B146 | [sim/mind.gd](../sim/mind.gd): `press`, `answer_night`, `_answer_gift_impl`, `defend_self`, `set_trust`, `cap_trust`; [sim/social.gd](../sim/social.gd); [sim/dialogue.gd](../sim/dialogue.gd); [game/game.gd](../game/game.gd): `_offer_command`, `_settle_offers` | Define one incident/promise and hearing identity. Wording memory, evidence, fatigue, rapport, source honesty, and caps are not interchangeable. |
| Movement, physical evidence, protection: B023, B059, B083–B086, B103, B138–B142, B149–B153, B171–B179, B192–B201 | [sim/world.gd](../sim/world.gd): `_night_movement`, `_night_sightings`, `_maybe_drop`, `attack_outcome`; [workshop/live_activity.gd](../workshop/live_activity.gd): `movement_inputs`, `_paths`, `_profile_paths`; [workshop/live_protection.gd](../workshop/live_protection.gd): `assess` | Keep generation, public receipt, fit, cache key, and reply consistent. Unknown whereabouts and no death are not hard exclusions/proven blocked attacks. |
| Board/UI: B002, B004, B036, B108–B115, B145, B166 | [ui/case_state.gd](../ui/case_state.gd): `apply`; [game/board_model.gd](../game/board_model.gd): `layout`; [ui/board_view.gd](../ui/board_view.gd); [ui/live_case_workshop.gd](../ui/live_case_workshop.gd); [ui/workshop_comparison.gd](../ui/workshop_comparison.gd) | Row filtering/order affects pins and hit geometry. Rich text on the custom Canvas/Tree needs rendering work, not a formatter switch. |
| Bot, measurement, outcomes: B062, B083–B084, B147–B148, B181–B182 | [tools/autoplay.gd](../tools/autoplay.gd): `_scores`, `_decide`; [game/case_metrics.gd](../game/case_metrics.gd): `summarize`, `aggregate`; [tools/compare_runs.py](../tools/compare_runs.py) | Bot search peeks at hidden dropped-item presence. Fabricated-reading `true=false` is not measured semantic falsity. Freeze event-time state for transition metrics. |

## Dependency order within workstreams

This is a dependency map, **not a replacement backlog priority order**. Small fixes
can proceed independently; major proposals still require their listed decisions.

1. **Verify before rebuilding.** Check the closure candidates below and reproduce
   current failure routes. Wording/cast/block-count changes can be separate small
   commits, with no evaluator or balance tuning attached.
2. **Establish identity before accumulation or social rewards.** Reuse original
   fact/source/night identities and disclosure history. Define incident/request/
   promise IDs before apologies, propagated requests, rapport rewards, or repeated
   rebuttal credit. Then consolidate independent instances, traces, and caught lies
   as one aggregation project instead of three coefficient changes.
3. **Build on the merged mechanics support before extending live capability.** Epochs,
   hearing weights, the new conclusion types and detours are on main (`0cd2181`); extend
   them rather than adding parallel versions. Establish adapters/world constraints
   before widening conclusion menus.
   Generic innocent secrets and a particular Seer Red Herring remain unsupported
   where not established; the Psychologist remains context/metagame information.
4. **Resolve premise/action semantics before vote tuning.** The new premise-salience
   proposal, qualitative previews, Q3/rank/urgency, conviction, and reply-only Insight
   budgeting intersect. Define the expected belief versus action result first, keep
   the zero Q3 hook until approved, then add paired correct/wrong-case controls.
5. **Set movement/receipt semantics before more patterns.** Review detours, trace
   origin, completeness, contact timing, and spent-ward/save receipts together where
   they overlap. Generate public receipts first, adapt them, then add links/replies.
   Breathstealer presence uses possible daytime contacts, not only evening proximity.
6. **Measure before balance coefficients.** Correct bot evidence access/coverage
   before interpreting active bot outcomes. Measure fabricated reports by content,
   not provenance flags. Choose a vigil policy before changing yield and likelihood
   together. Use matched controls only when implementing the balance change, not for
   this documentation pass.
7. **Keep structural expansions separate.** Roster, topology, larger towns, new Demon
   mechanics, director, and toolbox each change existing assumptions. Inventory
   generation, hidden/public knowledge, adapters, UI, and performance first. Deferred
   ghost votes and canceled channel validation remain deferred/canceled.

## Candidates to close or narrow after focused verification

Original entries remain in place. These are code-backed candidates, not automatic
closures and not claims of fresh runtime success.

| Entries | Evidence on this main | Remaining check / narrower task |
| --- | --- | --- |
| B006–B009 saturation baseline | `Mind.adjust` stores an unclamped sum; reads clamp; ownership retracts/replaces. | Recompute/withdrawal parity; do not implement the old victim exemption. **Session verification (Oct 25; base 739f366):** Propose closure of B006/B009 and retirement of B007 workaround after exact reversal/shared takeover tests. B008 remains [open] and skipped; no sincerity policy changed. Full default runner: 73/75; only permitted test_social/test_text_ui failures. |
| B011–B012 revision identity/strength | `WorkshopCanvas.file` preserves versions; migration suite has revision/repeat assertions. | Exact shared versus native route, newest-first UI labels, old hearing history. **Session verification (Oct 25; base 739f366):** shared revisions equal a fresh hearing of complete support and preserve historical endorsement versions (`test_legacy_migration`, `test_workshop_live_canvas`). Newest-first UI lists now label revision/superseded links (`test_board`). **Propose closure for normal shared delivery and visible history**; explicit disabled/native novelty is not retuned. |
| B013 daily defence key | `Mind.defend_self` uses scope hash, not day. | Same complete hearing strength and no repeat stacking; alternative choices remain open. **Session verification (Oct 25; base 739f366):** Propose closure of the day-key/repeat-stack sub-bug after native/shared tests. B001 alternatives remain skipped because mechanical changes are prohibited. Full default runner: 73/75; only permitted test_social/test_text_ui failures. |
| B019 whereabouts/public claim cards | `answer_today`, `add_card`, `_disclose` retain facts/history. | Exact historical examples, date wording, and confidentiality promotion. |
| B030 watch versus vigil | `_match_pair` contains vigil/watch and omission links. | Exact named-set mismatch and player observation versus NPC claim alternatives. |
| B034, part of B191 totem adapter | `activity_card` and `test_workshop_card_adapters._totem` cover it. | UI conditional-role explanation; typed-minion conclusions are a separate gap. |
| Part of B036 evaluator label | Live workshop `_sync` labels mode. | Headline prominence, assumption origin, collateral/rejection warning, actual capability. **Session verification (Oct 25; base 739f366):** UI mode labels, unsupported-card help and support review now match normal blocked-evidence behavior and deliberate existing-rule mode. Regression checks preserve evidence/RNG/beliefs. **Propose closure of mode-label/fallback-guidance portion only**; assumption-origin and collateral explanation work remains. |
| B122 player revision/withdrawal | `_withdraw_window`, `workshop_retract`, and versioned filing exist. | Public explanation/NPC stance changes remain; learned facts must survive withdrawal. |
| B181 outcome scoring umbrella | Metrics already distinguish identification, persuasion loss, minion ID sets, reachability. | Exact gift/confidence credit and Scion/curse event-time attribution. |
| B200 conversation as location | Native assertions emit both participants' locations; shared adapter accepts evening conversations. | Exact filing/preview/trace example rather than adding a duplicate location adapter. |

Other stale/duplicate wording to reconcile explicitly when working those entries:

- Historical absolute Demon-victim/silence clears conflict with current finite
  evidence. Keep sincerity, role plausibility, accuracy, and alignment distinct.
- B021's test failure/engine claim is historical. This review did not rerun it;
  current walking-duty ordering has changed since that report.
- B044/B072 already have a daily pairing limit. B054/B074 are the same Medium
  eligibility/selection policy at different layers, not independent features.
- B026/B066/B104 share aggregation; B045/B050/B103/B105/B128 share rebuttal/incident
  work; B039/B053/B060/B123/B133 share resistance/reason feedback; B023/B170/B192
  share contact-pattern timing. Link their acceptance cases before implementation.

## Focused validation menu for later changes

Use the project's agreed **Godot 4.7.2** runtime. This pass checked references and
Markdown/diff integrity only; it did not install Godot, execute these suites, or
measure presentation timings. Existing suites are starting points; add the specific
acceptance case described in the inline note rather than assuming coverage.

Run explicit suites through [tools/run_gd_tests.py](../tools/run_gd_tests.py): it checks
failure text as well as process status (some scripts print failures yet exit zero).
For example, from the checkout being tested:

```powershell
python tools/run_gd_tests.py --godot "<Godot 4.7.2 executable>" --project . test_workshop_card_adapters test_legacy_migration
```

| Change area | Focused starting checks | Specific controls |
| --- | --- | --- |
| Shared adapters/fit | `tools/test_workshop_card_adapters.gd`, `tools/test_case_eval.gd`, `tools/test_workshop.gd` | Public metadata only; unsupported reason visible; complete versus partial observations; native filing and shared fit both checked. |
| Ownership/revision/aggregation | `tools/test_legacy_migration.gd`, `tools/test_defence_repeats.gd`, `tools/test_beliefs.gd` | Fresh complete case equals revision; repeat/relay adds no origin; withdrawal/recompute restores the correct outside baseline. Defence-repeat suite isolates native compatibility, so it alone cannot validate shared adoption. |
| Arguments/Medium | `tools/test_argue.gd`, `tools/test_social.gd`, `tools/test_sighting_followup.gd` | Original source/night, two-source doubt, no relay self-corroboration, exact fake report consistency. |
| Dialogue/trust/requests | `tools/test_dialogue.gd`, `tools/test_dialogue_decisions.gd`, `tools/test_playtest_regressions.gd`, `tools/test_shadow.gd` | Full transcript and cost; no new facts from phrasing; good/evil access parity; incident reward once; cap recovery explicit. |
| Voting/Q3 | `tools/test_workshop_action.gd`, `tools/test_beliefs.gd`, `tools/test_playtest_regressions.gd` | Agreement plus actual vote, strong first/close second, wrong moderate accusation, block/tie/post-tie counts, no hidden target knowledge. |
| Board/text UI | `tools/test_board.gd`, `tools/test_ui.gd`, `tools/test_text_ui.gd`, `tools/test_text_formatter.gd` | Manual narrow-screen/keyboard/zoom/pin check where rendering changes; no duplicate promotion/history or inaccessible rich links. |
| Outcomes/transitions | `tools/test_outcomes.gd`, `tools/test_case_viewer.py` | Event-time alignment/role, Scion identity, curse restoration, minion ID versus exact gift; player information differs from diagnostic grimoire access. |
| Movement/protection/cache | `tools/test_workshop_card_adapters.gd`, `tools/test_lamplighter_drops.gd`, `tools/test_workshop_attention.gd` | Empty/complete vigils, dead victim exclusion, alternate blockers/innocent walkers, new input in cache key, cached/uncached agreement. |

For a behavior change after focused checks, select only the relevant saved replay or
small matched comparison. The 54875 case-85 instruction remains **observe/report a
surprising result either way, do not tune to its estimated outcome**. Do not use
historical estimates as measured baselines. Broad passive batches are unnecessary
for documentation and small text/layout fixes.

## Performance and hidden-information guardrails

- [workshop/role_constraints.gd](../workshop/role_constraints.gd) now keys only the
  relevant Medium delusion holder bits and hoists routing inputs. New fields that
  affect results must enter the appropriate cache key; do not restore all-holder
  splitting or canceled generic channel execution for independent sources.
- Keep per-listener evidence likelihood reusable across scoped reply/refresh paths;
  do not multiply cost by every person's theory. Preserve queued meeting refreshes
  and the one audience capability pass per command.
- Use [tools/profile_live_presentation.gd](../tools/profile_live_presentation.gd) or
  [tools/profile_case_eval_town.gd](../tools/profile_case_eval_town.gd) for changes to
  evaluator keys, new factors, chronology, or meeting refresh scheduling. Record
  before/after on the same fixtures, including source count and town size. The speed
  budget is the user's: meeting entry and presenting about 2 s or less, nominations
  under 1 s (on the user's machine). Flag any change set that adds time against it, and
  measure late games too (seed 42, Days 3 to 4), not only the 54875 opening.
- Keep actual role/alignment/poison/curse state inside generation, evil strategy, or
  explicitly post-case diagnostics. Listener acceptance uses observed facts, own
  knowledge, and alternatives. In particular, `fake`/`true` generation flags are not
  player evidence or a calibrated truth-rate dataset.
- The bounded epoch design grows only in curse histories by public eligible-voter
  hypotheses. It is not permission to add unknown personal secrets, exact Red Herring
  identity, or an unbounded latent role/channel dimension.

## Decisions still needed

The inline notes retain each original open/tentative/knob status. Main unresolved
choices are Rumormonger's no-result/setup rule; setup secret-count definition;
premise salience/qualitative preview and Q3 values; conviction and Insight scope;
contact-pattern knowledge policy; action eligibility/measured rates and stage-2
ownership/weights; trust cap recovery/apology incident rules; request compliance
contracts; vigil cost/yield; Medium eligibility/selection; and movement/trace/detour
semantics. No new answer to those questions was inferred from this review.
