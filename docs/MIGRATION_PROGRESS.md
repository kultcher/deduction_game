# Legacy migration progress

Updated Oct 24, 2026. Runtime: Godot 4.7.2 (confirmed by the user).

The migration is **in progress**, not finished. P1 is partly implemented; P3
consensus and Q4 opinion/context slices are implemented. The remaining P2 and P3 work, P4 and P5
remain. Q3 and Q6 remain deferred. The Demon-victim rule now supplies finite 95:5
innocence evidence; refusals supply weak suspicion and hints weakly support a
tentative gift-family claim.

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
  town-consensus term now remains separate social action pressure (P3 slice below).

Targeted suites cover revision/repeat contracts, location and totem adapters, exact
root ownership after native receipts are parked, malformed payloads, shared dialogue,
Insight/Confidence preservation and live UI delivery. Remaining P1 work includes the
curse event cards and removing the
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

P0 is **not signed off**: full post-change bot comparisons remain pending. The latest
user-measured presentation is within five seconds. The user authorized continued
migration above that target; report significant runtime increases by change set.

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

## Attention correction (Codex, Oct 24)

Starting checkout: `8fe9e1f`, clean. The presented roots now travel explicitly through
readiness, ownership refresh and scoped reply. Every submitted observation is read,
even if the submission exceeds the card budget. Private/background cards compete for
the remaining slots. Insight's line, support and rival limits are unchanged: reading
an observation does not grant an unattended reasoning connection. An ignored private
report cannot re-enter through the explanation search or CaseEval's private prior.
The focus persists with the current discussion and participates in repeat keys.

New attention suite: 11 checks passing. The broad run exposed old attention
expectations and a repeat-key inconsistency; the corrected cognition, presentation,
revision/repeat and ownership suites pass. All 46 regular suites outside the two
known baseline failures passed across the broad run and targeted corrections.
Fresh starting-checkout
validation: 45/47 regular suites pass, with the two documented baseline failures;
the slow trace suite was not included in that baseline run.

Measured opening replay, same commands and coefficients, nine shared listeners and
zero fallbacks in both runs:

| Listener | Agreement before | Agreement after |
|---|---:|---:|
| Jory | .000 reject | .722 accept |
| Odette | .000 reject | .650 accept |
| Agnes | .000 reject | .595 partial |
| Isolde | .000 reject | 1.000 accept |

Other headline agreements remain unchanged. Suspicion of Constance rises for Jory
(.510 to .633) and Agnes (.180 to .450); the other presentation-end values remain
unchanged. **The vote still fails 1 yes / 5 needed.** Acceptance is not a measured
promise that a vote changes. This result is reported without tuning Q3/Q6.

Paired timing under concurrent validation: presentation 4721 to 3574 ms; meeting
entry 4722 to 5133 ms; search into meeting 5659 to 5655 ms; nomination 1206 to 917 ms.
This slice did not introduce a significant presentation cost. These timings are
measurements on this machine, not guaranteed speedups. Reports are preserved under
`logs/migration/resume/{baseline,attention}`. The replay now records each listener's
considered/ignored cards as well as the applied refresh's considered cards.

## Nested canvas cases (Codex, Oct 24)

A filed canvas can now support a further deduction. Its intermediate questions keep
their own evidence, with namespaced parent links. Child answers, assumptions,
reading challenges and alibi disputes survive composition; the conclusion label
adds no evidence. Repeated routes to a shared descendant retain one original fact.
Each stored canvas is checked against its actual board supports, so an omitted root
or invalid challenge cannot hide inside a larger parent. Native-only argument trees
retain their existing shape.

The new suite passes 16 checks; eight targeted suites pass, including live canvas,
ownership, presentation, integration and reading challenges. The slow trace suite on
the frozen attention commit also passes all 45 checks.

