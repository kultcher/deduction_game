# Reasoning performance and migration options

Recorded October 22, 2026. These are engineering options and priorities, not measured
speedup promises. The player currently presents a large town-wide case roughly once
per day (about every 5–10 minutes of play); a few seconds at that boundary may be
acceptable. Keep ordinary interaction responsive and measure realistic cases before
changing the model to meet an unnecessarily strict frame-time target.

## What drives cost

`Session.present` currently assesses listeners sequentially. Shared caches reuse some
legal worlds, report matches and movement likelihoods, but each listener has different
private knowledge, source trust, prior suspicion and attention. More listeners add
roughly linear listener-specific work when everything else is fixed. That is not a
benchmark guarantee: caches and different listener knowledge change the slope.

The credibility mixture enumerates `2^u` combinations for `u` uncertain assumptions.
Twelve uncertainties mean 4,096 combinations; sixteen mean 65,536. Doubling listeners
roughly doubles that portion; four more uncertainties can multiply it by sixteen.
Those effects multiply. Bounded NPC hypothesis search does not by itself bound the
outer credibility mixture. More townspeople also enlarge possible-world searches;
adding an existing listener and adding a character to the town are different costs.

Repeated per-person good/evil projections, intermediate claims, minimal conflicts and
branch-removal diagnostics add further work. Profile them separately. As of the
pre-integration checkpoint, supplied four-juror experiments took about 1.5–3.5 seconds
on the development machine; a broad 4,096-state one-juror stress test took about nine
seconds. These are development observations, not production or other-hardware promises.

## Preserve behavior before reducing precision

1. Reuse an assessment across character questions and cache stable normalized inputs.
   Prepare IDs, report constraints and provenance once; avoid repeated dictionary
   copying, string serialization and filtering inside inner loops. Dependency-aware
   invalidation should recompute only what a case or belief revision affects.
2. Compute expensive explanation diagnostics on demand: every minimal contradiction
   set and every branch-removal comparison are useful tools, not prerequisites for
   updating beliefs. Keep clear ordinary explanations without calculating every
   possible explanatory breakdown at presentation time.
3. If needed, replace exhaustive credibility combinations with bounded weighted
   assessment. This sacrifices numerical precision before argument expressiveness.
   Reuse deterministic selections across repeats/revisions; unchanged cases must not
   produce random attitude jitter. Refine near consequential acceptance/vote thresholds.
4. Check important alternatives explicitly, including Bart-as-Marked, health failure
   and relevant dated conversion. A rare exception must not disappear merely because
   a sampler misses it. Separate approximation of weights from logical validation.
   Failure to find a rival within a budget is not proof that none exists.
5. Keep collateral effects and intermediate claims. Limit work by evidence dependencies,
   not only the headline target. Do not split connected branches as independent when
   global counts or shared sources couple them. Preserve provenance and full retraction.

## C# migration

Port the measured computational core incrementally; keep the UI and ordinary game
orchestration in GDScript. The modules, portable checkpoint examples and live evidence
contract provide boundaries. A prototype hotspot port is a bounded experiment; a full
behavior-equivalent core port is a meaningful implementation effort. Temporal rules,
shared dependencies and revision semantics are more difficult than translating syntax.

Use typed .NET structures, integer person IDs, arrays/bitsets and ordinary .NET
collections internally. Convert evidence in and results out at a coarse boundary.
Directly translating every dynamic Godot Dictionary access can retain much of the
overhead: Godot collections require interop/marshalling from C#.

A several-fold numerical-core improvement is plausible but unmeasured here. Whole-call
benefit depends on the accelerated fraction: hypothetically accelerating 90% of a call
by 10x gives about 5.3x overall, not 10x. Faster code does not remove exponential growth.
Benchmark equivalent inputs, answers, cold/warm caches, allocations and exported builds.
Godot's .NET edition is required. Current Godot documentation excludes C# web export;
recheck that platform constraint before committing if browser distribution is intended.

## Other routes

- Run pure assessment off the UI thread so the game stays responsive. This alone need
  not shorten the computation. Use immutable snapshots, separate/synchronized caches,
  cancellation and stale-result protection; do not access the active scene tree from
  worker calculations. Parallel listeners may reduce elapsed time within core/memory
  limits, but cannot simply share today's mutable caches unsafely.
- Compact constraint representations, pruning and dependency-aware inference can
  improve scaling without changing the game rules. A specialized constraint solver
  is a future benchmark candidate, not a promise of free weighted/temporal inference.
- A native C++/GDExtension core remains available if a measured C# core is insufficient.
  It adds build/distribution complexity and still needs sensible search budgets.
- Scheduling work during natural presentation/response pauses is preferable to
  sacrificing meaningful player expression solely for instantaneous answers.

First measure, share work and defer diagnostics; then benchmark a port and/or bounded
uncertainty. Keep the checkpoint examples as migration aids, with experimental numeric
weights separate from permanent semantic requirements.

Official references: [mixed-language scripting](https://docs.godotengine.org/en/stable/tutorials/scripting/cross_language_scripting.html),
[C# collections](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_collections.html),
[C# platform support](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html),
[thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).
