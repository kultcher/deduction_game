# Main-game integration

The bounded Workshop experiments are the reference implementation, not a replacement
already running in the main game. Integrate in verified vertical steps:

The pre-integration reference is commit `5d30513`. The [checkpoint and portable
specimens](CASE_WORKSHOP_CHECKPOINT.md) describe what must survive an interpreter change.
The read-only `Game.workshop_snapshot` API provides a portable evidence contract,
capability issues and hidden-state isolation checks. A restricted live comparison now
consumes that contract for Surveyor, Rumormonger and Dowser cases. Belief effects remain
on the legacy system. This delivers the first two integration stages within the scope
below, not completed gameplay integration.

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

Venue is recorded but the new proposal is unscaled; the real original result keeps its
actual venue scaling and side effects. Proposed effects use the captured existing beliefs,
which can already contain legacy reading effects. They must not be added to those effects:
the shared replacement ledger is the next integration gate. No new suspicion, trust,
pressure or voting change is applied by the comparison. Existing evil cover minds are
captured without creating or syncing them; a missing cover mind yields an unsupported
result. Comparisons remain a developer tool rather than an alternate gameplay mode.

Tests exercise public legal domains, all modifier types, distinct world/cache keys,
healthy unique gifts, hidden-truth independence, no preview mutation, original behavior
and RNG equivalence across all venues, JSON checkpoint replay and the actual inspector.
The initial one-reading benchmark was roughly 0.2 seconds for seven people and 1.6
seconds for ten on this machine; that is not a whole-town or large-case latency claim.
See [performance and migration options](CASE_WORKSHOP_PERFORMANCE.md).

## Remaining integration sequence

The shared-ledger work must assess the union of learned original evidence once, rather
than adding per-case vectors. Establish one owner for raw readings and deductions;
preserve source/reading reliability, private evidence and non-suspicion preferences.
The Workshop's private-evidence subtraction measures the marginal value of a presentation;
it cannot simply be reused as the total effect of all private readings. Remove each
owned previous vector before reassessment, including collateral effects, and use a
baseline that cannot feed its own accusation back into source credibility. Retractions,
trust changes, newly learned facts, repeated presentations and venue changes need paired
tests. Resolve the coarse legacy identities/dependencies flagged by the audit before
automatically suppressing old contributions. Public transitions and unsupported reports
must cause a coherent fallback/retraction, not leave a partial second model applied.

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