The bot comparison exposed an existing readiness exception: a Gravedigger *claim*
was checked for a reading's `executed` payload. The check now applies only to reports,
with a regression test. The interrupted batches contain script errors and are not
valid balance measurements; the full comparisons must be rerun on corrected source.

`profile_workshop_town.gd --nested` measures an enclosing deduction over the same
filed canvas. The ordinary benchmark keeps the exact behavior hashes from the
attention commit at seeds 692 and 4242, with no fallbacks: 2150/2147 ms and
2379/2391 ms (control/current). The nested seed-692 presentation takes 1623 ms,
also with full shared coverage. No significant added presentation cost was observed
in these probes; the results do not establish late-game scaling. Reports are under
`logs/migration/resume/nested`.

## Public death cards (Codex, Oct 24)

Public Demon-death receipts can be cited and owned through the shared path, alongside
the existing execution-card adapter. A death card must match a public announcement,
night, known person and public home; personal assertions are not promoted into
public events. The receipt supplies existing chronology/context without awarding
the already-public event again. Actual strict presentations retain both kinds of
root. **This is card coverage, not the pending Q2 change:** the existing hard-good
victim rule is still present and must become revisable 95% innocence evidence.

Card-adapter suite: 57 checks pass. Six targeted suites pass, plus the nested-case
regression checks. The ordinary seed-692 benchmark retains its exact behavior hash
and zero fallbacks (2488 ms under four concurrent bot runs).

## Q1: consensus outside evidence (Codex, Oct 24)

The chorus keeps its native weights, cap, fade, hint emphasis and diminishing voices,
in `consensus_pressure`. It never writes suspicion, ledger entries or source honesty,
and cannot enter shared world priors. Nomination ranking, existing-block preference
and the vote's starting score use the bounded raw evidence sum plus that pressure.
The vote/nomination coefficients and thresholds are unchanged. Debug/trace output
reports pressure separately; shadow creation preserves it. Withdrawing the final
stance clears stale pressure.

Eight new checks verify evidence/credibility/RNG isolation, raw-sum clamping, and
exact vote and nomination equivalence to folding the same pressure into suspicion
at a fixed state. Seven targeted suites pass; `test_social` retains only its known
false Night Watch failure. Whole-game outcome checks also pass.

Replay after Q1: nine shared, zero fallbacks, **still 1 yes / 5 needed**. Agreement is
now Hollis .319, Jory .775, Greta .037, Odette .676, Constance .000, Edda .000,
Agnes .680, Isolde 1.000, Lian .940. This declared Q1 behaviour change removes crowd
feedback into source credibility and priors; it is not Q3/Q6 tuning. Suspicion and
vote margins are saved in `logs/migration/resume/consensus/measurement.json`.

Under four concurrent bot runs: meeting entry 4368 ms, search into meeting 5295 ms,
presentation 4023 ms, nomination 1097 ms. No significant new presentation cost was
observed relative to the earlier replay. The bot matrix currently runs on frozen
`0cfd073` (before this Q1 change), so it will not establish final-migration balance.

## Q4: opinions and Psychologist context (Codex, Oct 24)

Private opinion gossip retains its conversation/provenance and normal teller bond,
but creates no suspicion entry. A Medium's relayed distrust and the Psychologist's
reported trust/suspicion no longer produce guilt by association. The common gift
summary and native compatibility weights also exclude them from accusation/defence
strength. Direct, wrapped and nested Medium opinions are rejected before a command
selects an engine; they cannot exploit ordinary-play fallback. Empty opinion/context
reading entries do not block ownership of supported evidence from the same source.

Psychologist readings now have a validated context adapter. All original identities,
timing and social content remain available; the model never queries the subject's
private trust or suspicion. Every good/cover listener uses the same interpretation
in seven- and ten-person towns, with no alignment award. A Medium relay retains the
original source and observation while remaining context. This starts the P2 family
migration; the other reading families' native branches, channels and temporal
adapters still need work.

