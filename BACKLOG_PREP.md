# Demonologist backlog: preparation notes

Codex's per-entry preparation notes (written against commit 9cb8782, Oct 24) and its "session scope"
notes on entries it skipped, moved out of BACKLOG.md on Oct 26 to keep that file readable. Code
pointers may have moved. Grouped by the backlog entry they belonged to (section, then entry title).

## Case 44814: inconsistent pair-reading defenses · B001

_1. Bugs and quick fixes (hours, low risk)_

> **Session verification 2026-10-25 (B001):** Skipped: choosing mutually exclusive pair/challenge
> explanations would change defence hearing/belief mechanics, which this session prohibits. Stable
> daily keys (B013) are a separate verified closure. Full default runner: 73/75; only permitted
> test_social/test_text_ui failures.

> **Prep B001 (9cb8782; open):** `sim/mind.gd::defend_self` can emit pair redirection and lying/misled
> moves together. Choose a single explanation/hearing policy; extend `tools/test_defence_repeats.gd`
> with the 44814 pair case before changing strengths.

## Rumormonger as the sole modifier holder · B003

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B003):** Skipped [open]: Rumormonger no-result/setup choice remains
> unresolved and coordinated evidence handling would reach protected workshop code.

> **Prep B003 (9cb8782; design):** Coordinate `sim/world.gd::_receive_info`'s self-excluding
> pool/fallback with `workshop/solver.gd::_report_content` and UI. No-result versus setup changes
> remains undecided; preserve the generator-backed fallback test until that decision.

## From playtest 54875 · B005

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B005):** The historical 54875 parent is not closed wholesale. Only
> its verified sub-bugs are proposed for closure. Changing numerical real-listener
> effectiveness/premise previews reaches protected judge behavior and pending preview design.

> **Prep B005 (9cb8782; historical context):** Several child reports are partly resolved.
> `docs/LEGACY_MIGRATION.md` now specifies a deliberate hybrid; do not read this old diagnosis as a
> requirement to remove every native social mechanic.

## Related inconsistency · B008

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B008):** Skipped [open]: choosing how death changes sincerity
> versus accuracy is a belief/credence decision; no numbers or protected evaluator paths were
> changed.

> **Prep B008 (9cb8782; partial):** Keep sincerity, role plausibility, and accuracy separate in
> `sim/mind.gd::_honesty`, `_recompute_beliefs`, and `workshop/solver.gd::report_table`.
> Consolidate with “Demon victims' earlier information”; death must not make poisoned readings
> accurate.

## A press with a sighting replayed the alibi word for word · B016

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B016):** Skipped: a genuinely changed story or disclosure after a
> press needs NPC response/cover choices; merely adding another lead-in would not fix this
> report. No cover strategy or belief effects were changed.

> **Prep B016 (9cb8782; open):** Follow `sim/mind.gd::press` into `answer_night` and dialogue memory.
> A fresh lead-in can still wrap an unchanged alibi; test the full transcript and question cost, not
> just a changed prefix.

## The owned lie didn't follow the disclosure · B017

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B017):** The good-walker admission exists and is tested. Remaining
> evil-walker admission/withheld-report coherence would change evil cover/disclosure behavior;
> skipped under the evil-strategy boundary.

> **Prep B017 (9cb8782; partial):** `sim/mind.gd::_answer_gift_impl` already admits a good walker's
> stored `lied_nights`. Check sighting-triggered history and evil cover separately;
> `reading_disclosed` gates Night Watch results in `answer_night`.

## `tools/test_social.gd` fails on main · B021

_1. Bugs and quick fixes (hours, low risk)_

> **Session scope 2026-10-25 (B021):** The full runner still reports the permitted false Night
> Watch consistency failure. Fixing that evil-story behavior is outside this session, so no
> strategy or fake reports were changed.

> **Prep B021 (9cb8782; historical test claim):** Current `sim/mind.gd::answer_night` puts claimed
> walking duties before home; `sim/evil.gd::fake_night_sighting` caches speaker/night. Re-run
> `tools/test_social.gd` before calling this a current failure. The cited engine/results are old; no
> suite was run for this preparation.

## The premise should matter (with Q3 tuning) · B022

_Deduction types and templates_

> **Prep B022 (9cb8782; design; shared dependency):** `workshop/jury.gd::refresh` now uses a neutral
> global target; `_assess_target_eval` judges the premise separately. Target-scaled updates need
> reversible ownership, not another additive effect. Coordinate with Q3 and
> `ui/workshop_comparison.gd::describe`; numbers remain open.

## Seen with the silenced: circumstantial suspicion · B023

_Deduction types and templates_

> **Prep B023 (9cb8782; design):** `sim/evil.gd::breath_target` now enforces same-block contact at
> possible day phases; silence is applied later by `sim/world.gd::begin_meeting`. Choose the
> knowledge/card policy first. Evening-only intersections or meeting locations misrepresent possible
> action times.

## Starting secret-count card · B024

_Deduction types and templates_

> **Prep B024 (9cb8782; design):** Setup distinguishes `_assign_secret_mod` from `_assign_secrets` in
> `sim/world.gd`; generate a receipt in `game/game.gd::new_case` only after defining type versus holder
> versus ordinary-secret count. Do not expose assignments.

## One evaluation path for generic and structured cases · B025

_Deduction types and templates_

> **Prep B025 (9cb8782; partial; consolidate):** Shared consequences live in
> `workshop/shared_ledger.gd::evaluate`; native `sim/argue.gd::assertions` still has a location-poor
> death assertion and separate link routes. Align evidence-family semantics across adapters, templates,
> and previews rather than raising generic sums.

## Independent support versus repetition · B026

_Deduction types and templates_

> **Prep B026 (9cb8782; open; duplicate workstream):** `sim/mind.gd::_final_weight` selects strongest
> justification; shared facts deduplicate origins. Group with independent instances/repeated traces.
> New nights must accumulate appropriately, while repeating one origin must not add another posterior
> contribution.

## Template generalization · B027

_Deduction types and templates_

> **Prep B027 (9cb8782; partial architecture):** Shared family semantics exist in
> `workshop/solver.gd::report_table`; native filing still uses `sim/argue.gd::check`. Extend adapters,
> fit checks, and link surfaces together instead of adding isolated role templates.

## From playtest 54875: case-workshop links that were missing or misread · B028

_Deduction types and templates_

> **Prep B028 (9cb8782; mixed coverage):** The children span link recognition, shared likelihoods, and
> UI expressiveness. Check each separately: a successful posterior does not prove
> `game/game.gd::find_links` can file the desired explanation.

## A reading against an alibi is filed as "Contradicted home alibi" · B029

_Deduction types and templates_

> **Prep B029 (9cb8782; open in part):** `sim/argue.gd::_match_pair` builds out-versus-home
> alternatives through `_place_expls`. Keep player observations distinct from NPC reports; test
> offered explanations as well as shared report doubt, without upgrading hearsay to observation.

## One person's two accounts of the same night · B031

_Deduction types and templates_

> **Prep B031 (9cb8782; open):** `sim/argue.gd::_match_pair` detects Seer/Hearthwitch flips, not
> general Night Watch named-set changes. Preserve full contents, original source, and observed night;
> two disclosures of one report are not automatically independent readings.

## "Killed by the demon, so good" should give credence to the victim's alibi · B032

_Deduction types and templates_

> **Prep B032 (9cb8782; partial):** Finite death evidence is adapted by
> `workshop/live_assessment.gd::activity_card`; native honesty/alibi reasoning remains separate.
> Consolidate victim-information policy, testing Sleepwalker and poison alternatives. Death must not
> prove a home alibi.

## Surveyor answers · B033

_Deduction types and templates_

> **Prep B033 (9cb8782; partial):** `workshop/solver.gd::report_table` accepts blocks/people and
> `ui/case_workshop_canvas.gd::_refresh_case` has Surveyor controls. Test the exact
> two-block/two-person expression and cleared-block explanation before changing the answer schema.

## A claimed day gift but seen out at night · B035

_Deduction types and templates_

> **Prep B035 (9cb8782; partial; balance dependency):** `workshop/live_activity.gd::_profile_paths`
> already gives non-walking claims an ordinary/secret mixture. Surface existing support with
> walking-claim explanations; coordinate strength changes with the sighting balance pass, not a
> second penalty.

## From playtest 54875: case-workshop feedback · B036

_Deduction types and templates_

