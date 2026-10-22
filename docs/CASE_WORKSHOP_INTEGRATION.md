# Main-game integration

The bounded Workshop experiments are the reference implementation, not a replacement
already running in the main game. Integrate in verified vertical steps:

The pre-integration reference is commit `5d30513`. The [checkpoint and portable
specimens](CASE_WORKSHOP_CHECKPOINT.md) describe what must survive an interpreter change.
The read-only `Game.workshop_snapshot` API provides a portable evidence contract,
capability issues and hidden-state isolation checks. A restricted live comparison now
consumes that contract for Surveyor, Rumormonger and Dowser cases. An experimental shared
owner can now replace certified legacy suspicion for that restricted evidence set. It is
off by default and can be enabled in the live canvas without Debug, or in the developer
inspector. Stages 1–4 and a restricted live canvas are implemented within the reading
scope below. Broader mechanic adapters and ordinary multi-case playtesting remain.

## Live canvas

**More → Case Workshop** opens the live editor. A board card's right-click menu also
offers **Add to Case Workshop**, which opens and selects that original receipt. This
first version preloads all non-deduction board evidence; hidden cards are player-known
and remain available. Native filed deductions are not imported as graph nodes: their
old flat form cannot recover answers or branch semantics. The old fixture canvas is
still available through `ui/case_workshop.tscn` with F6.

1. Add a premise, answer supported readings, and link evidence or supporting premises.
   Disconnected cards are scratch work. Dragging and layout supply no evidence.
2. Inspect the **whole-case support label**. Enable **Experimental reading evaluator**
   to apply the new restricted model for this case; opening the editor alone leaves it off.
   This switch does not enable spoilers or disable identification scoring.
3. **Preview effectiveness** is a manual, read-only neutral reference. It uses the same
   full graph and live capability gate as presentation. Unsupported cases have no new-
   model numeric preview and no claimed prediction of the native fallback.
4. **File / update case** retains the graph as a native board deduction with an exact
   original-receipt mapping. It preserves answers, assumptions, intermediate claims,
   branch-removal provenance, quoted conflicts and all future unsupported choices.
   Filing alone changes no listener beliefs. Each premise keeps its filed board number
   across revisions; a listener replaces the old endorsement only upon hearing the revision.
5. Present during an actual conversation, meeting or nomination. The button uses the
   current context, not an unrestricted mock audience. Private presentations consume
   normal questions; the floor remains once per meeting; nomination speech remains one
   statement with normal social effects. Accuse/defend chooses the social stance toward
   the nominee; it does not rewrite the case's headline.
6. The result window names each delivered listener's **new shared evaluator** or
   **fallback: existing rules**. Listener-dependent incompatibility is reported without
   exposing their private evidence or alignment. Rejected/expired actions give no
   delivery record and direct the player to the ordinary conversation log.

The capability label covers Surveyor/Rumormonger/Dowser readings at supported acquisition
times, original-alignment claims, selected answers and scoped identity assumptions. It
does not promise that every listener can combine them with their existing knowledge:
source/receipt ownership, credibility budgets and public temporal history can require
fallback. Numerical shared effects use the original reports once; chosen answers are
hypotheses assessed in the scoped response, never additional facts or extra bonuses.

**Unsupported evidence is usable. It is never silently omitted from an asserted case.**
Every unsupported card is labeled, and including it flags the whole connected case.
Movement, trace, alibi disputes, additional role claims/home cards as separate premises,
outing explanations/citations, impairment hypotheses, changed-alignment histories and
composing a canvas graph inside a separate legacy deduction remain outside the new
live evaluator. Even a linked role claim that seems redundant is explicitly flagged.
Reading conflicts presented as the headline are supported without assigning guilt.
Embedded conflict questions remain flagged: ownership can distinguish quotation from
endorsement, but the scoped response's attention needs a quoted-evidence adapter before
it can assess them together with a different headline. Present the conflict separately
to use the new evaluator. Live movement/alibi conflicts also fall back and do not inherit
the fixture's experimental 2× factor.

The fallback uses the **headline plus original cards** through the existing argument
system. It does **not** interpret canvas answers, assumed identities, intermediate
claims or link meanings. This loss is stated before presentation, and actual fallback
is labeled afterward. A mixed inseparable case is not partially evaluated by dropping
unsupported evidence. An absent/deleted/changed original receipt blocks filing instead
of submitting fewer roots. Independent reasoning lines with different evaluators are
not implemented yet.

