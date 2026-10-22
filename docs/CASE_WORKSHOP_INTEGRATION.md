# Main-game integration

The bounded Workshop experiments are the reference implementation, not a replacement
already running in the main game. Integrate in verified vertical steps:

The pre-integration reference is commit `5d30513`. The [checkpoint and portable
specimens](CASE_WORKSHOP_CHECKPOINT.md) describe what must survive an interpreter change.
The read-only `Game.workshop_snapshot` API provides a portable evidence contract,
capability issues and hidden-state isolation checks. A restricted live comparison now
consumes that contract for Surveyor, Rumormonger and Dowser cases. An experimental shared
owner can now replace certified legacy suspicion for that restricted evidence set. It is
off by default and explicitly enabled in the Debug inspector. This delivers stages 1–3
within the scope below; unified response dialogue and broader playable rollout remain.

## Try the live comparison

Open **More → Live Workshop comparison** in the main game. To inspect private NPC
responses, enable the existing **Debug** control; its normal identification-scoring
warning still applies. Choose a filed deduction and listener, then **Inspect now**.
The optional recording checkbox also captures comparisons when actual deductions are
presented privately, to the meeting, or during nomination speech. All three venues use
one comparison adapter. The detailed trace stores the captured input, real legacy
result, proposed new result, capability issues and elapsed time. Recording is off by
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
credibility model. Native trust rewards, pressure, masking and argument dialogue remain
in place. Consequently the spoken old agreement can differ from the newly applied joint
belief shift; unified response dialogue is still stage 4.

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

Mixed or uncertified argument paths, ambiguous receipts, overlapping old raw-card
accusations/defences, unsupported readings, conflict-only presentations requiring quoted
report ownership, temporal transitions and workloads above the eight-report/64-state budget
restore the complete legacy suspicion model for that listener. Original entries are kept,
not deleted. Missing adapters appear in the inspector's ownership status and detailed trace.
This conservative behavior means an ordinary mixed-role live case may remain entirely on
legacy beliefs even with the switch enabled. Broader card/role ownership is still required
for general play.

## Manual effectiveness preview

Both the fixture canvas and the live comparison panel have **Preview effectiveness**.
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

Stages 1–3 now have paired tests, including raw/case overlap, revisions, repeated venues,
independent learning, source-doubt recovery, clamping/retraction, native preference and
role effects, cover isolation, capability fallback and neutral preview. The frozen fixture
checkpoint remains unchanged. Full-case general-role rollout and response parity remain
future gates, not evidence supplied by these restricted tests.

Run `godot --headless --path . --script res://tools/test_workshop_ownership.gd` for the
57 ownership/ghost checks, alongside `test_workshop_integration.gd`,
`test_workshop_live_ui.gd`, `test_workshop_canvas.gd`, native argument/belief/cover tests,
and `test_trace.gd`. The ownership suite includes actual turn/free lifecycle calls with
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
