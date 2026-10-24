# Legacy migration progress

Updated Oct 24, 2026. Runtime: Godot 4.7.2 (confirmed by the user).

The migration is **in progress**, not finished. P1 is partly implemented; P3
consensus, public death/silence/Martyr events and Q4 speech/context slices are implemented.
The remaining P2 and P3 work, most of P4 and P5
remain. P4's execution-priority input is wired with a fixed zero coefficient.
Q3 and Q6 remain deferred. The Demon-victim rule now supplies finite 95:5
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

The presentation suite passes 72 checks, including self support, collateral effects,
cover delivery, non-stacking and no extra game RNG for self-defence. Dialogue-decision,
ownership, live cognition and social-boundary suites pass. Newly covered self/group
paths now pay for real evaluation; their large-town marginal cost has not yet been
isolated. Curse capability and the remaining native fallback routes still need work.

The playtest regression caught a missing social thank-you after routing self support
through the evaluator. Restored the original one-time +.03 rapport and its repetition
guard in the shared presentation boundary; receipt evaluation still runs first.
All six related suites pass, including the actual command-level self-support check.

## Public vote receipts (Codex, Oct 24)

The actual tally now publishes its public nominee, nominator, yes/no voters, player
vote, count, threshold and outcome. The bridge copies only those public fields.
Vote cards retain that receipt as neutral process context: they add no alignment
likelihood or guilt by association. This also supplies dated, complete voter data
needed for the forthcoming curse history model. Curse histories remain explicitly
unsupported until that model is complete.

The aggregate event is attributed to the town, keeping the existing individual
`vote_yes` records' social meaning. Tests verify it adds no second hostility/heat
credit, consumes no capture RNG, and does not pass non-public extra payload fields.
The adapter rejects unknown people, overlapping/duplicate voter sets, mismatched
counts/dates/outcomes and unannounced tallies. The new suite passes 49 checks,
including real native votes and strict delivery to every seven- and ten-person
listener/cover. The combined regular run passes **55/57 suites**, with only the
two reproduced baseline failures.

A ten-listener Day-2 pair measured 3170 ms without the card versus 3394 ms with it
(+224 ms, about 7%), all shared with zero fallback. This single pair does not show a
significant new runtime increase. Reports are under `logs/migration/resume/votes`.

## Martyr receipt identity (Codex, Oct 24)

Martyr and saved person are now named transport fields, preserved before the generic
subject set is sorted. Previously an alphabetically earlier saved person could be
assigned the Martyr's role. Legacy cards retain their actor-first public ordering;
new cards name both roles. Reordering a wrapper with explicit roles retains the
same receipt. The adapter requires a matching public substitution and distinct,
known participants. It never recovers their roles from hidden NPC state.

The public-evidence suite passes 70 checks, including the reversed-alphabetical
case and actual strict delivery to every living listener/cover. Martyr/Sexton and
presentation suites pass. This fixes transport; the native Martyr proof entry is
not yet migrated. The self/group-routing source also completed all 45 slow trace
checks, in addition to its active trace-on/off smoke parity.

## P3 shared Martyr proof (Codex, Oct 24)

A witnessed substitution now supplies one automatic public receipt and its known
gift identity, even without a player presentation. Notebook prose and reordered
explicit-role wrappers resolve to the same structured receipt. Native `martyr:<day>`
proof entries are certified and parked, including in evil cover minds. Their old
-2 contribution no longer remains as an independent second evidence layer.

Unlike the finite Demon-victim signal, the public Martyr rule proves both people
good. The shared projection cancels the full independent baseline while retaining
it under reversible ownership. Public reads retain that certainty between refreshes;
independent additions remain recoverable beneath it. Turning ownership off/on restores
exactly one native/shared contribution. The existing `cleared` knowledge flag still
exempts these people from native paranoia drift; moving priors remains P3 work.
Curse histories remain explicitly gated until dated current/original alignment is
supported, rather than carrying a pre-curse proof into a new alignment epoch.

Known public gift identity participates in role checks and their cache keys outside
the card attention budget. Empty public-knowledge fields are omitted in ordinary
cases. The isolated seed-692 and seed-4242 probes retain the exact pre-slice behavior
hashes (`fe6dac...` and `12ae7619...`, respectively); all ten listeners use shared
assessment, with no fallback. These are parity checks against `f1abd4b`, not the
older pre-Q1/Q4 hash for seed 4242.