Draft layouts/answers and filed-number mappings are retained in memory only for the
running case, including closing/reopening the window and refreshing new board evidence.
Starting a new case, even the same seed, clears them and resets effects off. There is
no live draft disk export/import in this slice. **Withdraw endorsement…** is explicitly
a developer testing tool: it retracts that case's shared/native canvas contribution for
the selected listener while retaining independently learned evidence. It is not an
in-character retraction conversation or a reversal of past trust/social effects.

Town presentations yield between listeners and show progress. Individual assessments
remain synchronous. Other game commands and a new-case action are locked until the
presentation finishes, keeping one ordinary command/trace boundary. Typed presentations
still use the synchronous command handler. A ten-person native-generated reading case
took approximately 29 seconds for the first town presentation on the development machine;
this is a measured limitation, not the earlier one-listener timing extrapolated to town.

`workshop_canvas_filed` traces retain the full submitted graph and resolved board roots;
`workshop_delivery` records actual model/fallback feedback for every recipient, and
`workshop_presentation` retains shared assessments, novelty and ownership. The live canvas
suite covers native-generated gifts, private → meeting → nomination → execution/night,
floor/question/statement limits, progress action locking, mixed-case fallback/recovery,
stable revisions, missing receipts, main-menu/context entry points and case resets.

## Try the live comparison

Open **More → Live Workshop comparison** in the main game. To inspect private NPC
responses, enable the existing **Debug** control; its normal identification-scoring
warning still applies. Choose a filed deduction and listener, then **Inspect now**.
The optional recording checkbox also captures comparisons when actual deductions are
presented privately, to the meeting, or during nomination speech. All three venues use
one comparison adapter. The detailed trace stores the captured input, actual named
presentation model, read-only proposal, capability issues and elapsed time. With shared
effects disabled, the actual result is the original legacy result; with them enabled it
can be the applied shared assessment. No hypothetical legacy result is fabricated. Recording is off by
default and adds work only when enabled; the panel keeps the most recent 24 records.
Each comparison also audits overlapping legacy reading entries and potentially
dependent arguments. Distinct receipts sharing an old source/day/role key are exposed
as ambiguous identities. Ordinary testimony is not treated as a gift-reading dependency.
Ambiguous original reading identities defer numeric comparison. These diagnostics do
not grant permission to delete or suppress any old entry.

The live model enumerates legal original alignment worlds and all four public modifier
kinds. Non-Marked worlds have no Marked person; Lovers have two good holders. Accepted
healthy readings exclude a Delusional source. Healthy role claims must be compatible
with unique gifts and the listener's own known gift. Modifier identities and actual
poison/curse targets are never read from the simulation for inference.
The listener retains public known-good Demon victims and Martyr participants even if
their process cards are not cited. Working-gift branches respect first-night-only
Surveyor/Rumormonger acquisition and daytime Dowser acquisition.

One native exception matters: Rumormonger excludes itself when choosing a modifier
holder. If it is the sole holder, a working gift can generate an arbitrary fallback
pair/secret. The live model retains that explanation without establishing the reported
pair or modifier type. This is tested against `_receive_info`, not inferred from a
handwritten special-case fixture. The fixed Workshop validator's assumption that report
contents are accurate is stronger than merely having a working gift in this situation.
Changing the native fallback is recorded as a separate open backlog decision.

Comparisons are conditional on report credibility and health, use full reasoning, and
retain the Workshop's experimental weights. They support up to eight reading receipts,
six claims and 64 credibility combinations for seven- or ten-person towns. Nested filed
deductions retain their original evidence and scoped intermediate claims. Unsupported
roles, live movement/trace likelihoods, incomplete payloads and public conversion history
produce explicit non-numeric results. The complete live health/poison history is not
modeled. Report, observation and learning times remain distinct; original report time
can remain unknown when a legacy relay receipt does not record it.