> **Prep B036 (9cb8782; partial UI):** `ui/live_case_workshop.gd::_sync` already labels evaluator mode;
> `_support_details`/`_preview_effectiveness` and `ui/workshop_comparison.gd::describe` expose
> diagnostics. Check each symptom with a small canvas; assumption origin and collateral warnings are
> separate from the qualitative-preview proposal.

## From playtest 54875: agreement has to reach the vote · B037

_NPC behaviour_

> **Prep B037 (9cb8782; open):** Trace `workshop/jury.gd::_consequences_eval` through
> `sim/mind.gd::action_susp`/`_vote_impl`. Belief, crowd/player pressure, preferred block, and voting
> threshold differ. Pair agreement/vote assertions and explanations. Q3 is deferred, not disabled: the
> legacy vote/nomination formulas (including the player vote/accuse terms) run today; only the
> shared execution-priority input sits at weight zero until the design pass. (Claude, after merge)

## "Accept" is wording, not belief · B038

_NPC behaviour_

> **Prep B038 (9cb8782; partial):** `workshop/shared_ledger.gd::response` and `evaluate` separate
> scoped reply from global consequences. Define what “accept” promises and align wording. Applying
> the scoped vector as well as the owned global vector would double-count evidence.

## When they agree and still vote no, they say why · B039

_NPC behaviour_

> **Prep B039 (9cb8782; open):** `sim/mind.gd::_vote_impl` records score parts and margins. Generate
> explanations from those perceived causes rather than a new calculation; selective spoken reasons
> versus silent votes belongs to the common meeting-talk decision.

## "I'm more suspicious of Edda" is relative · B040

_NPC behaviour_

> **Prep B040 (9cb8782; open; Q3 batch):** `sim/mind.gd::ranked_suspects`, `_good_nomination_impl`,
> and `_vote_impl` separate ranking from an absolute voting bar. Test close second choices and a
> strongly preferred block; relative wording is not a promise to spare.

## Urgency · B041

_NPC behaviour_

> **Prep B041 (9cb8782; design):** Day/paranoia and Confidence already affect
> `sim/mind.gd::_vote_impl`'s bar. Set urgency scope alongside rank-aware execution/Martyr urgency;
> lower bars can also approve moderately supported wrong nominations.

## From playtest 54875: Insight and Confidence barely shaped reactions · B042

_NPC behaviour_

> **Prep B042 (9cb8782; partial; migration boundary):** `workshop/reasoner.gd::_prepare` still limits
> evidence used in beliefs; reply-only Insight budgeting is not built. Confidence scaling exists, but
> conviction protection remains a separate design. Do not restore per-person world searches for varied
> reactions.

## From playtest 54875: evil's cover priorities are backward · B043

_NPC behaviour_

> **Prep B043 (9cb8782; open strategy):** Inspect `sim/evil.gd::review_scapegoat`, `caution`,
> `teammate_value`, and `sim/mind.gd::_public_claim_decision`. Preserve shadow/public-information
> boundaries: internal evil stakes may use private intel, but spoken reasoning must not expose it.

## From playtest 54875: evil meetings are over-weighted and always visible · B044

_NPC behaviour_

> **Prep B044 (9cb8782; partial limits exist):** `sim/world.gd::_pre_pair` weights
> `sim/social.gd::news_bonus`; `_make_pair` already stamps one pairing per NPC/day. Separate
> visibility, news weighting, and frequency before adding cooldowns; `_post_pair` also restricts
> partners by location.

## From playtest 54875: a hidden walker caught out should explain · B045

_NPC behaviour_

> **Prep B045 (9cb8782; partial; duplicate rebuttals):** Admission exists in
> `sim/mind.gd::_answer_gift_impl`; `defend_self` and disclosure gates control explanation choice.
> Group false-alibi/hidden-walker work so one incident produces one hearing, not stacked innocence
> bonuses.

## From playtest 54875: the Gravedigger in a reluctant town · B046

_NPC behaviour_

> **Prep B046 (9cb8782; design):** `sim/mind.gd::_good_nomination_impl`/`nomination_case` consume
> suspicion and reasons; `sim/world.gd::_receive_info` generates Gravedigger reports.
> Information-seeking execution needs an explicit purpose, not a false Demon assertion or guaranteed
> true-role knowledge.

## From playtest 54875: evil frames should cohere · B047

_NPC behaviour_

> **Prep B047 (9cb8782; partial; focused regression):** `sim/evil.gd::make_plan`, `make_fake_info`, and
> `fake_night_sighting` store cover; `sim/mind.gd::answer_night` now prioritizes claimed duties. Check
> private/public versions of one night and changing scapegoats. Never rewrite an old report to fit a
> new frame.

## Case 44814: asking about an already disclosed gift · B048

_NPC behaviour_

> **Prep B048 (9cb8782; partial):** `sim/social.gd::answer_is_role` repeats known roles without
> readings; `game/game.gd::_talk_command` routes ordinary gift/info asks elsewhere. Join carefully so
> confirmation can offer disclosed information without granting a new disclosure tier or repeat credit.

## Case 44814: readings after role disclosure · B049

_NPC behaviour_

> **Prep B049 (9cb8782; partial):** `sim/mind.gd::_answer_gift_impl` already preserves public floors
> and offers remaining readings. Reproduce the exact withheld/shared report with privacy/gossip gates;
> knowing a role is not automatic access to all reports.

## Follow-up after a false alibi is established · B050

_NPC behaviour_

> **Prep B050 (9cb8782; open; consolidate):** Use `sim/mind.gd::press`, `answer_night`, and
> `defend_self`. Track one challenged incident, then choose admission, explanation, or refusal. Private
> and meeting follow-up should share that transition while retaining the false statement.

## Reading challenges and next supported gifts · B051

_NPC behaviour_

> **Prep B051 (9cb8782; partial):** `workshop/reading_challenges.gd` and
> `workshop/canvas_model.gd::add_modifier` provide scoped challenges; relay restrictions remain in UI.
> Extend evidence-family support with adapter/solver checks rather than bypassing unsupported gifts at
> submission.

## Revenant revelation and reversible town uncertainty · B055

_NPC behaviour_

> **Prep B055 (9cb8782; updated after merge `0cd2181`):** Curse epochs are now on main
> (`workshop/chronology.gd`; `workshop/live_assessment.gd` handles cursed games): public eligible
> voters and hypothetical epochs, never the hidden turnee. Check this entry against that work rather
> than building a second version.

## Secret awareness and bluffing · B056

_NPC behaviour_

> **Prep B056 (9cb8782; partial):** `sim/world.gd::_assign_secret_mod` now excludes walking gifts from
> Sleepwalker/Lovers; ordinary personal secrets remain possible. Keep awareness, actual errands, and
> claimed excuses separate in `sim/mind.gd::answer_night` and evil cover.

## Nisha's reticence · B057

_NPC behaviour_

> **Prep B057 (9cb8782; open):** `sim/mind.gd::answer_opinion` checks low Gossip/pressure before a
> public-stance exception. Decide whether repeating public opinions bypasses reticence; do not force
> new private information or count repetitions as evidence.

## Believable public revisions · B058

_NPC behaviour_

> **Prep B058 (9cb8782; partial):** `game/workshop_canvas.gd::file` and
> `game/game.gd::workshop_retract` support historical revision/withdrawal. NPC stance changes still
> need reasons/cadence; retract endorsement while preserving underlying learned facts and private
> guesses.

## Quiet-night evidence · B059

_NPC behaviour_

> **Prep B059 (9cb8782; partial):** Quiet/protection support exists in
> `workshop/live_assessment.gd::activity_card` and `workshop/live_protection.gd::assess`; native
> `sim/world.gd::_quiet_night` grants credit too. Keep one owner and distinguish no death from a proven
> blocked attack; save receipts are separate work.

## Vote resistance feedback · B060

_NPC behaviour_

> **Prep B060 (9cb8782; open; duplicate feedback):** Reuse `sim/mind.gd::_vote_impl`'s structured
> reasons. Consolidate agree-but-no, distrust, and “what would change their mind”; check friendship,
> contradictory readings, and preferred-block refusals without introducing a second resistance score.

## Evil vote stakes beyond the Demon · B061

_NPC behaviour_

> **Prep B061 (9cb8782; design):** `sim/mind.gd::_vote_impl` specially protects the actual Demon;
> `sim/evil.gd::teammate_value`/`public_hostility` provide other stakes. Specify cover-versus-teammate
> policy before tuning; do not leak strategy truth into shadow beliefs.