The public-evidence suite passes **142 checks**, including every seven-/ten-person
listener and cover, saturated baselines, automatic ownership, duplicate receipts,
role identity, retraction and independent additions. Integration, presentation,
reading-challenge, cognition, Medium, ownership and factor-cache checks pass. The full
regular run passes **55/57 suites**, with only the two reproduced baseline failures.
The slow trace run of the frozen proof source is still running.

**Added runtime to flag:** an isolated native-event A/B measured 2 -> 45 ms for the
seven-person town and 3 -> 384 ms for the ten-person town. Before, the proof stayed
native; afterwards all six/nine surviving listeners have shared proof ownership,
with no capability issues. Reports are under `logs/migration/resume/martyr`.

## P2 reading provenance boundary (Codex, Oct 24)

The unnamed meeting relay previously said "Word reached me from the Seer" while
putting the referee's exact source identity into the listener's shared receipt.
Anonymous receipts now contain only the visible teller, gift, date and payload;
their fact identity is unchanged if the hidden source changes. Portable legacy
references also redact that private binding. The native compatibility route still
exists internally and is explicitly logged as a fallback: anonymous identity and
two-source honesty need their own latent model before this route can migrate.

An actual public "That was me" binds only that teller's anonymous report. Matching
content from a named speaker alone does not bind it. The named fact retains both
provenance paths, replaces the unresolved receipt, and acquires one shared owner.
Acknowledgement adds no weight, trust reward or RNG draw. Named NPC readings retain
the teller path too; repeated routes do not create new original facts.

`test_workshop_provenance.gd` passes 62 checks across seven- and ten-person towns,
including real meeting speech, public acknowledgement, cover minds, source redaction,
deduplication and the existing single corroboration draw. Six focused suites pass.
A frozen full regular run passes **56/58**, with only the two established baseline
failures. The prior shared Martyr slice also passed the slow trace suite (45 checks).
The provenance slow trace run passes all 45 checks. Logs: `logs/migration/resume/provenance`.

Paired ordinary town presentations remain fully shared (10 listeners, zero fallback):
seed 692 **2429 -> 2453 ms**, seed 4242 **2658 -> 2676 ms**. No significant time
increase. Seed 692 preserves the exact behavior hash. Seed 4242 differs only in
three newly retained `provenance_paths` arrays on named NPC reading receipts; its
probabilities, dialogue, RNG and all other recorded behavior are identical. This
is a declared transport change, not a numerical optimization. Anonymous fallback
timings are not used as performance evidence.

## P4 execution-priority plumbing, zero weight (Codex, Oct 24)

The shared union now exposes a separate provisional action input: the attended
posterior for each person, including the existing Insight/Confidence theory path.
This reuses the completed solve; it does not run another solve or read referee
truth. The output explicitly says it has not been action-tuned. Urgency and action
threshold calibration remain deferred. Public Martyr proof sets its action input
to zero as well as its posterior.

Good and cover minds retain this input only while shared ownership is active.
Disabling assessment, losing capability or refreshing an empty evidence set removes
it. Vote and nomination plumbing reads the input separately from suspicion and
crowd pressure, with `SHARED_EXECUTION_PRIORITY_WEIGHT = 0.0` fixed in content.
Decision traces expose that zero coefficient and the unused input. No Q3 tuning,
new urgency rule, suspicion adjustment or extra random draw was introduced.

`test_workshop_action.gd` passes 84 checks, including exact vote score, threshold,
margin and nomination parity at several boundary values, cover ownership, repeat
and capability-loss behavior. Four related suites pass; the frozen full regular run
passes **57/59**, with only the two established baseline failures. The frozen action
slice also passes slow trace (45 checks). Logs: `logs/migration/resume/action`.

Paired ten-listener presentations remain fully shared: seed 692 **2377 -> 2267 ms**,
seed 4242 **2610 -> 2584 ms**. No significant added time. Both recorded behavior
objects are exactly equal after removing only the newly stored action metadata.
The paired 54875 replay retains identical agreement, suspicion, vote margins,
delivery coverage and tally: **1 yes / 5 needed**, nine shared, zero fallback.
Only command/profile timings differ. P4 nightly baseline solves, public citing
reasons and bot integration remain; P5 deletion is still gated on the remaining
replacements and measurements.

