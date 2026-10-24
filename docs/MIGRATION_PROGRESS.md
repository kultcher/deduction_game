# Legacy migration progress

Oct 23, 2026. Runtime: Godot 4.7.2 (confirmed by the user).

The migration is **in progress**, not finished. P1 is partly implemented; P2–P5
remain. Q3 and Q6 remain deferred. The 95% demon-victim rule and weak hint/refusal
rules are recorded decisions, not yet migrated behavior.

## P1 first slice

- Canvas revisions receive a new number and mark their predecessor superseded.
  Filing does not change listeners' beliefs. Hearing the revision retires the old
  endorsement; unchanged roots keep their full shared weight. A regression compares
  a revision with first hearing its complete evidence at fixed trust.
- Unchanged presentations reuse their earlier assessment. They acknowledge a prior
  private discussion or meeting; the first repeat in a conversation is free. Tests
  check that no jury/ownership solve, trust reward, pressure or RNG draw occurs.
- Morning/afternoon sightings and conversations retain their daylight locations and
  do not become night outings. Evening conversations use the existing evening/trace
  likelihood for every named participant. Homes and haunts are accepted as context,
  without manufacturing alignment evidence.
- A structured totem uses the public material/home mapping and the joint unique-role
  assignment: a Revenant minion must come from that block. It cannot be explained by
  the Demon or by a Marked registration.
- Dropped materials constrain which home-group residents could have walked through
  the discovery block. Joint alibis can resolve a sole eligible walker; several
  eligible residents remain alternatives. Distinct drops need distinct walkers,
  matching the native one-drop-per-walker rule. Personal belongings reserve their
  known owner; repeated receipts do not create a second item.
- Opinion and accusation cards are rejected as evidence in ordinary play as well as
  strict tests. Their underlying observations/readings must be cited instead. The
  town-consensus suspicion term itself still needs the P3 migration.

Targeted suites cover revision/repeat contracts, location and totem adapters, exact
root ownership after native receipts are parked, malformed payloads, shared dialogue,
Insight/Confidence preservation and live UI delivery. Remaining P1 work includes the
other event cards, hints/refusals, nested case composition, and removing the
remaining native presentation routes after their replacements are measured.

## P0 implementation

- Suspicion stores reversible, unclamped totals. Simulation/UI consumers use bounded
  reads. Owned entries no longer fail capability checks because of saturation.
- Shared assessment starts enabled. Strict rejection is opt-in for tests only.
- Presentation commands check the entire audience before spending a question, floor
  or statement, revealing secrets, or changing beliefs. Unsupported ordinary-play
  submissions explain the reason and use one response engine for the whole audience.
- Presentation and internal ownership failures emit `workshop_fallback` trace events.
- Previews include actual audience readiness alongside the neutral assessment.
- Timing and cache diagnostics live outside NPC belief state.
- Private-reading evaluation stores only states present in legal worlds, rather than
  allocating all 3^readings combinations. Dense-enumeration parity checks pass.
- Identical constraint solves and conflict analyses are memoized. Position filters
  share their common report/role/route solve. Semantic checkpoint tests pass.
- Live assessment defers exhaustive minimal-conflict enumeration: only the explicit
  diagnostic UI reads those lists. Bounded attention, candidate counts, belief and
  action results remain the same. Attention/explanation memoization has A/B checks.

P0 is **not signed off**: full validation and bot comparisons are running, and the
historical case exceeds the five-second presentation budget.

## 54875 measurement

The next P1 slice supports Surveyor answers naming a block without identifying a
resident. Block and resident slots share validation and remain hypotheses: they
change conditional fit, never the evidence posterior. The backend's 11 checks and
the editor's actual selection/rebuild checks pass on Godot 4.7.2.

`tools/replay_54875.gd` replays the original local playtest's opening commands through
the first Day 2 vote on Constance. The committed fixture was extracted from the
original `case_54875.jsonl`; it contains player actions and the filed graph, without
referee truth. Plain-card references are matched by original fact identity because
board numbering changed since c6ae7a4. Original case #85 is #89 in this build.

Measured while P0 was in progress:

- All nine living listeners used shared assessment; no fallback events.
- The nomination **failed: 1 yes, 5 needed**, with the player's original `vote no`.
  Jory voted yes; Lian accepted the case and voted no.
- Post-presentation suspicion of Constance: Hollis .267, Jory .510, Greta .145,
  Odette .189, Constance's cover .000, Edda's cover .291, Agnes .180, Isolde .293,
  Lian .232. These are measurements, not tuning targets.