## Outcome attribution · B062

_NPC behaviour_

> **Prep B062 (9cb8782; partial metrics):** `game/case_metrics.gd::summarize` separates
> identification/persuasion/outcomes. Audit event-time role/alignment for curse/Scion: reading final
> state can misattribute earlier executions. Add focused transition cases in `tools/test_outcomes.gd`
> before aggregate scores.

## From playtest 61251 · B063

_NPC behaviour_

> **Prep B063 (9cb8782; historical context):** Keep the 61251 observations, but check the children
> against current shared ownership and native voting separately. They overlap later social-tuning and
> evidence-fit work; do not implement them twice.

## A proven lie should hurt an info claimant's credibility hard · B064

_NPC behaviour_

> **Prep B064 (9cb8782; partial; coefficients undecided):** `sim/mind.gd::_honesty` reweights
> ledgers; `sim/argue.gd::effects_of` separates doubt/suspicion. Report lies, whereabouts lies, and
> poison have different scopes. Test downstream old reports, not only immediate increments.

## A Seer's record · B065

_NPC behaviour_

> **Prep B065 (9cb8782; partial):** `sim/mind.gd::_honesty` and `workshop/shared_ledger.gd::evaluate`
> already re-evaluate evidence. Narrative track records/trust need event identities; semantic
> correctness includes Red Herring/Marked registration, not just actual Demon membership.

## Repeated trace matches add up · B066

_NPC behaviour_

> **Prep B066 (9cb8782; open; aggregation duplicate):** Group with independent instances and
> generic/template parity. `sim/mind.gd::_final_weight` is max-based; trace facts need stable
> crime/night/source identities in `sim/argue.gd::assertions` and shared adaptation. Retellings are
> not new matches.

## The player's voice in votes is small at ordinary trust · B067

_NPC behaviour_

> **Prep B067 (9cb8782; design; Q3 audit):** Player terms are explicit in `sim/mind.gd::_vote_impl`;
> `execution_priority_contribution` is a separate zero-weight hook. Measure after premise design with
> wrong-accusation controls. Action modifiers are not evidence likelihoods.

## Not the cause · B068

_NPC behaviour_

> **Prep B068 (9cb8782; historical finding):** Retain this negative diagnosis, not a task to remove
> failed-nomination consequences. Use `_vote_impl`'s score parts to distinguish nominator trust,
> nominee trust, crowd pressure, and evidence in any new reproduction.

## Backing a strong case builds trust · B070

_NPC behaviour_

> **Prep B070 (9cb8782; design):** `sim/mind.gd::hear_accusation`/`_vote_impl` are social entry points.
> Define recipient and accepted-evidence credit; prevent rapport farming by repeated cases and never
> use the simulator's true verdict to decide NPC gratitude.

## More talk in town, especially in bigger towns · B072

_NPC behaviour_

> **Prep B072 (9cb8782; design; existing cap):** `sim/world.gd::_pre_pair`, `_post_pair`, `_make_pair`,
> and `sim/social.gd::converse` already limit pairings and exchange one item/direction. Separate more
> opportunities from more items; check public visibility as a distinct constraint.

## Evil backs into a bluff · B073

_NPC behaviour_

> **Prep B073 (9cb8782; open):** `sim/evil.gd::make_plan` fixes bluff assignments; `ensure_scapegoat`
> can change frames. Reactive bluffing requires persistent claims compatible with earlier reports.
> Coordinate with role requests/coherent frames; never overwrite disclosed history.

## Storyteller-driven Medium visits · B074

_NPC behaviour_

> **Prep B074 (9cb8782; design):** `sim/world.gd::_medium_choice` is mechanical recent-death selection,
> not a director. Resolve Demon-victims-only eligibility first, then define selection policy separately
> from receipt validity and fake Medium behavior.

## Medium relay: separate later social consequences · B075

_NPC behaviour_

> **Prep B075 (9cb8782; partial):** `workshop/live_assessment.gd::medium_card` preserves supported
> originals; native `sim/mind.gd::_info_effects`/social consequences differ. Test faithful relays as
> one origin, then independently test blame/trust when either source is doubted.

## Medium challenge attribution and nested relays · B076

_NPC behaviour_

> **Prep B076 (9cb8782; open):** `workshop/live_assessment.gd::medium_card` handles bounded originals;
> `workshop/canvas_model.gd::add_modifier`/UI restrict relay challenges. Nested relays need dated
> source chains, cycle checks, deduplication, and attribution before relaxing gates.

## Martyr promise versus later hanging · B077

_NPC behaviour_

> **Prep B077 (9cb8782; open; time boundary):** `workshop/live_protection.gd::assess` and
> `sim/world.gd::_martyr_choice` concern different moments. Later poison/execution cannot prove an
> earlier promise false without dated support. The merged mechanics work (`0cd2181`) added dated
> statement times and Warden guard receipts; build on those rather than duplicating them.

## NPCs push back on nominations their own information contradicts · B078

_NPC behaviour_

> **Prep B078 (9cb8782; open):** `sim/mind.gd::nomination_case`/`_good_nomination_impl` have
> own-information context; `game/game.gd::_nomination_command` handles nominations. Coordinate with
> reactive meetings for one timely contradiction, without forced disclosure or an extra belief bonus
> for speaking.

## Lie severity · B079

_NPC behaviour_

> **Prep B079 (9cb8782; design; duplicate tuning):** Compare equal hearing weights in
> `sim/argue.gd::effects_of`, `sim/mind.gd::_honesty`, and `night_sighting_scale`. Coefficients affect
> different quantities; combine with misled-versus-lie and rebuttal wording, not an isolated severity
> multiplier.

## Evil reads as evil · B080

_NPC behaviour_

> **Prep B080 (9cb8782; watch):** `sim/mind.gd::shadow_run` and `sim/evil.gd::review_scapegoat`
> preserve cover/public-information boundaries. The quoted rates are historical, not fresh
> measurements. Improve believable reason variety without exposing actual evil knowledge to the shadow.

## Role hints from workplaces and haunts · B081

_Exploration_

> **Prep B081 (9cb8782; design):** Search routing is `game/game.gd::_search`. Define eligible
> workplace/haunt locations, attribution, and frequency before adding hints; a clue must not become
> guaranteed true-role verification or read hidden roles directly into player knowledge.

## Occasional free arrival search · B082

_Exploration_

> **Prep B082 (9cb8782; knob):** `game/game.gd::_search` spends phase actions. Define ordinary versus
> evidence searches and an arrival/phase receipt first; revisiting must not reset free-search
> eligibility. Start with action-budget checks rather than broad balance runs.

## Balance pass watchlist: night sightings are too decisive · B083

_Numbers_

> **Prep B083 (9cb8782; balance dependency):** Rates/routes live in
> `workshop/live_activity.gd::_profile_paths`/`_paths`, keyed through `movement_inputs`. Group vigils,
> detours, and Lamplighter noise. Establish behavioral controls first. Demon detours are on main
> (`DEMON_DETOUR` = 0.05 in `live_activity.gd`); don't import canceled channel machinery.

## Evil sometimes tells the truth (start by faking it) · B084

_Numbers_

> **Prep B084 (9cb8782; measurement trap):** `sim/evil.gd::make_fake_info` stamps fabricated entries
> `true=false` even if content happens to be correct. Measure semantic correctness per role/world,
> including registration rules, not that flag. Then change `workshop/solver.gd::report_table` using
> measured rates and cache/parity checks.

## Unlimited Vigil strength · B085

_Numbers_

> **Prep B085 (9cb8782; design):** `game/game.gd::_night_command`/`_resolve_night` control vigils;
> `sim/world.gd::_night_sightings` supplies movement. Choose cost/yield before changing both
> observations and likelihoods. Check action accounting, empty watches, and victim exclusion before
> matched balance comparisons.

## The Lamplighter contaminates vigils and traces · B086

_Numbers_

> **Prep B086 (9cb8782; watch):** `sim/world.gd::_night_movement` and
> `workshop/live_activity.gd::_profile_paths` give Lamplighter all-block routes. Trace contamination is
> not independent corroboration. Coordinate provenance and innocent explanations before reducing
> visibility or increasing suspicion.

## Situational credence modifiers · B087

_Numbers_

> **Prep B087 (9cb8782; design):** `sim/mind.gd::reliability`, `_honesty`, and `_night_factor` differ
> from relationship hearing weight; shared validity is in `workshop/solver.gd::report_table`. Specify
> observable triggers/lifetimes and check duplicate disclosure/relay credit before adding modifiers.