## P2 source/channel likelihood foundation (Codex, Oct 24)

`evidence_channels.gd` represents separate gift honesty, gift accuracy within a
night-to-next-night poison window, whereabouts honesty and relay transmission.
Failed accuracy relaxes a report's content while retaining a truthful gift claim;
failed gift honesty relaxes both. A good person's whereabouts lie does not lower
their gift accuracy. Quotation retains the statement without endorsing its content.
A faithful Medium relay shares the original accuracy, retains the Medium's own
gift and visit, and supplies no independent copy of the original content.

`channel_likelihood.gd` is an exact reference marginalization over these states,
using the joint role/route solver within each conditional state. Competing claims
can be explained by dishonesty; impairment alone cannot excuse a duplicate unique
gift. A known good person can lie without forcing their alignment evil. In a
hypothetical Delusional world the model uses the impaired accuracy prior, and
inaccurate content can still happen by chance. Submitted assumptions integrate out
of the private baseline. Several paths to an inaccurate original content pay its
chance likelihood once.

An exact elimination skips channel variables once all constraints they affect are
inactive. Conditional solves and private baselines are shared across states. The
reference can evaluate CaseEval's compact representatives and their multiplicity;
tests compare every legal world's baseline, posterior likelihood and accepted
content against full enumeration at seven and ten people, including modifiers,
private evidence and Medium routes. The three channel suites now pass **49 checks**.
A frozen full regular run passes **60/62** suites, with only the two established
baseline failures; the production behavior is unchanged from the action slice,
whose 45 slow trace checks passed.

This foundation is **not connected to live assessment yet**. That integration must
replace the unconditional `CaseEval._class_fits` / `claims_compatible` gate, supply
separate hearing and accuracy priors from the live contract, and replace the
independent-per-reading accuracy distribution in `Jury._provisional`. Retaining
one of those gates would still discard the very lying/impaired alternatives the
channel model is meant to assess. Bounded attention and private rejection handling
must retain the difference between a heard statement and its disputed contents.
No live fallback or reduced-coverage timing is being claimed as progress here.

Reference benchmark, native ten-person seed 692, three publicly stated readings
from three sources: **27 conditional states, 15,120 worlds**. Full enumeration took
**3097 ms** for one listener; compact representatives took **549 ms** (1,368 classes),
with the same likelihood mass. This is additional work compared with the old
kernel, not a measured whole-town presentation or a live performance regression.
`tools/profile_channel_likelihood.gd -- --npcs 10 --sources 3 [--classes]` reproduces
the comparison. Logs: `logs/migration/resume/channels`.

Pause checkpoint refinement: faithful paths materialize one canonical original
predicate while retaining each route's acceptance and the Medium's separate visit.
Conflicting payloads claiming the same original produce an explicit issue. Only
gift report contents pay a false-content chance likelihood; declarations and
whereabouts testimony already use their shared honesty channel. Tests verify that
repeating a gift declaration adds no likelihood, restating a private declaration
does not improve the case over its baseline, and a refuted alibi selects testimony
dishonesty without damaging the independent gift channel. Invalid original timing
is rejected before canonicalization. These changes remain offline and introduce no
live presentation cost. Final checks: `logs/migration/resume/channels/pause-final`.

## P3 defence repeat identity (Codex, Oct 24)

Native compatibility defences previously used `def:<person>:<day>:<move>`, so the
same explanation reduced suspicion again on each later day. They now use stable
semantic identities: a named gift, a confessed secret, a persistent red-herring
claim, a rival about the same other person, or a challenge to an exact original
reading. Fear and desperation are two wordings of the same plea. A challenge to a
genuinely different original reading remains distinct.

Gift and secret excuses keep the strongest complete hearing. Strength and trust
from different hearings cannot be combined into a stronger path than either
actually supplied. All first-hearing move strengths, regard weighting and the
existing Confidence coefficient are retained; Q6 remains deferred. Evil covers
receive the same stable ownership. This fixes the repeat bug in the compatibility
route; converting the moves into shared claims/challenges still remains in P3.

