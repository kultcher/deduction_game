# Whole-town presentation profile

Measured 2026-10-22 with Godot 4.7.2 Mono, native ten-person case 692, three native-generated
readings. This reproduces the live-canvas smoke test: one private presentation, normal
conversation departure/meeting setup, then the first floor presentation. Setup is outside
the measured interval. Detailed trace capture is off. These are single-run development
measurements, not platform guarantees or an all-caches-empty microbenchmark.

**31,133 ms before → 8,676 ms after**, about **72% less elapsed time / 3.6× faster**.
All ten listener records, dialogue, beliefs, ledger/ownership state and final RNG match
exactly. The comparison deliberately excludes diagnostic elapsed/cache-hit fields from
NPC state. Its canonical behavior SHA256 is
`253d9f9a5f343e6ffd8add17e7d860bf548b653e674473d234d55e103b29328b`.

## By listener

| Listener | Before (ms) | After (ms) | Actual route |
|---|---:|---:|---|
| Constance | 4,693.83 | 1,513.08 | Shared |
| Nisha | 4,632.57 | 1,346.77 | Shared |
| Hollis | 4,153.67 | 1,067.51 | Shared |
| Odette | 2,140.60 | 431.68 | Shared |
| Merrin | 7.57 | 6.01 | Existing-rules fallback |
| Lian | 4,442.97 | 1,224.53 | Shared |
| Agnes | 3,578.32 | 1,011.43 | Shared |
| Greta | 3,984.12 | 1,265.63 | Shared |
| Fenwick | 6.18 | 6.38 | Existing-rules fallback |
| Bartholomew | 3,484.94 | 797.65 | Shared |

Merrin/Fenwick's fast results are capability fallbacks, not fast successful new-model
inference. Both runs use the same routes. Odette already heard the private presentation;
the benchmark therefore includes reuse representative of that sequence.

## Calculation stages

Exclusive times: the rows below do not count nested work twice. Before the additional
search span existed, search was included in explanation's exclusive time; those two
are grouped for a comparable before/after row.

| Work | Before (ms) | After (ms) |
|---|---:|---:|
| Ranking prior worlds | 16,586 | 235 |
| Comparing weighted worlds | 6,559 | 2,031 |
| Explanation/candidate search | 4,288 | 2,996 |
| Constraint solves | 2,641 | 2,589 |
| Remaining work, wrappers and frame yields | 1,059 | 825 |

For context, these inclusive stages overlap the table above and must **not** be added:

| Presentation stage | Before (ms) | After (ms) |
|---|---:|---:|
| Initial belief refresh, all listeners | 14,573 | 4,192 |
| Scoped assessment that supplies the reply | 16,468 | 4,399 |
| Store native fallback contributions | 13 | 13 |

There were 17 belief refreshes, seven new union evaluations, eight scoped assessments,
eight union-cache hits and no trust-reward refresh in this particular floor action.
The expensive refreshes represent distinct union/response inputs; parking an already
owned native contribution mostly hits its assessment cache. Removing that necessary
ownership step would save little and would risk fallback/retraction behavior.

## Changes made

1. **Reuse prior ranks.** Previously 496 calls rebuilt the prior ranking for each
   projection/explanation, although its inputs were unchanged. The measured action now
   makes seven builds and 489 hits. The bounded 64-entry cache checks exact inputs after
   hashing: roster/setup, chronology/modifier domain, epoch, private knowledge, suspicion,
   witness trust and theory bias. Stored keys are deep copies. Numerical ranking is unchanged.
2. **Reuse comparisons within an assessment.** A possibility calculation reused a
   comparison just calculated for that same state. The comparison against a private-only
   evidence subset also repeated across states for other witnesses. Reuse is local to
   that assessment, where ranking, question and knowledge are fixed. Comparison calls
   fall from 33,675 to 16,867; the number of actual cache misses remains 91. There are
   9,693 private-subset comparison reuses. Credibility states remain **16,544**.
3. **Reuse candidate constraint checks.** Live explanation searches often test the
   same candidate under the same reports/knowledge while asking different alignment
   questions. A bounded 32-entry cache reuses only the candidate checks the existing
   search elects to perform. It preserves candidate order, support/rival selection,
   budgets, exhaustion and reported tested counts. Case 692 still tests **170,856**
   candidates: 105,293 check hits and 65,563 misses. The cache receives public possibilities
   and permitted knowledge, never referee-filtered worlds. No bounded reasoner gets
   additional candidates or an answer to an unperformed check.

Intermediate measurements were 11,185 ms with prior reuse alone and 9,157 ms after
local comparison reuse. Candidate reuse then produced the final 8,676 ms result.

A second native case, seed 4242, checks that this is not a universal nine-second claim.
Its final run took **13,610 ms**; its behavior hash matches the run with all three changes
disabled (`da951a4de850c36ede2ed08c8f416dcc7b61363cc828c254d8ea0ba0b2f94f46`).
It spends more time on candidate search (6,591 ms) and constraints (3,563 ms). Its baseline
timing was collected alongside regression work, so it is used for behavioral parity,
not a controlled speedup ratio.

## Reproduce and inspect

Run:

```text
godot --headless --path . --script res://tools/profile_workshop_town.gd
godot --headless --path . --script res://tools/profile_workshop_town.gd -- --seed 4242
```

The default JSON output is `logs/workshop_profile.json` (ignored by Git). Use
`--output res://logs/name.json` to preserve each run. For a reference run, pass
`--no-prior-cache --no-comparison-reuse --no-match-cache`. Those switches affect only
that developer process; they are not game settings. Compare the `behavior_hash` and
canonical `behavior` objects as well as elapsed time. Run timed comparisons sequentially.

The opt-in `workshop/profiler.gd` records per-listener stage paths, call counts, inclusive
and exclusive microseconds, cache counters and candidate/state counts. It is disabled
by default, performs no I/O and is not stored in NPC beliefs. The benchmark enables it
only around the floor command and exports afterward. Nesting is asserted and tested;
independent parent/child times reconcile without summing overlapping stages.

The [compact recorded profile](benchmarks/workshop-town-2026-10-22.json) includes per-listener
stage rows and counters for case 692, without the full private NPC dumps. Frozen Workshop
checkpoint outputs are unchanged. `tools/test_workshop_profiling.gd` adds exact A/B checks
for cache invalidation, soft/temporal fixture support, and bounded/full live searches.

The next substantial targets are remaining explanation search and repeated constraint
solves. Those require a separate measured change; the current fixes do not change
evidence coverage, uncertainty limits, confidence, balance, fallback rules or game content.