## Offer trust · B088

_Numbers_

> **Prep B088 (9cb8782; watch):** Audit `game/game.gd::_offer_command`/`_settle_offers` against
> `TUNING.md`. Offered, kept, and successful protection are distinct; broken promises, secrecy losses,
> and trust caps can dominate a small gain.

## Privacy without compounding trust penalties · B089

_Tentative social tuning (Oct 20 discussion)_

> **Prep B089 (9cb8782; tentative):** `sim/mind.gd::_target_tier`, `set_trust`, and `press` combine
> disclosure/rapport inputs. Keep disclosure gates while auditing initialization and fatigue
> separately. Check new-topic versus repeated intrusive questions; this preparation does not approve
> retuning values.

## Evidence can build NPC-to-NPC trust · B090

_Tentative social tuning (Oct 20 discussion)_

> **Prep B090 (9cb8782; tentative):** `sim/social.gd::_deliver` changes bonds;
> `sim/mind.gd::apply_info`/shared evaluation change beliefs. Any reward needs original-fact/recipient
> identity. Only the listener's own-role knowledge may establish a Clerk match; hidden roles cannot
> validate reports for everyone.

## Diminishing trust changes near extremes · B091

_Tentative social tuning (Oct 20 discussion)_

> **Prep B091 (9cb8782; knob; caps separate):** `sim/mind.gd::set_trust` centralizes changes, but
> `cap_trust` lowers ceilings and `sim/world.gd::_grief` uses it. A softening curve cannot repair
> permanent caps. Agree curve and recovery policy before applying changes globally.

## Fewer trust penalties for presenting evidence · B092

_Tentative social tuning (Oct 20 discussion)_

> **Prep B092 (9cb8782; knob):** Trace `game/game.gd::_route_present`/`_talk_command` into
> `sim/mind.gd::press`/`hear_accusation`. Identify why trust fell before changing magnitude: presenting
> may also breach confidence or consume patience, which need distinct consequences.

## Opinion strength and shared origins · B093

_Tentative social tuning (Oct 20 discussion)_

> **Prep B093 (9cb8782; tentative):** `sim/mind.gd::refresh_consensus` owns pressure separately from
> evidence; `sim/social.gd::_deliver` stores private opinions. FADE/CAP are not second/third voice
> strengths. Establish source-chain deduplication before treating repeated stories as independent
> voices.

## Martyr urgency · B094

_Tentative social tuning (Oct 20 discussion)_

> **Prep B094 (9cb8782; tentative; confirmed gap):** `sim/world.gd::_martyr_choice` still uses fixed
> 0.62. Day-3 start is specified, decrement/floor remain open. Check good candidates, all-suspicious
> candidates, and late refusal; coordinate promise-time versus execution-time evidence.

## Demon victims' earlier information · B095

_Tentative social tuning (Oct 20 discussion)_

> **Prep B095 (9cb8782; partial; absolute wording stale):** Shared death evidence is finite;
> `sim/mind.gd::_recompute_beliefs` applies finite role-claim strengthening. Consolidate
> sincerity/old-report policy with earlier victim-information items. Do not restore “dead means
> certainly good.”

## Confidence should protect convictions, not create general resistance · B096

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B096 (9cb8782; design):** `sim/mind.gd::adjust`, `_recompute_beliefs`, `reconsider`, and
> `workshop/reasoner.gd::_prepare` intersect here. Define conviction before a global Confidence change;
> preserve reinforcement, firsthand knowledge, and exact retraction across native/shared ownership.

## Ward promises should outrank vigil promises · B098

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B098 (9cb8782; design):** `game/game.gd::_settle_offers` sees ward/vigil logs;
> `workshop/live_protection.gd::assess` handles uncertain evidence. Credit observable plausible success
> once, retaining alternate blockers. Do not read the actual attack target to decide gratitude.

## Reduce secret-keeping rewards and soften secret breaches · B099

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B099 (9cb8782; design):** Audit `sim/mind.gd::end_of_day_trust`/`cap_trust` and
> `game/game.gd::_break_confidences` together. Resolve recovery with apologies/confidentiality. Give
> repeated nightly rewards and breaches explicit identities before tuning amounts.

## Track incrimination versus a suspected misread explanation? · B101

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B101 (9cb8782; design):** `workshop/world_domain.gd` and
> `workshop/jury.gd::_consequences_eval` already represent registered/actual alternatives. Decide which
> explanation to expose before adding state; a parallel additive incrimination score would duplicate
> evidence and complicate revisions.

## Dowser clearing strength · B102

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B102 (9cb8782; tentative):** Generation is `sim/world.gd::_day_gifts`/`_receive_info`; fitting
> is `workshop/solver.gd::_report_content`. Define when no ping is observable: a guaranteed trigger
> with known activation can still produce a zero clear through absence.

## Make night-sighting rebuttals explicit · B103

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B103 (9cb8782; open; duplicate rebuttals):** `sim/mind.gd::night_sighting_scale` discounts
> native off-kill suspicion; shared movement can exculpate the Demon. Surface context in
> `defend_self`/replies without applying that discount twice or clearing possible Minions.

## Accumulate discrete independent instances · B104

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B104 (9cb8782; open; one aggregation project):** Group independent support, traces, and caught
> lies. `sim/mind.gd::_final_weight` is max-based; `workshop/shared_ledger.gd::endorsed_facts`
> deduplicates facts. Compare new night/source, faithful relay, repeat, and withdrawn support as
> separate acceptance cases.

## More rebuttals after a caught lie · B105

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B105 (9cb8782; open; duplicate dialogue):** Reuse false-alibi/hidden-walker incident handling
> in `sim/mind.gd::defend_self`. Innocent-secret and specific Red Herring explanations need established
> support; plausible wording is not permission to add hidden facts to a listener's case.

## Compare misled and reading-lie strength · B106

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B106 (9cb8782; design):** Native coefficients are in `sim/argue.gd::effects_of`; shared report
> validity/source honesty differ. Compare equal hearing weights with
> `tools/test_argue.gd`/`tools/test_beliefs.gd`. Doubt 0.80 is not simply a probability comparison with
> 0.50 + 0.30 suspicion.

## Signal honest observation forgetting · B107

_Social tuning and evidence follow-ups (Oct 20)_

> **Prep B107 (9cb8782; open):** `sim/mind.gd::answer_today`/`answer_night` control recollection;
> `game/game.gd::add_card` controls receipts. Honest forgetting must be an incomplete account, not a
> complete negative observation. Check metadata and spoken uncertainty together.

## Limited-use tool warnings · B109

_UI_

> **Session scope 2026-10-25 (B109):** Skipped because warning presentation is explicitly left
> open in the original tag; no new promise/consumption confirmation policy is inferred here.

> **Prep B109 (9cb8782; open UI):** `ui/main.gd::_actions_day`/`_offer_picker` expose tools;
> `game/game.gd::_night_command` spends them. Warn from actual remaining inventory, distinguish
> offering from spending, and check text commands/canceled menus too.

## Hide Unselected · B111

_UI_

> **Session scope 2026-10-25 (B111):** Skipped: no-selection, pin, and filter edge-case policy
> remains explicitly open. Selected-first ordering (B110) is separate and does not implement
> hiding.

> **Prep B111 (9cb8782; open; same batch):** Keep hide state in `ui/case_state.gd` and visibility in
> `game/board_model.gd::layout`. Define empty selection, intersecting filters, and pinned cards on
> hidden rows; hiding must not remove cards or their links.

## Long dropdowns in columns · B112

_UI_

> **Session scope 2026-10-25 (B112):** Skipped [tentative]: dropdown grouping/threshold/layout
> remains an open presentation decision.

> **Prep B112 (9cb8782; open UI):** `ui/main.gd::_list_picker`/`_people_picker` share popup
> construction. Add columns with keyboard focus, screen-edge fitting, and readable labels; check all
> helper users before changing common dimensions.

## "Stayed home" vs "none of your business" · B113

_UI_

> **Session scope 2026-10-25 (B113):** [watch] retained: no behavior change is planned by this
> entry. Home testimony and refusal evidence semantics were not altered.

> **Prep B113 (9cb8782; partial data distinction):** `workshop/live_assessment.gd::activity_card`
> treats refusal as weak context and home claims separately; `sim/argue.gd::assertions` distinguishes
> whereabouts. Check `game/board_model.gd::layout` marks before changing mechanics just for visual
> differentiation.