- Good-listener vote margins: Agnes -.521, Isolde -.274, Lian -.213, Hollis -.278,
  Jory +.252, Odette -.211.
- Most listeners did not accept the headline: agreement ranged from 0 to .757.
  This differs from the legacy playtest's wording and is reported without tuning.
- Cold presentation cost was initially about 50 seconds. Removing empty private
  states and reusing solver work reduced it to about 18–19 seconds; removing unused
  exhaustive diagnostics and reusing attention reduced the latest run to about
  **8 seconds**. Further work is
  required; the simple probes do not represent this historical case's workload.

The replay writes full agreement, suspicion, vote margins, actual tally, commands,
timings and profiler output to `logs/migration/replay_54875/measurement.json`.
It deliberately does not assert that the nomination passes. The complete later
playtest, including curse histories, still needs a replay after P2's adapters.

## Presented cards dropped by attention (found in review, Oct 23)

Claude re-ran `tools/replay_54875.gd` on the merge (Godot 4.7.2 headless): same result,
1 yes of 5 needed, all nine listeners shared, presentation about 9.6 s plus 2.4 s for
the nomination. Dumping each listener's `reasoning` shows why most rejected:

| Listener | Insight profile | Case cards considered | Agreement |
|---|---|---|---|
| Hollis | High | both | .42 (partial) |
| Greta (cover) | High | both | .19 |
| Lian | High | both | .76 (accept) |
| Jory | Low | **neither** (in `ignored`) | 0 |
| Agnes | Low | **neither** | 0 |
| Odette | Medium | **neither** | 0 |
| Isolde | Medium | **neither** | 0 |
| Edda (cover) | Medium | **neither** | 0 |
| Constance (cover) | Medium | one | 0 (own knowledge) |

The case has only two cards (Constance's "home" alibi and the player's vigil). Medium-
and Low-Insight listeners filled their attention with 13–20 other facts (8–15 of them
their own private reports) and put both presented cards in `ignored`, then answered "I
could not follow your explanation through" with agreement exactly 0. The legacy rules
always weighed the presented cards.

This is a migration defect, not Q6 tuning: Insight should limit how far a listener
follows the case (links, rivals), not whether they look at what was put in front of
them. **Fix before more P1 work:** the presented case's own cards are always in
attention; background and private evidence compete for the remaining budget. Then
re-measure the replay. (Jory voted yes anyway, from his own suspicion.)

Also observed: the 2-card Day 2 case is genuinely weaker under the shared model than
under legacy, because Constance had publicly claimed Night Watch (a walking gift
explains being out) before the presentation. That part is principled. The replay
only covers that first vote; the Day 3–4 versions of #85 (four and six reports,
including her "watched the Docks" while seen on the Market) are the stronger test and
should be added to the fixture.

## Performance pass after review (Claude, Oct 24; branch `claude/perf-reuse`, merged)

Profile of the replay's #85 presentation (9.6 s, nine listeners): `explain` 3.7 s self
(207 calls), `headline` 1.8 s, `consequences` 1.5 s, `listener` 0.9 s, candidate search
0.7 s, constraint solves 0.5 s. Each listener runs the jury twice (belief refresh 3.3 s,
scoped reply 5.2 s), and live listeners use `persistence` confidence, so
`_consequences_eval` ran `Support.explain` for every person in both runs.

Changes (intended to be exact: same beliefs, replies, theories and RNG):
- `Theory.cached()`: the decision `Theory.prepare` would return without reading any
  reasoning (a fixed commitment, or unchanged inputs). `prepare` now uses it first.
- `_consequences_eval` skips `Support.explain` whenever its result is unused: the
  headline target's own alignment theory (it always used `headline.theory`), and any
  person whose decision is cached or fixed. Explain is read-only, so skipping it only
  changes profiler counts and memo-cache contents.
- The scoped reply (`Shared.response`) passes `{"headline_only": true}`: its effects
  are never applied (the union from the belief refresh owns them), so only the
  headline's own effect is computed. Every person already has a fixed decision from
  the union, so the reply also skips their explanation searches.
- Not yet done: batching the explanation search across people for the belief refresh
  itself (bounded budgets make exact parity delicate).
- Worth measuring next: `explain`'s own cache had zero hits in the replay, yet each
  call still hashes and deep-copies `[view, value, profile, prepared]`. That may be a
  large part of the 3.7 s self time.

### Second and third passes (Oct 24)