`test_defence_repeats.gd` passes **39 checks** across seven- and ten-person towns,
including different plea wording, exact challenge roots, stronger hearings, trust,
Confidence, covers and RNG. Five related suites pass. A frozen full regular run
passes **61/63** suites, with only the two established baseline failures. Its
slow trace run passes all **45 checks**.

Paired ordinary fully shared ten-listener presentations: seed 692 **2451 -> 2386 ms**,
seed 4242 **2674 -> 2749 ms**. No significant increase. The paired 54875 replay has
identical agreement, suspicion, vote margins, coverage and tally: **1 yes / 5
needed**, nine shared, zero fallback. Logs: `logs/migration/resume/defence`.

## P2 exact original reading keys (Codex, Oct 24)

Native reading entries now use the canonical original receipt, rather than only
source/day/gift. Distinct same-day contents or observation phases get separate
owners. Rewording, unordered groups, sharing flags and referee annotations do not
create another original. Board facts use the same canonical key and respect an
explicit observation stamp. Source lookup, spoken reading identity and withdrawal
continue through `Mind.info_eid`, so they find the intended original rather than
the first matching source/day entry.

The shared ledger parks each exact native contribution and jointly assesses all
original facts. Old coarse entries remain usable when their recorded exact receipt
identifies one original. Missing or ambiguous proof still produces an explicit
capability issue; it never chooses a sibling arbitrarily. If an identified old
record coexists with a new one, the original is counted once at the strongest
complete hearing weight. A weaker duplicate neither stacks nor weakens it.

`test_workshop_reading_identity.gd` passes **75 checks** at seven and ten people,
including strict delivery to every good/cover listener, canonical identity, native
retraction, diagnostics, old/new coexistence and no assessment RNG draws. Eight
related suites pass. The frozen regular run passes **62/64**, with only the two
established baseline failures; the final explicit-stamp edge case also passes its
targeted suites. The frozen slow trace run also passes all **45 checks**.
Logs: `logs/migration/resume/reading-identity`.

The paired 54875 replay retains identical agreement, suspicion, vote margins,
delivery coverage and tally: **1 yes / 5 needed**, nine shared, zero fallback.
This is an identity/coverage change, not a numerical optimization; recorded native
ledger and dialogue keys change. Ordinary ten-listener timing was 2731 -> 2754 ms
(692), and 3935 -> 3006 ms (4242) under concurrent test/bot load. Reversed replay
pairs measured `present 89` at **4629 -> 4974 ms** and **4880 -> 4787 ms**: no
consistent presentation regression. Nomination was **1205 -> 1320 ms** and
**1333 -> 1389 ms**, an observed **56–115 ms increase (4–10%)** worth tracking as
the longer keys flow through the live contract. All measurements retained full
shared coverage.

## Current bot comparison interrupted at user pause (frozen `0e60614`)

A fresh 600-game comparison was started from the frozen channel-foundation snapshot
(production behavior `d6eb589`, before the defence-repeat fix). It uses seeds
1000–1149, 150 games in each of seven/ten-person active/passive modes. Detailed
state sidecars are disabled using the already parity-checked `--no-trace` switch;
ordinary developer logs remain. The user requested a pause after the current step,
so both workers were stopped. Ten-person active finished **29 cases** (1000–1028),
passive **25 cases** (1000–1024), with no printed script errors in either partial
log. Seven-person rows had not started. No final batch metrics were produced; these
partial runs do not satisfy the comparison or P0 sign-off. Status files record the
interruption; partial logs remain in `logs/migration/resume/current-batches`.

## Paused checkpoint (user, Oct 24)

The requested current channel-reference step is complete. No implementation or bot
jobs remain running. The migration is still incomplete: next is live joint-channel
integration (replacing both the hard report gate and provisional reading model),
then remaining anonymous/Medium and temporal histories, shared defences/NPC shares
and priors, P4 baseline/reasons/bot work and P5 legacy deletion. Psychologist stays
context-only; Q3/Q6 remain deferred. The latest replay is still **1 yes / 5 needed**
with nine shared listeners and zero fallback. Its result has not been tuned.

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
1011. Both now finish on the current self/group-routing source, with no script error
or guard exhaustion. The ten-person 1011 result is exactly equal with detailed trace
on/off (104/111 s under concurrent load). Seven- and ten-person seed 1000 smokes
also finish. These four-case checks are not replacement balance batches.
Ten-person active/passive elapsed 7834/8403 s
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