Venue is recorded but the comparison proposal is unscaled; the real original result keeps
its actual venue scaling and social side effects. Read-only comparison proposals use the
captured existing beliefs, which can contain legacy reading effects: they must not be
added directly. Comparison recording never applies a proposal. Shared ownership below
uses a separate, cleaned baseline and total-evidence assessment. Existing evil cover minds are
captured without creating or syncing them; a missing cover mind yields an unsupported
result. Comparisons remain a developer tool rather than an alternate gameplay mode.

Tests exercise public legal domains, all modifier types, distinct world/cache keys,
healthy unique gifts, hidden-truth independence, no preview mutation, original behavior
and RNG equivalence across all venues, JSON checkpoint replay and the actual inspector.
The initial one-reading benchmark was roughly 0.2 seconds for seven people and 1.6
seconds for ten on this machine; that is not a whole-town or large-case latency claim.
See [performance and migration options](CASE_WORKSHOP_PERFORMANCE.md).

## Shared ownership and retraction (experimental)

In **More → Live Workshop comparison**, enable Debug and select **Experimental shared
reading effects** to apply the supported joint model. This is a per-case developer
experiment and resets off for a new case. The switch recomputes existing supported raw
readings; subsequent raw readings and deduction presentations refresh automatically.
Private, meeting-floor and nomination deductions register the same endorsement identity.
Disabling retracts the shared layer and restores the native ledger calculation.

`workshop/shared_ledger.gd` is the portable ownership planner. `Mind.apply_info` now
records normalized original receipts; each legacy argument justification records its exact
original roots and board-case identity. Relays, reordered groups, duplicate board wrappers,
different conclusions and different venues do not create extra original facts. The legacy
coarse source/day/role id remains intact for compatibility; distinct statements colliding
under it cause explicit fallback rather than silently certifying one another.

The owner assesses the union of independently learned reports and active player case
endorsements once. It moves private reports into this total-evidence union while retaining
self/own-role and public known-good constraints. The earlier comparison's subtraction of
private evidence is deliberately not used as the total learned-evidence effect. Intermediate
labels supply no new constraints or bonus; the actual presented case's scoped diagnostics
remain available separately in the read-only comparison.

The baseline excludes the entire previous shared vector and certified legacy suspicion
effects. Those legacy grounds are also excluded from the honesty passes, preventing a
second credibility penalty from the same accusation. Native interval doubt, protection and
spare preferences, and role-belief effects retain their original owners. Joint source
credibility comes from independent baseline suspicion and NPC trust; this slice does not
feed joint accusations back into native honesty, which would require another explicit
credibility model. Supported presentation replies, acceptance and sound-argument rewards
now use a scoped assessment with the same clean baseline, report weights, background
evidence and world rules as the applied union. Intermediate acceptance can be explained
without accepting the headline. Strategic evil masking, ordinary conversation fatigue,
public nomination support/hostility and voting remain separate social systems.

Player trust discounts reports whose only route is player presentation (factor
`clamp(0.5 + trust, 0, 1)` in report acceptance). Independently learned readings instead
retain their legacy hearing weight (capped at 1), together with source credibility and
interval reliability. They do not globally become stronger or weaker with player trust.
The aggregate uses neutral player scaling and the listener's existing confidence scaling.
These are experimental interpretation weights, not calibrated guilt probabilities.

Re-presenting a revised board case replaces that case's exclusive roots. **Withdraw
selected endorsement** removes one case path for the selected listener and suppresses
its retired native argument contribution. Facts remain if another case or an independent
reading still owns them. Withdrawal means withdrawing endorsement, not making the NPC
forget independently learned testimony. This control is a debugging operation; it is not
yet an in-character conversation command. Turning the whole experiment off restores the
native system, including native arguments that had been withdrawn in the experimental
discussion.

An outside-suspicion layer preserves independent later changes and their clamps while
joint effects are replaced or withdrawn. Ordinary native adjustments, including paranoia
drift, update that outside layer. Pre-existing legacy contributions that were clipped, or
owned legacy targets already at a boundary without a reversible baseline, are declined
rather than guessing how much to retract. Direct absolute native assignments are reconciled
at the next reassessment. Public conversion/restoration history causes complete fallback;
cover routing never supplies actual evil intelligence to the interpreter. A turned mind's
dormant layer is retained until cover creation or restoration; if it was freed before a
cover existed, native effects are restored before the post-restoration suspicion cap.