Psychologist suite: 65 checks pass. Social-evidence suite: 19 checks pass. Nine
targeted suites pass, plus repeated checks of the final compatibility guards.
The frozen full run (including trace parity) passes **50/52 suites**, with only the
two documented baseline failures. It is under `logs/migration/resume/opinions/all`.
The replay has the **same agreement, suspicion and 1-yes tally as the Q1 run**:
nine shared, zero fallbacks; presentation 4092 ms versus 4023 ms, nomination 1110 ms
versus 1097 ms. No significant presentation cost appeared in this slice.

The bot now skips semantically rejected/superseded cards and deductions and gives
opinions no heuristic alignment score. Before this fix, seed 1060 repeatedly issued
`tell fenwick 64` for an accusation card until its 600-command guard expired. It
now finishes on Day 5 with no guard exhaustion. Optional `autoplay.gd --no-trace`
skips detailed state sidecars while retaining ordinary logs and metrics; a tracing
on/off run of seed 1060 produces identical result JSON. Presentation profiles and
replay coverage checks continue to use full tracing.

## Secret errand claims (Codex, Oct 24)

Structured confessions and relayed secret stories are supported as `secret_claim`
context. The owner, teller, original time and secret kind are preserved. A confession
dated to one night explains only that night's ordinary activity; a generic recurring
story supplies its stated historical interval. It uses the existing private-errand
outing rate (.55) as an alternative to ordinary inactivity, without changing gift,
Demon or minion rates or their profile weights. It never asserts an outing, an
alignment or the hidden Lovers modifier. Multiple retellings do not multiply the
alternative. Existing native defence-move entries still need P3 migration.

The movement-factor cache includes secret context and its interval; hard route
checks retain their smaller cache key because they do not read it. A claim by itself
has no alignment effect. Explicit citations validate owner and night; the live
editor now exposes the outing explanation controls and stores the original receipt.

New suite: 18 checks pass, including actual live controls, date/owner validation,
non-stacking, strict delivery and modifier independence. Eight evaluator regressions
and five UI/context suites pass. Whole-town seed-692 probes, all ten listeners shared
and no fallback: outing case 3305 ms; same case plus secret 3231 ms. No significant
added presentation cost was observed. The default benchmark retains its exact
behavior hash (2522 ms under concurrent bot runs). Reports are under
`logs/migration/resume/secrets`.

The user confirmed Psychologist can remain metagame information. Its existing
context-only treatment stays; further automatic alignment inference is deferred.

## Q2: finite Demon-victim evidence (Codex, Oct 24)

A public Demon death supplies 95:5 support for innocence (evil odds multiplied by
1/19). This is evidence strength, not a forced final probability: setup counts,
private knowledge and counterevidence still matter. The isolated even-odds test
produces 95% innocence. Neither the public adapter nor the native compatibility
rules discard a victim from candidate groups, reset their suspicion to zero, or
declare them incapable of lying. Martyr public knowledge is unchanged.

The world publishes the observation before refreshing listeners. CaseEval includes
it once per victim, even without a cited death card. The same observation arriving
through the board cannot add a second factor. Its identity participates in theory
cache signatures. A temporary native ledger entry uses the same finite odds update
and existing .45 contribution coefficient; shared ownership parks that entry and
applies the joint vector. Covers receive the same observation. This replaces the
former out-of-ledger reset without changing vote formulas or confidence coefficients.

The new public-evidence suite passes 32 checks: isolated probabilities, counterevidence,
duplicate announcements, all living listeners/covers, reversibility, no evaluation
RNG, and switching ownership on/off. Existing integration expectations of hard-good
victims were updated and its 64 checks pass. Psychologist relay neutrality now compares
against the same public death background, rather than incorrectly expecting the death
itself to have no effect. The full frozen suite, including trace parity, is running;
targeted evaluator, belief, integration and ownership checks pass.