## From Playtest Notes 12553 · B114

_UI_

> **Session scope 2026-10-25 (B114):** Existing test_ui covers board pin/hide/unpin and
> test_town_ui covers visibility/highlight ownership. Idle visibility follows can_see public-block
> rules by code inspection. No exact remaining elimination/visibility defect was established;
> leave this historical checklist unresolved rather than redesigning guess or visibility policy.

> **Prep B114 (9cb8782; verify old examples first):** Use `tools/test_board.gd`,
> `ui/board_view.gd::_gui_input`/`_draw_pinned`, and `game/board_model.gd::layout`. Check
> pin/map/elimination examples across filters/views; preserve user pins before labeling historical
> visual reports current bugs.

## Card zoom and text extension · B115

_UI_

> **Session scope 2026-10-25 (B115):** Skipped: renderer approach is open and the rich-text
> extension is deferred; custom Canvas/Tree reflow is beyond a small fix.

> **Prep B115 (9cb8782; open; renderer decision):** `ui/board_view.gd::_draw_card_item` uses custom
> Canvas drawing/fixed geometry; `ui/card_list.gd` extends Tree. Rich text requires reflow,
> hit-testing, and caching/replacement controls. Follow `docs/text_system_handoff.md`; test zoom,
> links, and pins at several scales.

## Evidence-reading bot · B148

_3. Medium features (several days; touch a few systems)_

> **Prep B148 (9cb8782; open; confirmed oracle):** `tools/autoplay.gd::_decide` peeks at
> `w.dropped.has(g.loc)`; `_scores` uses hand weights. Remove the hidden-presence peek and add public
> trace/material reasoning before treating bot outcomes as physical-evidence balance measurements.

## Expanded dialogue and trust management · B116

_3. Medium features (several days; touch a few systems)_

> **Prep B116 (9cb8782; tentative package):** These children share incident IDs, promises, and
> public/private knowledge. Define those contracts before adding actions to `ui/main.gd::_offer_picker`
> or `game/game.gd::_talk_command`. No tuning values are approved by these notes.

## General requests can spread through town chats · B119

_3. Medium features (several days; touch a few systems)_

> **Prep B119 (9cb8782; design; request schema first):** `sim/social.gd::_pick_item`/`_deliver`
> exchange information, not general commitments. Define request identity/status before propagating it
> once per recipient; a relay does not imply a real gift-holder accepted or completed the task.

## Responsibility and useful follow-through can build trust · B120

_3. Medium features (several days; touch a few systems)_

> **Prep B120 (9cb8782; design):** Use `sim/mind.gd::set_trust` and `game/game.gd::_settle_offers` as
> patterns. Credit perceived useful follow-through once per task/outcome, not incriminating results
> or repeats; keep rapport separate from source honesty.

## Responsibility can cut both ways · B121

_3. Medium features (several days; touch a few systems)_

> **Prep B121 (9cb8782; design):** `sim/world.gd::_grief` has execution resentment;
> `game/case_metrics.gd::summarize` is truth-aware post-case diagnostics. NPC guilt needs event-time
> knowledge and attributed contribution, not metrics' hidden correctness or “execution implies
> vindication.”

## Withdraw or revise a case · B122

_3. Medium features (several days; touch a few systems)_

> **Session verification 2026-10-25 (B122):** test_workshop_live_canvas verifies heard revision
> replacement, endorsement withdrawal without independent ownership, and retained original board
> evidence. Propose closure only of the demonstrated player UI/history mechanism. Retention of
> independently heard NPC facts needs separate evidence; broader public explanations/NPC stance
> design remains skipped. Full default runner: 73/75; only permitted test_social/test_text_ui
> failures.

> **Prep B122 (9cb8782; partial; candidate to narrow):**
> `ui/live_case_workshop.gd::_withdraw_window`, `game/game.gd::workshop_retract`, and
> `game/workshop_canvas.gd::file` already support withdrawal/revision. Verify UI/ownership first;
> public explanations and NPC stance changes remain distinct from deleting facts.

## Ask what would change their mind · B123

_3. Medium features (several days; touch a few systems)_

> **Prep B123 (9cb8782; open feedback):** `sim/mind.gd::_vote_impl` provides resistance parts and
> `workshop/jury.gd` assessed explanations. Expose actionable known reasons while protecting private
> information; do not promise that fulfilling one suggestion guarantees a later vote.

## Explain an execution's purpose · B124

_3. Medium features (several days; touch a few systems)_

> **Prep B124 (9cb8782; design):** `sim/mind.gd::execution_priority` is a zero-weight extension
> point; `game/game.gd::_parse_conclusion` is proposition-based. Define information-seeking purpose
> separately so proposing an execution does not itself assert evil or raise suspicion.

## NPCs voice doubt about their own readings · B127

_3. Medium features (several days; touch a few systems)_

> **Prep B127 (9cb8782; open in part):** `sim/argue.gd::_match_pair` recognizes some flips;
> `sim/mind.gd::_night_doubt` affects beliefs. Proactive self-doubt still needs own-evidence/chronology
> triggers. Allow legitimate succession/poison alternatives without consulting actual hidden causes.

## Rebuttals and excuses · B128

_3. Medium features (several days; touch a few systems)_

> **Prep B128 (9cb8782; partial; consolidate):** Own-lie admission exists in
> `sim/mind.gd::_answer_gift_impl`; `defend_self` owns native moves. Group hidden walkers, caught-lie
> motives, and reading challenges. The merged mechanics work (`0cd2181`) maps defence moves to claims,
> secret cards and reading challenges with hearing weights; extend those, don't rebuild them.

## Medium relay credibility at both sources · B129

_3. Medium features (several days; touch a few systems)_

> **Prep B129 (9cb8782; partial; two paths):** Native Medium expansion is `sim/mind.gd::_info_effects`;
> shared originals use `workshop/live_assessment.gd::medium_card` and
> `workshop/solver.gd::report_table`. Check both sources and dates. A faithful relay cannot be an
> independent corroborating origin.

## Trust dynamics around sources (later) · B130

_3. Medium features (several days; touch a few systems)_

> **Prep B130 (9cb8782; design; later):** `game/game.gd::_disclose` records `via`;
> `sim/social.gd::_deliver` forwards claims. Anonymous-source inference and retaliation need an
> attribution policy first. Do not identify an unnamed reader from hidden real role assignments.

## Last words · B131

_3. Medium features (several days; touch a few systems)_

> **Prep B131 (9cb8782; open flavor):** Hook between the final decision in `game/game.gd::_after_vote`
> and `sim/world.gd::execute`, respecting Martyr substitution. Final words must not expose true
> role/alignment; execution and aftermath must still occur exactly once.

## Nominations make a case · B132

_3. Medium features (several days; touch a few systems)_

> **Prep B132 (9cb8782; partial):** `sim/mind.gd::nomination_case`/`case_against` collect reasons;
> `game/game.gd::_show_nomination` displays events. Cite actual known cards and count only newly heard
> facts; a flavor recap must not reapply existing evidence effects.

## Meeting and vote talk · B133

_3. Medium features (several days; touch a few systems)_

> **Prep B133 (9cb8782; open; meeting batch):** `sim/mind.gd::_vote_impl` records reasons;
> `game/game.gd::_after_vote` displays results. Use those records for selective explanations/reactive
> replies, including varied evil cover reasons; never rerun votes to obtain better dialogue.

## Fading into the crowd · B134

_3. Medium features (several days; touch a few systems)_

> **Prep B134 (9cb8782; design):** `sim/mind.gd::_public_claim_decision` already weighs
> disclosure/repeated gift value. Coordinate crowd/salience input with reactive meetings, preserving
> timely contradictions and willingness gates; avoid two contradictory speaking decisions.

## Outing yourself to defend someone · B135

_3. Medium features (several days; touch a few systems)_

> **Prep B135 (9cb8782; design):** `sim/mind.gd::defend_self`/`_public_claim_decision` support some
> self-disclosure. Defending another needs known clearing evidence and one public event; availability
> must not reveal an undisclosed true gift.

## Talking to a group · B136

_3. Medium features (several days; touch a few systems)_

> **Prep B136 (9cb8782; design):** `game/game.gd::_talk_command` has one target and conversation-scoped
> costs/repeats. Define membership, shared hearing, and phase budget before UI target changes;
> switching people must not reset the group allowance.

## Revenant seeks execution · B137

_3. Medium features (several days; touch a few systems)_