Independent unsupported readings retain native ownership and contribute to the outside
baseline; their presence no longer disables unrelated supported reports. Exact original
receipts now identify private card accusations, defences, group presentations and public
nomination cards, including reports heard before enabling the experiment. Those paths
share one report owner with raw readings and filed deductions. Citing a deduction as a
card follows its original roots rather than treating its conclusion as a new fact.
Supported private accusations remain in ordinary NPC gossip; a stale relayed deduction
does not silently borrow a later revision from the player's board.

Inseparable mixed or uncertified argument paths, unresolved native receipt collisions,
old deduction wrappers lacking roots, unsupported selected evidence, unsupported readings
sharing a source with owned reports, temporal transitions
and workloads above the eight-report/64-state budget still restore the legacy calculation
where ownership cannot be established. Original entries are kept, not deleted. Missing
adapters appear in the inspector's ownership status and detailed trace. General live
movement/trace/health/transition semantics are still future work.

## Unified presentations and quoted conflicts

`game/workshop_presentation.gd` handles supported deduction and raw-card presentations
through the same good-mind callback. Raw accusations ask whether the target is suspicious;
defences ask whether they are good. Group presentations retain separately assessed
questions and one joint evidence effect. Private, meeting and nomination venues preserve
interpretation. Silence suppresses speech without suppressing reasoning. Evil's cover
receives repetitions, revised cases and self-targeting allegations; the real evil mind
keeps its strategic mask and receives no inferred suspicion or sound-argument trust.

Accepted presentations can earn the existing +0.02 sound-argument trust reward when they
offer new original reports. Rewrapping, changing targets, reordering roots or changing
venue cannot repeatedly reward those reports. Ordinary question fatigue is unchanged.
Semantic repetition and audience delivery are distinct: a new audience gets an explanation
without another evidence award; a repeated explanation to the same audience is shortened.

A conflict presents evidence that the statements were made, without endorsing both
contents. Quoted roots stay separate from the endorsed union. If another path independently
endorses one of those reports, that report retains its existing owner and weight. A nested
conflict remains an assessed intermediate question without sneaking its contradictory
contents into the parent's alignment premises.
Independent direct endorsement of a report survives when that report also occurs in a
quoted child. Branch-removal diagnostics retain roots still supplied by another path.
Healthy report constraints still allow
Marked to register differently on different readings; apparent conflicts with such an
explanation are not called impossible.

Recognizing a conflict adds no guilt and invents no all-night impairment for its sources.
The parked legacy conflict's broad doubt and suspicion effects are suppressed while the
shared owner is active. A supported conflict accepted at agreement >= 0.6 can put an
actually cited participant under scrutiny once (+0.1 privately, +0.2 publicly); rejected
conflicts and repeated wrappers/venues add no such pressure. Merely putting someone's
name in the conflict group does not make them a cited source. This scrutiny is a social
consequence, not an alignment inference.

Substantial joint suspicion can be cited as coming from the reports considered together.
Disclosure is conservative: private presentations are citable to the player, public
presentations/disclosures to the town. Later private restatements do not erase public
knowledge of those reports. Unknown private roots remain unpublished. A joint
reason does not trigger the old own-gift reveal/hint machinery, and an owned legacy bonus
that has been retracted cannot remain as the stated reason. Source health and honesty
are still hypotheses, not public assertions established by this generic explanation.

Compatible native entries are parked using the shared assessment's agreement so a later
capability fallback has a contribution to restore. They are not a simulation of what the
old argument interpreter would have concluded in a separate playthrough. Preferences and
role beliefs retain native ownership. Withdrawal also removes direct citations of the
selected filed deduction; independently learned raw-card reports remain known.

`workshop_presentation` traces separate agreement, scoped intermediate assessments,
response, original novelty, quoted receipts, trust change, scrutiny and the total applied
union. Read-only inspector records explicitly name whether the actual response was shared
or legacy. Joint effects and response calculations cache one exact pure input per good/
cover listener, reset on a new case. Baseline, role knowledge, report weights, trust,
interval doubt, evidence and public chronology invalidate the relevant calculation.
Retraction restores an unchanged outside baseline exactly; it does not add and subtract
the same floating-point value in a way that slowly changes priors or cache keys.

## Manual effectiveness preview