The initial Q2 replay and paired runtime measurements were **invalidated** by
the full trace suite: appending public factors mutated a cached movement array,
allowing repeated queries to stack the event. Fixed by copying that array before
extension; a focused cache-isolation regression passes. Fresh replay and trace
measurements are recorded below. The invalidated run had nine shared listeners, zero
fallback and still failed 1 yes / 5 needed; its changed numbers are not tuning targets.
A ten-person Day-1 probe retains the exact pre-change behavior hash
`fe6dac94929d65dfbb959d26e2a134b30fb5e6a56fceb990af8bf1a14056765e` (2762 ms).

**Corrected measurement after the cache fix:** original #85/filed #89 still fails
1 yes / 5 needed, with nine shared listeners and zero fallback. Jory agreement
.775 -> .812; suspicion .596 -> .615. Full listener agreements, suspicion, vote margins
and tally are under `logs/migration/resume/silence/current-measurement.json`.

**Added runtime to flag:** a fresh paired replay under concurrent test/bot load measured
the first overnight transition 759 -> 1768 ms, the Day-2 meeting/search 6273 -> 7144 ms,
presentation 4368 -> 5034 ms, and nomination 1240 -> 1320 ms. Refreshing public evidence
now does real shared work where the reset was constant-time. These are single-pair
measurements, not an isolated scaling claim; progress continues above five seconds
as authorized. Reports are under `logs/migration/resume/victims`.

Further P2 audit item: live role compatibility currently treats accepted gift identities
and some role-bearing report contents as hard constraints before likelihood weighting.
Per-source honesty/accuracy migration must preserve legal liar/impaired alternatives
and joint unique-role assignments. The finite death adapter does not solve that
separate source-channel gap; do not compensate by tuning this replay.

## Public silence (Codex, Oct 24)

Silence is a dated public observation, shared by good listeners and evil covers.
Its existing -.12 native contribution is parked when shared ownership is active.
The shared factor is finite: the corresponding odds update at the .3 reference
prior, using the existing .45 alignment coefficient. It never proves the target's
alignment. A second receipt of the same silence counts once; a genuinely separate
silence on a later day remains another event. The card preserves its original
receipt but does not add a second factor to the already-public observation.

The public-evidence suite now passes 60 checks, including exact receipt ownership,
strict presentation, malformed/unannounced/wrong-date rejection, all listeners and
covers, and retraction. Roster and card-adapter suites also pass. The combined
event/cache-fix regular run passes **52/54 suites**, with only the reproduced
`test_social` and `test_text_ui` failures. The slow trace suite also passes all
45 checks after the cache fix. These reports are under
`logs/migration/resume/silence`.

**Added runtime to flag:** a paired ten-person Day-2 probe measured 3434 ms without
silence and 3828 ms with the public event/card (+394 ms, about 11%). Both evaluated
all ten listeners with zero fallback. This single pair ran under concurrent tests
and bot load. The opening replay contains no silence and isolates the Q2 cost above.

## Q4: weak refusals (Codex, Oct 24)

A first-person refusal is weak suspicion evidence, not proof of being out or of
holding/lying about a gift. Its maximum likelihood ratio is 1.5 (the evaluator's
existing lower threshold for weak evidence); stated fear reduces its log weight by
the existing native .25/.35 ratio. Poison does not invalidate ordinary speech.
Repeated reluctance from the same person, across receipts or days, supplies one
factor at the strongest attended weight. Quoted statements supply none.

Fear, withholding and any named role survive normalization. Invalid speakers,
subjects, dates, boolean fields and role names produce a named rejection. Exact
roots, presentation/retraction and native-entry parking use the existing shared
mechanism. No opinion/accusation route was reopened.

The new suite passes 43 checks, including actual strict presentations to every
listener/cover in seven- and ten-person towns. Nine targeted regression suites pass.
A ten-listener Day-2 pair measured 3357 ms without refusal and 3542 ms with it (+185 ms,
about 6%), with zero fallback. This pair does not show a significant added cost;
reports are in `logs/migration/resume/refusals`. Full trace/regular validation will
be repeated after the hint slice.