> **Prep B137 (9cb8782; open; split AI tasks):**
> `sim/evil.gd::place_totem_now`/`sim/world.gd::_revenant_curse` implement lifecycle. Seeking execution
> and NPC searches need separate strategy/action paths. Preserve voter uncertainty; good NPC search
> choices must not read hidden totem locations.

## NPCs find evidence and personal items · B138

_3. Medium features (several days; touch a few systems)_

> **Prep B138 (9cb8782; open):** `game/game.gd::_search` is player-oriented;
> `sim/social.gd::_pick_item` lacks a general physical-evidence inventory. Define discovery receipts,
> provenance, and cost before NPC searches; retelling a discovery is not a second observation.

## Ways to discover and confront secrets · B140

_3. Medium features (several days; touch a few systems)_

> **Prep B140 (9cb8782; design):** `sim/world.gd::_assign_secrets` sets secrets;
> `game/game.gd::_secrets_used`/`_break_confidences` handle leverage/cost. Define discoverable
> attributed claims before secret cards; do not populate player knowledge directly from hidden
> assignments.

## Named corroborators in alibis · B141

_3. Medium features (several days; touch a few systems)_

> **Prep B141 (9cb8782; design):** `sim/mind.gd::answer_night` emits alibis; `sim/evil.gd::make_plan`
> stores cover. Add named corroborator/date, then an independently heard reply. Two names on one
> person's statement are not two witnesses.

## Evidence chains · B142

_3. Medium features (several days; touch a few systems)_

> **Prep B142 (9cb8782; design; movement dependency):** `sim/world.gd::_maybe_drop`,
> `game/game.gd::_search`, and `sim/argue.gd::assertions` cover clues. Settle trace origin/movement
> first; retain discovery identity so revisits/relays do not multiply chained evidence.

## Evil coordination you can see · B143

_3. Medium features (several days; touch a few systems)_

> **Prep B143 (9cb8782; partial):** `sim/world.gd::_pre_pair`/`_make_pair` and
> `sim/social.gd::converse` already produce visible encounters and private evil intel. Specify
> additional coordination against normal friend meetings; separate the observed encounter from secretly
> exchanged content.

## Throw a teammate under the bus · B144

_3. Medium features (several days; touch a few systems)_

> **Prep B144 (9cb8782; design):** `sim/evil.gd::teammate_value`/`public_hostility` and
> `sim/mind.gd::_vote_impl` govern stakes. Bussing needs observable cover benefits and persistent
> stance history; preserve prior reports and keep teammate calculations out of good listeners'
> reasoning.

## Claims/reveals timeline · B145

_3. Medium features (several days; touch a few systems)_

> **Prep B145 (9cb8782; partial data):** `game/game.gd::_disclose` stores learned histories;
> `ui/profile_panel.gd::_render_entries` renders attribution. Reuse receipts for the new timeline,
> distinguishing observed versus disclosed time; location marks alone cannot represent both.

## Dialogue voices for the rest of the cast · B146

_3. Medium features (several days; touch a few systems)_

> **Prep B146 (9cb8782; open content):** Inspect `sim/dialogue.gd`, `sim/dialogue_voices.gd`,
> `ui/dialogue_lab.tscn`, and `tools/dialogue_scenarios.gd`. Keep approved facts/intent IDs stable
> while varying lines; test semantic facts and repeats rather than identical wording for every speaker.

## Bot coverage of the new talk options · B147

_3. Medium features (several days; touch a few systems)_

> **Prep B147 (9cb8782; open prerequisite):** `tools/autoplay.gd::_decide` does not cover the whole
> talk/offer toolbox. Add observable decision coverage/counters before using bot outcomes to measure
> those features; passive runs do not exercise active offers/haunts.

## The Revenant can hide a new totem each day · B149

_3. Medium features (several days; touch a few systems)_

> **Prep B149 (9cb8782; open signposting; lifecycle built):**
> `sim/world.gd::find_totem`/`start_new_day` and `sim/evil.gd::place_totem_now` already permit
> replacement. Add burn-receipt warning; separately check burn → replacement → execution/curse without
> implying permanent safety.

## The ward as evidence, and a visible save · B150

_3. Medium features (several days; touch a few systems)_

> **Prep B150 (9cb8782; open in part):** `game/game.gd::_morning_report` puts ward metadata on quiet
> cards but has no standalone ward/save receipt. Add spent door/night and separately observable
> scorched outcome; coordinate quiet/protection adapters to count one save once.

## Reactive meetings: speak up when the last statement concerns you · B151

_3. Medium features (several days; touch a few systems)_

> **Prep B151 (9cb8782; open; scheduling contract):** Use
> `game/game.gd::_start_meeting`/`_nomination_command` and `sim/mind.gd::_public_claim_decision`.
> Preserve queued refresh boundaries and one audience capability pass/command; relevance checks must
> not trigger another world evaluation per reply.

## Seen at night away from the murder · B152

_3. Medium features (several days; touch a few systems)_

> **Prep B152 (9cb8782; updated after merge `0cd2181`; partial):** `workshop/live_activity.gd` now
> gives the Demon a small detour chance (`DEMON_DETOUR` = 0.05), so an off-route sighting argues strongly
> but not absolutely against the killer; native `sim/mind.gd::night_sighting_scale` still serves
> native-owned paths. Remaining: distinguish Demon exclusion from possible Minion guilt and surface the
> same model in replies.

## Corroborated walking-gift claims · B153

_3. Medium features (several days; touch a few systems)_

> **Prep B153 (9cb8782; partial numerical support):** `workshop/live_activity.gd::_profile_paths`
> already distinguishes Lamplighter all-block routes from Minion errands. Explain those inputs without
> a second innocence bonus. Optional vibes weight belongs to the separate gated-impressions design.

## Votes and nominations ignore rank (Q3 pass) · B154

_3. Medium features (several days; touch a few systems)_

> **Prep B154 (9cb8782; design; Q3 deferred):** `sim/mind.gd::_good_nomination_impl` walks rank;
> `_vote_impl` uses an absolute bar plus `prefers_block`. `sim/content.gd` keeps shared
> execution-priority weight zero. Decide rank/urgency/premise policy, then test strong first, close
> second, and wrong moderate cases.

## Supporting evidence in a case: logical where possible, vibes where not · B155

_3. Medium features (several days; touch a few systems)_

> **Prep B155 (9cb8782; design):** `workshop/jury.gd::_consequences_eval` currently takes the larger
> logical/pattern signal. Action factors and gated impressions are not that implementation. Define
> separate retractable ownership first, keeping accusations/opinions outside evidence and action rates
> measured.

## Observable actions go in the evaluator as soft evidence · B156

_3. Medium features (several days; touch a few systems)_

> **Prep B156 (9cb8782; open; measure first):** `sim/world.gd::vote_pending` emits public vote
> receipts; `workshop/live_assessment.gd::activity_card` adapts them as context. Instrument
> action/target identities and rates before likelihood changes; do not also retain an independent
> native bump for the same evidential action.

## Listener impressions go in a second stage gated on the first · B157

_3. Medium features (several days; touch a few systems)_

> **Prep B157 (9cb8782; design; ownership risk):** `game/workshop_ownership.gd::_refresh` retracts
> one joint vector. Stage 2 needs a separate reversible contribution from a frozen post-stage-1
> snapshot, without self-suspicion feedback. Define split presentations, revisions, and withdrawal
> before choosing weights.

## Existing hook · B158

_3. Medium features (several days; touch a few systems)_

> **Prep B158 (9cb8782; verified hook):** `workshop/jury.gd::_consequences_eval`/`_pattern` are the
> implementation points. Replacing max with addition alone would double-count overlaps. Classify
> logical actions/impressions and deduplicate origins across both stages first.

## Cases instead of proofs: the player argues a theory · B159

_4. Major structural work (a week or more; design first)_

> **Prep B159 (9cb8782; partial; milestone stale):** Case canvas/shared evaluation already exist in
> `game/workshop_canvas.gd`, `workshop/canvas_model.gd`, and `workshop/shared_ledger.gd`. Treat this as
> an umbrella with remaining gaps, not a fresh rewrite. Current migration documentation supersedes the
> old “next after reset” sequencing.

## The problem · B160

_4. Major structural work (a week or more; design first)_

> **Prep B160 (9cb8782; partial):** `game/game.gd::file_deduction` integrates shared cases;
> `sim/argue.gd::check` still provides templates/compatibility. Reproduce generic/template
> discrepancies against the actual delivery path before changing a coefficient in only one evaluator.