Instrumented profile (Day 1 meeting entry and #89, about 30% profiler overhead):
movement likelihoods (`LiveActivity.factors`) were the largest single cost (3.2 s and
4.1 s, 80–120 ms per cache miss), then `CaseEval` (1.6 s and 2.9 s), constraint solves
and `Solver.analyze`. A meeting ran about 53 jury refreshes, one per statement heard per
listener. Argon's independent review agreed on the movement model and the refresh,
and added the cache-key and `unresolved` points.

Exact changes (commit 3bad9d5):
- `LiveActivity._likelihood`: route lists and per-route products built once per
  profile, not per habitual block × evening (same arithmetic order).
- `LiveActivity.factors` and `routes` cache on `movement_inputs()` (movement cards,
  relayed cards, claimed roles), not the whole card list.
- `CaseEval._own_counts`: integer state codes. `Solver.unresolved`: one bitmask pass.

Declared behaviour change (commit 12bdf32, agreed with the user): the belief refresh
uses `Jury.refresh`, with no placeholder headline ("the first person in the list is
evil"). The first person now gets the same theory path as everyone else. Reading
challenges and the refresh's `reasoning` come from the attended union. Every
refresh effect's `reasoning` is `belief_refresh`. The
refresh no longer builds intermediate-claim or link diagnostics. Replay numbers after
this commit are the new baseline. In the 54875 replay, agreement, vote margins and
tally came out identical to 3bad9d5.

Speed effect, measured afterwards (same machine, A/B, profiled #89): neutral, not the
10–25% Claude estimated. The headline's work was mostly the first person's theory
(the same 16,800 candidate tests either way); it moved into the per-person loop
(`consequences` self time +0.8 s, `headline` −0.7 s, total +2%). Interleaved
replays on a noisy container: meeting entry within noise, other steps 6–12% faster
or slower depending on the run. The user's run showed 2–8% slower, consistent with
"no gain". Kept for consistency, not speed.

Measured on the user's machine (replay; main → after 3bad9d5):

| Step | Before | After |
|---|---:|---:|
| Enter meeting (`ask seen today`) | 8501 ms | 4529 ms |
| `search` → meeting | 8759 ms | 4964 ms |
| `present 89` | 6864 ms | 4158 ms |
| `nominate constance` | ~2015 ms | 1070 ms |

Same result: 9 shared, 0 native listeners; case #85 (filed #89) 1 yes of 5 needed.
Not done, by decision: batching meeting refreshes (later speakers must react to
earlier ones). The rules that keep these gains are in LEGACY_MIGRATION.md,
"Performance rules".

Profiling tools now fail when any listener falls back (`--allow-fallback` reports
without failing): `profile_live_presentation.gd`, `profile_case_eval_town.gd`,
`profile_workshop_town.gd` (new `fallback_listeners` field) and `replay_54875.gd`.

**To verify:** all suites as before (expect the two known failures), the replay's
`measurement.json` agreement, suspicion, vote margins and tally identical to before
with lower `elapsed_ms` for `present 89`, and `profile_workshop_town.gd`'s
`behavior_hash` identical to main's on seeds 692 and 4242.

## Validation baseline

Untouched commit: `6bce4d4`. Godot 4.7.2 headless, seeds 1000–1149, 150 games per row.

| Town | Player | Good wins | Wrongful / all executions | Evil executed |
|---|---|---:|---:|---:|
| 7 | Active | 42 | 157 / 239 | 82 |
| 7 | Passive | 8 | 119 / 147 | 28 |
| 10 | Active | 28 | 318 / 430 | 112 |
| 10 | Passive | 20 | 227 / 307 | 80 |

Baseline tests: 43/45 suites passed. Existing failures on this runtime:

- `test_social`: false Night Watch's night story versus fake report (one check).
- `test_text_ui`: enclosing card target on role hover and right-click (two checks).

These were reproduced in an untouched source snapshot. Tests of the native equations
or migration from a disabled baseline explicitly select native mode; integration
tests exercise the new default. Run every suite with
`python tools/run_gd_tests.py --godot <Godot-console-executable>`; the runner also
detects printed failures and script errors when a suite exits zero.

The initial P0 batches were stopped after revealing the exhaustive-diagnostic
performance problem; their partial logs remain under `logs/migration/p0`. The fixed
ten-person active smoke case (seed 1000) completed in 83 seconds under concurrent
test load. Full post-change results and comparisons are pending. No post-migration
balance claim is made yet.

The broad migration run passed 44/47 suites, with the two reproduced baseline suites
and one stale reading-challenge revision test failing. Updating that test to use the
new returned card number passed its 57 checks. All 45 suites outside the reproduced
baseline failures have now passed, including trace parity (45 checks). Subsequent
targeted checks also pass for dropped cards, exact caching, revisions and the UI.
