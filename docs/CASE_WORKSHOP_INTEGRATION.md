# Main-game integration

The bounded Workshop experiments are the reference implementation, not a replacement
already running in the main game. Integrate in verified vertical steps:

The pre-integration reference is commit `5d30513`. The [checkpoint and portable
specimens](CASE_WORKSHOP_CHECKPOINT.md) describe what must survive an interpreter change.
The first integration slice now provides the read-only `Game.workshop_snapshot` API,
its portable evidence contract, capability issues and hidden-state isolation checks.
Live numeric comparison and belief effects remain disabled until the narrower fixture
assumptions have explicit live equivalents. This is a data boundary, not completed
gameplay integration.

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