## The direction · B161

_4. Major structural work (a week or more; design first)_

> **Prep B161 (9cb8782; partial):** `workshop/canvas_model.gd` compiles partial
> cases/answers/assumptions for the solver. Live premises remain bounded; generic innocent secrets
> and a particular Seer Red Herring stay unsupported unless established, consistent with the later
> mechanics decisions.

## One fit check per evidence type · B162

_4. Major structural work (a week or more; design first)_

> **Prep B162 (9cb8782; partial; absolute wording stale):** `workshop/solver.gd::_report_content`
> provides family fit checks; `workshop/world_domain.gd` supplies alternatives. Demon death is strong
> finite evidence, not certain goodness. Check generator/adapter/solver consistency per family before
> adding templates.

## Against flooding the zone · B163

_4. Major structural work (a week or more; design first)_

> **Prep B163 (9cb8782; partial):** `workshop/shared_ledger.gd::roots`/`endorsed_facts` preserve
> canonical origins. “Same source once” must not erase new dated reports. Check origin repeats,
> multiple nights, dependent relays, contradictions, and withdrawal before adding surprise weights.

## NPCs judge the player's theory; they don't search for theories · B164

_4. Major structural work (a week or more; design first)_

> **Prep B164 (9cb8782; partial; canceled-work boundary):** Current jury/reasoner judge bounded cases
> with shared ownership; attention still affects the evidence set. Use premise salience to clarify
> listener work. Do not restore per-person latent-channel evaluations or the canceled full hypothesis
> rewrite.

## Keep · B165

_4. Major structural work (a week or more; design first)_

> **Prep B165 (9cb8782; constraint):** Retain `sim/argue.gd` links, `game/game.gd::add_card`
> identities, provenance, and `sim/mind.gd::shadow_run`. A template bonus must not add another
> likelihood for facts already owned by the posterior; filing help and belief weight differ.

## Bonuses · B166

_4. Major structural work (a week or more; design first)_

> **Prep B166 (9cb8782; partial UI; oracle risk):**
> `ui/live_case_workshop.gd`/`ui/workshop_comparison.gd` preview assessments;
> `game/game.gd::set_guess` stores private guesses. Align supports/contradicts with
> qualitative-preview policy; guesses must not silently become public facts or endorsement
> assumptions.

## Where it plugs in · B167

_4. Major structural work (a week or more; design first)_

> **Prep B167 (9cb8782; partial):** `game/game.gd::_meeting_command`/`_route_present` and
> `ui/main.gd::_refresh_actions` already accept case presentations. Reuse the delivery path with
> explicit public endorsement and queued refresh, rather than a parallel argument executor.

## Considered and not chosen · B168

_4. Major structural work (a week or more; design first)_

> **Prep B168 (9cb8782; parked alternative):** Keep the explicit non-choice. Experimental
> `workshop/channel_likelihood.gd` is not authorization to revive canceled validation. A future
> hypothesis prototype needs separate scope and measured cost/benefit; this preparation does neither.

## Related cheap idea, can come first · B169

_4. Major structural work (a week or more; design first)_

> **Prep B169 (9cb8782; partial hook; deferred activation):**
> `sim/mind.gd::execution_priority_contribution` exists with zero coefficient in `sim/content.gd`.
> Resolve Q3 rank/urgency/premise design and wrong-nomination controls before activation. Do not
> invent another hook or conflate action priority with belief.

## Pattern-based cases · B170

_4. Major structural work (a week or more; design first)_

> **Prep B170 (9cb8782; partial infrastructure):** Reuse `workshop/canvas_model.gd`/live adapters and
> actual phases from `sim/evil.gd::breath_target`. Start one report-only prototype. Unknown whereabouts
> and synthetic summaries must not become negative proof or duplicate underlying sightings.

## Night movement and trace model · B171

_4. Major structural work (a week or more; design first)_

> **Prep B171 (9cb8782; design; semantics first):** Generation is
> `sim/world.gd::_night_movement`/`_walk`/`_maybe_drop`; interpretation is
> `workshop/live_activity.gd::_paths` and `sim/argue.gd::_match_route`. Settle
> origin/detour/destination wording before evidence chains. Main now has Demon detours (5%) as well
> as direct kill routes (merge `0cd2181`).

## Locations as evidence, from both sides · B172

_4. Major structural work (a week or more; design first)_

> **Prep B172 (9cb8782; open in part):**
> `sim/argue.gd::assertions`/`workshop/live_assessment.gd::activity_card` already adapt some
> location-bearing cards. Ability groups and visit absences need explicit completeness semantics.
> Visits omit people at home; hearsay/incomplete recollections cannot create the same exclusion.

## Passing through vs. stopping · B173

_4. Major structural work (a week or more; design first)_

> **Prep B173 (9cb8782; design):** `sim/world.gd::_night_sightings` records observations;
> `sim/argue.gd::_match_route` interprets routes. Define observer ability to identify
> transit/destination before metadata changes. All-block adjacency collapses many distinctions;
> preserve old-log interpretation.

## Breathstealer confirms the good · B174

_4. Major structural work (a week or more; design first)_

> **Prep B174 (9cb8782; design; absolute diagnosis stale):** `sim/evil.gd::breath_target` targets good
> NPCs, but public silence already has finite native/context impact. Choose teammate targeting,
> concealment, or both, then change generation and interpretation together; do not restore certainty
> from silence.

## Breathstealer ambiguity, two more routes · B175

_4. Major structural work (a week or more; design first)_

> **Prep B175 (9cb8782; design; same decision):** Optional use/innocent silence changes observation
> generation too. Coordinate `sim/evil.gd::breath_target`, `sim/world.gd::begin_meeting`, and public
> receipts; do not add an invisible exception only in the evaluator.

## Relationships · B176

_4. Major structural work (a week or more; design first)_

> **Prep B176 (9cb8782; design):** `sim/world.gd::_assign_relationships`/`_assign_secret_mod` and
> `sim/npc.gd` own setup state. Relationship variants need disclosure/grief policy before inference
> support. Reuse learned relationships instead of exposing all setup links.

## Roster expansion · B177

_4. Major structural work (a week or more; design first)_

> **Prep B177 (9cb8782; design; cross-system checklist):** Definitions are
> `sim/content.gd`/`sim/gifts.gd`, generation `sim/world.gd::_receive_info`, bluffing
> `sim/evil.gd::make_fake_info`, fitting `workshop/solver.gd`. Include hints, adapters, UI, fake paths,
> and ownership tests; dropdown names alone are not support.

## A demon that kills during the day · B178

_4. Major structural work (a week or more; design first)_

> **Prep B178 (9cb8782; design):** `sim/world.gd::resolve_night`/`attack_outcome` and
> `workshop/live_protection.gd::assess` assume today's night attack process. Define public death
> time/cause and quiet-night alternatives first; new Demon rules must change protection interpretation
> consistently.

## The demon lures a victim elsewhere · B179

_4. Major structural work (a week or more; design first)_

> **Prep B179 (9cb8782; design):** `sim/world.gd::_kill`/`_night_movement`,
> `game/game.gd::_morning_report`, and live adapters couple victims/scenes/routes. Lures need explicit
> crime location separate from home, consistent traces/protection reach, and old-log compatibility.

## Player toolbox · B180

_4. Major structural work (a week or more; design first)_

> **Prep B180 (9cb8782; design):** `game/game.gd::_night_command`, `_search`, and `_outcome_text` are
> tool/victory seams. Define charges, observable receipts, alternate win, and false-result behavior
> before UI. Keep toolbox exploration separate from current ward receipt cleanup.

## Scoring system · B181

_4. Major structural work (a week or more; design first)_

> **Session verification 2026-10-25 (B181):** test_outcomes and test_fixes._summary verify
> identification/loss/Martyr/initial-Demon attribution. Propose narrowing, not closing the [open]
> scoring design. Exact-gift/confidence design is skipped. Surprise: execution history still reads
> final role/alignment, so transition attribution remains unresolved. Full default runner: 73/75;
> only permitted test_social/test_text_ui failures.

> **Prep B181 (9cb8782; partial; candidate to narrow):** `game/case_metrics.gd::summarize`/`aggregate`
> already report identification, minion ID sets, and loss categories; `tools/test_outcomes.gd` covers
> outcomes. Exact-gift credit, confidence, and Scion/event-time attribution need explicit rules. ID
> correctness is not exact-role accuracy.