The live canvas, fixture canvas and live comparison panel have **Preview effectiveness**.
It calculates on demand, never on every link, and does not change the case, remembered
mock-jury discussion, NPCs, time, RNG or identification scoring. Live preview is available
without Debug and uses selected player-held evidence plus public process events only.

The ghost is a new reference profile with no town identity, self-good assumption, private
reports, known gift, actual NPC trust or hidden truth. Its fixed inputs are player/witness
trust 0.5, initial suspicion 0.1 and confidence 0.5 with full reasoning. The result reports
approximate signed effects for all people, intermediate acceptance/remaining alternatives,
and conditional compatible assignments. Unsupported evidence yields an explicit explanation.
These values describe the case under declared neutral assumptions; they predict neither
a particular NPC nor a vote. Assignment counts are not probabilities of guilt.

## Integration sequence and remaining work

Stages 1–4 now have paired tests, including raw/case overlap, revisions, repeated venues,
independent learning, source-doubt recovery, clamping/retraction, native preference and
role effects, cover isolation, capability fallback and neutral preview. The frozen fixture
checkpoint remains unchanged. Full-case general-role rollout and response parity remain
future gates, not evidence supplied by these restricted tests. The live canvas now files
and presents its full answered graph through those paths. The separate F6 fixture UI
remains the reference for mechanics not yet adapted to a running case.

Run `godot --headless --path . --script res://tools/test_workshop_ownership.gd` for the
57 ownership/ghost checks. `test_workshop_presentation.gd` adds presentation, mixed-owner,
quoted-conflict, source privacy, intermediate acceptance and cache checks, alongside `test_workshop_integration.gd`,
`test_workshop_live_ui.gd`, `test_workshop_canvas.gd`, native argument/belief/cover tests,
`test_workshop_live_canvas.gd` and `test_trace.gd`. The ownership suite includes actual turn/free lifecycle calls with
no cover, tiny legacy remnants below the usual display threshold, clipped-migration
refusal, and over-budget fallback. UI tests exercise the manual preview without Debug.

1. **Live evidence adapter, read-only.** Map board reports, testimony and observations
   to stable original fact/incident identities, keeping observation, reporting and learned
   time distinct. Construct each listener's permitted knowledge; never pass role truth,
   the actual poison target or conversion identity as an inference shortcut. Record
   unsupported mechanics explicitly instead of silently excluding legal alternatives.
2. **Restricted live comparison.** Choose cases whose roles, registration, faults and
   public chronology are supported. Evaluate without changing the NPC. Trace original
   evidence, intermediate acceptance, considered alternatives, likelihood assumptions
   and proposed consequences beside the old assessment. Validate ordinary playthroughs
   as well as the 692 teaching example. Profile realistic town and evidence sizes.
3. **One source of belief effects.** Reconcile existing `Mind.apply_info` reading effects,
   `Argue.evaluate` deductions and new joint consequences. Use replacement or incremental
   inference over a shared evidence store; do not add the new vector over old bonuses
   for the same reports. Share provenance across multiple player cases, NPC discoveries
   and retellings. Recompute affected consequences when a source or interval is doubted.
4. **One semantic presentation path.** Route private presentation, the meeting floor and
   nomination speech through that assessment. Audience, disclosure, pressure and voting
   can differ. Venue changes and repeated presentations must not award fresh evidence.
   Adapt good-cover reasoning for evil NPCs without leaking real evil knowledge.
5. **Controlled playable rollout.** Enable new effects for a supported subset, retain
   old/new diagnostics, and inspect persuasion, social pressure and voting separately.
   Preserve other effects such as protection preferences and role beliefs until their
   replacements exist. Run argument/belief regressions and full-case save/replay tests.
6. **Expand mechanic coverage.** Define each additional role/event's constraints and
   legitimate exceptions, then test combinations. Do not enumerate bespoke argument
   chains. Extend the causal movement model, event uncertainty, Scion succession and
   multiple histories only with appropriate generators and tests.

Acceptance includes no hidden-truth dependence, no duplicate awards across raw readings
and cases, coherent retraction, source-time correctness, honest unsupported/incomplete
feedback, agreement on intermediate claims without forced acceptance of their parent,
and playable response latency. The Workshop's five-second testing budget and hand-set
profile priors are not production targets or final balance recommendations.