## Q4: tentative gift-family hints (Codex, Oct 24)

A structured family hint weakly supports its tentative good-gift claim, using the
same 1.5 weak-evidence odds ratio. It retains every role in its named package and
does not choose a role, assert a healthy reading, or establish a night outing.
Repeated hints from the same person count once. Incompatible family declarations or
an attended explicit gift declaration outside the family instead weakly undermine
that claim. Quoted declarations are not silently endorsed. This is ordinary
testimony; the separate P2 source/accuracy/role-assignment gap remains.

The normalizer preserves package and role alternatives; the adapter validates them
against public content. The filing guard permits this tentative support for a good
premise, while its existing rejection of merely restating a complete role claim
remains. The new hint suite passes 42 checks, including actual strict delivery to
every seven- and ten-person listener/cover, contradictions, repetitions, malformed
payloads and withdrawal. Refusal and argument suites also pass. The combined speech
source passes **54/56 regular suites**, with only the two reproduced baseline failures.

**Added runtime to flag:** one ten-listener Day-2 pair measured 3181 ms without the
hint versus 3558 ms with it (+377 ms, about 12%), all ten shared with zero fallback.
The extra report/attention work is included; this is not an isolated evaluator-only
cost. Reports are under `logs/migration/resume/hints`.

## P1 self/group presentation routing (Codex, Oct 24)

Raw self-defence previously returned thanks before its shared callback, discarding
the card's evidence about other people. Evil listeners also skipped their cover
assessment when included in a raw defence/accusation group. Those paths now hear
the original receipts and refresh collateral beliefs. Real evil can retain its
strategic reply; the returned engine flag reports whether the cover actually used
shared belief evaluation, matching the existing filed-deduction path.

The presentation suite passes 75 checks, including self support, collateral effects,
cover delivery, non-stacking and no extra game RNG for self-defence. Dialogue-decision,
ownership, live cognition and social-boundary suites pass. Newly covered self/group
paths now pay for real evaluation; their large-town marginal cost has not yet been
isolated. Curse capability and the remaining native fallback routes still need work.

## Intermediate bot measurements (frozen `0cfd073`)

These runs precede Q1/Q4 and the bot rejection fix. They are not final-migration
balance results and are not tuning targets. Seeds 1000–1149:

| Town / mode | Good wins | Wrongful / all executions | Evil executed | Completion |
|---|---:|---:|---:|---|
| 7 active, original baseline | 42 | 157 / 239 | 82 | 150 complete |
| 7 active, intermediate | 35 | 116 / 171 | 55 | 149 complete; 1 bot guard |
| 7 passive, original baseline | 8 | 119 / 147 | 28 | 150 complete |
| 7 passive, intermediate | 3 | 47 / 62 | 15 | 150 complete |
| 10 active, original baseline | 28 | 318 / 430 | 112 | 150 complete |
| 10 active, intermediate | 22 | 255 / 336 | 81 | 149 complete; 1 bot guard |
| 10 passive, original baseline | 20 | 227 / 307 | 80 | 150 complete |
| 10 passive, intermediate | 2 | 128 / 151 | 23 | 150 complete |

All four 150-case batches have finished with no script errors. Active bot guards
occurred at seven-person seed 1060 (fixed as described above) and ten-person seed
1011 (current-source recheck pending). Ten-person active/passive elapsed 7834/8403 s
with detailed tracing and concurrent work. Fewer executions and fewer good wins
are observations, not an established causal explanation or a passed balance
criterion. In particular, passive ten-person good wins fell 20 -> 2: this intermediate
result does not meet P0 sign-off. It predates Q1/Q4, Q2, event adapters and bot filtering;
current-source results are still required. Data and per-run script-error status are in
`logs/migration/resume/adapters/batches`.

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