## Storyteller/director and solvability check · B182

_4. Major structural work (a week or more; design first)_

> **Prep B182 (9cb8782; design):** `sim/world.gd::_receive_info`/`sim/evil.gd::make_fake_info` feed
> deterministic replay. Define solvability from reachable public evidence in a bounded diagnostic
> first. A truth-aware director must not leak solutions into beliefs or silently alter reports already
> heard.

## Procedural town · B183

_4. Major structural work (a week or more; design first)_

> **Prep B183 (9cb8782; design; topology assumptions):** `sim/content.gd` defines places,
> `sim/world.gd::_walk` uses topology, and `game/board_model.gd::layout`/map UI expect current rows.
> Inventory route/material/home/UI assumptions first; validate reachability and seed determinism before
> balance conclusions.

## Larger towns (12–15) · B184

_4. Major structural work (a week or more; design first)_

> **Prep B184 (9cb8782; watch; scaling risk):** `workshop/world_domain.gd`,
> `workshop/role_constraints.gd`, jury, setup, and UI target 7/10-person models. Benchmark isolated
> solves/refreshes first; avoid multiplying all role-holder masks or per-person theories when adding
> towns.

## NPC memory and recency bias · B185

_4. Major structural work (a week or more; design first)_

> **Prep B185 (9cb8782; design):** `sim/dialogue.gd::compose` remembers wording;
> `sim/mind.gd::ledger_hear` retains facts and `refresh_consensus` fades pressure. Decide what decays
> before applying recency globally. Forgetting wording must not retract evidence or create an absence.

## Dead NPCs · B186

_4. Major structural work (a week or more; design first)_

> **Prep B186 (9cb8782; watch; no action):** `sim/world.gd::seats`, `vote_order`, and `vote_pending`
> define current voters. Preserve the explicit no-ghost-votes decision; dead-source credibility/Medium
> work is not permission to add voting rights.

## Time-scoped Revenant possession premise · B187

_Template gaps (NYI)_

> **Prep B187 (9cb8782; updated after merge `0cd2181`; built, verify):** The accepted design
> (public eligible voters, one hypothetical turnee, bounded epochs) is on main in
> `workshop/chronology.gd` and the live assessment. Candidate to close after a cursed-game playtest and
> a passive cost check; growth stays bounded to curse histories and the actual victim stays private.

## Succession breaks earlier clears · B188

_Template gaps (NYI)_

> **Prep B188 (9cb8782; partial guard):** `sim/argue.gd::assertions` marks possible succession;
> `sim/world.gd::execute` actually requires the Demon and healthy Scion. Possibility is not
> confirmation. Shared chronology needs dated identity alternatives; check old clears across qualifying
> hangings without reading the hidden successor.

## Same person in repeated Seer yeses, later proven good · B189

_Template gaps (NYI)_

> **Prep B189 (9cb8782; design):** `workshop/solver.gd::_report_content` models Seer registration; live
> conclusions do not identify a particular Red Herring. Repeated yeses plus finite innocence do not
> prove that identity. Keep hypotheses unsupported unless established, retaining
> poison/lie/Marked/succession alternatives.

## Evil reading on a proven-good person · B190

_Template gaps (NYI)_

> **Prep B190 (9cb8782; partial model):** `workshop/world_domain.gd`/`workshop/solver.gd` distinguish
> registered evil; `workshop/live_assessment.gd::CONCLUSIONS` now has 15 types (merge `0cd2181`); generic
> innocent secrets and a specific Red Herring stay unsupported by decision. A finite
> clear plus an evil report does not force Marked. Test alternatives before adding builder premises.

## Minion gifts in templates · B191

_Template gaps (NYI)_

> **Session verification 2026-10-25 (B191):** Totem adapter absence is verified resolved (B034).
> Current main has expanded conclusion adapters, but not every typed-minion pattern is established
> by that test. Broader pattern work requiring workshop changes is skipped. Full default runner:
> 73/75; only permitted test_social/test_text_ui failures.

> **Prep B191 (9cb8782; partial; adapter diagnosis stale):**
> `workshop/live_assessment.gd::activity_card` now adapts silence/totems, but typed-minion conclusions
> remain unsupported there. Native labels do not create typed worlds. Coordinate role confirmations with
> the merged role/notrole premises (`0cd2181`).

## Breathstealer by presence · B192

_Template gaps (NYI)_

> **Prep B192 (9cb8782; design; duplicate pattern):** `sim/evil.gd::breath_target` can act any day
> phase; `sim/world.gd::begin_meeting` applies silence later. Evening-only intersection is unsound.
> Track possible dated contacts/unknown coverage; start the report-only presence prototype described
> above.

## Night companions of the proven evil · B193

_Template gaps (NYI)_

> **Prep B193 (9cb8782; design; weak association):**
> `sim/world.gd::_night_sightings`/`workshop/live_activity.gd` include innocent routes too. Role
> confirmation remains dated testimony. Shared presence must not imply guaranteed teammates or gain new
> weight each time a relay repeats it.

## A Medium's relayed sighting vs the dead's known vantage · B194

_Template gaps (NYI)_

> **Prep B194 (9cb8782; partial):** `workshop/live_assessment.gd::medium_card` retains supported
> source/time; `sim/world.gd::_medium_item` and `sim/evil.gd::_fake_medium_item` generate relays. Check
> the original observer's claimed duty/vantage then, not the Medium's later location or hidden real
> role.

## Accounting · B195

_Template gaps (NYI)_

> **Prep B195 (9cb8782; open in part):**
> `workshop/solver.gd::_report_content`/`workshop/live_activity.gd` score supported counts/movement;
> native rules are `sim/argue.gd::_match_groups`. Complete accounting must distinguish negative alibis
> from refusals and preserve Lamplighter self-exclusion.

## Role confirmations · B196

_Template gaps (NYI)_

> **Prep B196 (9cb8782; partial):** `sim/argue.gd::_match_support` has Clerk `claim_backed`;
> `_match_pair` covers Gravedigger disagreement. General positive confirmation needs dated
> reliability/live premises; another claimant's report is not revelation of hidden true role.

## Duty claim vs reading · B197

_Template gaps (NYI)_

> **Prep B197 (9cb8782; partial; duty fix present):** `sim/mind.gd::answer_night` now emits claimed
> Medium/Warden duties consistently; `sim/argue.gd::assertions` handles destinations. A hearth embedded
> in a Medium reading still needs link/movement propagation with original observation time and relay
> provenance.

## Walker's sightings vs the Lamplighter count · B198

_Template gaps (NYI)_

> **Prep B198 (9cb8782; open; accounting family):** `sim/argue.gd::assertions` emits out/watch facts;
> `workshop/solver.gd::_report_content` checks reports. Use one count/set consistency rule with exact
> night/source/completeness. Lamplighter self-omission is not automatically a contradiction.

## NPC at evening location vs. murder evidence trace originating from a different location · B199

_Template gaps (NYI)_

> **Prep B199 (9cb8782; partial):** `sim/argue.gd::assertions` and
> `workshop/live_assessment.gd::activity_card` expose evening-presence/trace inputs. Check phase/crime
> night and generator contamination alternatives. Group with conversation/trace examples rather than
> inventing a second trace rule.

## Evening sightings and conversations vs the scene trace · B200

_Template gaps (NYI)_

> **Session verification 2026-10-25 (B200):** Both location facts and shared conversation/sighting
> parity are verified. A focused probe found that native Argue.check returns only one trace-match
> subject: its template-plus-cards dedup key omits the person. Keep the full native linking item
> open; only the blanket absence-of-location assertion is disproved. No judge/link behavior
> changed. Full default runner: 73/75; only permitted test_social/test_text_ui failures.

> **Prep B200 (9cb8782; candidate to narrow; stale assertion):** `sim/argue.gd::assertions` already
> emits locations for both conversation participants; `workshop/live_assessment.gd::activity_card`
> adapts evening conversations as movement evidence. Recheck the exact link/preview example; any
> remaining gap is a specific route/UI issue.

## Protection + quiet night + sighting · B201

_Template gaps (NYI)_

> **Prep B201 (9cb8782; partial; receipt dependency):** `workshop/live_protection.gd::assess` and
> quiet-card ward metadata already give bounded support. Build standalone spent-ward/save receipts
> first, then links/replies. Keep innocent walkers, withheld attacks, false claims, and alternate
> blockers; do not double-credit one quiet outcome.
