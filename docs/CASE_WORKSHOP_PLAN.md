# Case Workshop: revised implementation plan

Updated October 22, 2026 after reviewing the user's pasted Opus discussion against
the Workshop and main simulation. Slices 1–3 are now implemented and verified
on `codex/case-workshop`, including the case/line/evidence structure and a controlled
soft-factor convergence experiment, bounded Insight and confidence persistence.
The next UI step is delivered as a fixture-692 card canvas: movable evidence and premise
cards, shared answers, directed links, merged contradictions and a separate jury window.
The separately approved pre-Slice-4 step now adds scoped intermediate-claim assessments
and simultaneous collateral suspicion effects with shared provenance and retraction.
Slices 4 and 5 are delivered as selectable bounded movement/soot, poison/recovery
and Revenant/restoration experiments. Their mechanisms, controls, tests and limits are
documented in [CASE_WORKSHOP_EXPERIMENTS.md](CASE_WORKSHOP_EXPERIMENTS.md).
Current behavior is documented in [CASE_WORKSHOP.md](CASE_WORKSHOP.md). The Workshop
plan is complete within its stated fixture scope. Production integration, arbitrary
histories and deferred mechanics remain separate follow-on work.

## Direction

Keep the card-question interface: attach evidence, answer as much as you can, choose
what you want the listener to believe, and present or revise the case. Unknown answers
are useful. Players should not have to build logical expressions or complete a world.

Separate four things internally and explain them in ordinary language:

1. **Evidence:** what someone reported or what the player observed, with provenance.
2. **Assumptions:** which reports are accurate, proposed identities, and explanations
   such as a gift outing or a poisoned reading. A selected answer is not new evidence.
3. **Consequences:** what follows from those assumptions, what remains possible, and
   what conflicts. Distinguish consequences of reports from consequences of player choices.
4. **Listener response:** what the NPC noticed, believes, doubts, and consequently changes.

Use a complete conditional validator as the referee, with a separately bounded NPC
reasoner. Neither receives the scenario's hidden truth. Keep the current trust,
suspicion, confidence, stance and replaceable-ledger shape while experimenting.
Do not replace the main game's suspicion or voting systems in this proof of concept.

## One case, several converging lines of reasoning

The player should be able to build one case containing several named lines, each
with evidence, proposed answers, assumptions and an intermediate conclusion. For
example, the top-level claim might be “Constance is evil”, supported by:

| Line | Its contribution to the combined case |
| --- | --- |
| Surveyor + Rumormonger + Dowser | Conditional on accurate readings, Hollis and Lian are evil and the Constance/Nisha alternatives remain. This line supplies a relationship between their identities. |
| Constance's movements and crime-scene traces | Compare how well the observations fit the Constance-evil and Constance-good explanations, including a possible genuine Medium gift. Mere outings may fit both; route, timing and trace details can distinguish them. |
| Evidence supporting Nisha's Warden claim | A credible protection account and a relevant quiet night can favor a genuine Warden explanation. Through the first line, evidence favoring Nisha being good also favors Constance being evil at the relevant time. |

This is a design example, not a new finding about the original case-692 trace. A
quiet night is not proof of Warden protection: attack eligibility, other protection,
Veteran survival and the knell matter. The scripted Workshop itself uses Veteran
survival for its first attack. Only information available to the listener may affect
its explanation; the actual hidden cause is not an inference input.

**Convergence is different from corroboration.** Two paths can independently support
the same conclusion, but one line can instead establish alternatives while another
helps choose between them. Neither line has to establish the final accusation alone.

- Evaluate lines against a shared set of hypotheses. Join on person, role, alignment
  epoch, reading/outing time and underlying event identity. The current separate
  alignment and movement solvers need an explicit bridge for the relevant roles,
  actions and trace causes; adding their final suspicion scores is not that bridge.
- Accepted hard constraints restrict which joint explanations are possible. Soft
  evidence changes their relative support. Both Constance/Nisha alternatives may
  remain possible while one becomes more persuasive. Preserve that distinction in
  replies and diagnostics; do not silently discard a low-weight alternative as false.
- “Separate lines” describes how the player organizes a case, not statistical
  independence. Shared witnesses, incidents and fault hypotheses remain shared.
  A reused sighting or a derived intermediate conclusion is not fresh evidence.
- Keep simultaneous premises distinct from alternative explanations. The interface
  should distinguish “also supports this” from “another possible explanation” without
  asking the player to write logic. Incompatible branch assumptions cannot secretly
  support different parts of one supposedly coherent world.
- A supported Medium explanation may make Constance's outings neutral or even favor
  her innocence; repeated outings do not automatically increase guilt. Compare the
  actual evidence under both explanations. A bare Medium claim does not settle them.
- Doubting a reading can weaken the connection between Nisha and Constance while
  leaving movement evidence intact. Discrediting a sighting can remove its effects
  wherever it was cited without erasing the independent reading argument. Recompute
  jointly; do not score an intermediate conclusion again as an independent premise.
- Allow red-string connections or grouped cards to express these links, with readable
  labels such as “supports”, “explains” and “conflicts with”. References point to the
  same evidence wherever shown. Start with groups and explicit links; freeform board
  layout is optional presentation work, not a prerequisite for testing the reasoning.

**Delivery:** slice 1 establishes the case/line/evidence structure and references;
slice 2 tests shared dependencies and convergence with a controlled soft factor;
slice 4 supplies the actual movement/trace likelihood model. The controlled factor
must be visibly marked as test input, not shipped evidence tuning. Test the combined
case as well as each line alone. Under the same considered premises, changing only
grouping, links that restate existing support, card order, venue or intermediate-card
wrappers must not increase evidence weight. Explicitly connecting lines can focus an
NPC's attention on an inference it previously missed; log that as newly noticed
reasoning, not newly acquired evidence or a repeatable presentation bonus.

**Acceptance checks:** with the reading premises accepted, evidence favoring Nisha's
innocence shifts the Constance/Nisha comparison; evidence equally expected in both
alternatives does not favor either; sufficiently strong contrary evidence can reverse
the preference without changing the referee's logical result; removing a key reading
weakens the indirect inference while preserving direct evidence. Shared sightings
are counted once, mutually incompatible branch assumptions are exposed, and a
low-Insight listener can follow individual lines without necessarily noticing their
connection. Log when that connection was actually considered.

## What the review changes

| Opus proposal | Decision and qualification |
| --- | --- |
| Premises in, consequences derived | Adopt. Preserve explicit player hypotheses as a third input, rather than treating everything that is not a report as an established conclusion. |
| Registration distinct from identity | Adopt. Ask what registered and optionally why. Offer causes specific to that gift: a Seer Demon ping is not interchangeable with a Dowser evil ping; Red Herring is not a universal explanation. |
| Referee distinct from an NPC's limited reasoning | Adopt. Insight controls attention and search; confidence controls commitment or movement. A missed alternative does not turn a belief into a certified logical consequence. |
| Hard constraints and soft patterns in one case | Adopt the interface and evidence model. Introduce probabilistic pattern evaluation in a bounded experiment, not a full probabilistic town simulator immediately. |
| Derive evidence strength from the generator | Use generator mechanics to inform and test likelihoods. Account for routes, observation opportunities and shared causes before turning generation rates into evidence weights. |
| Question a report; derive a conflict question | Adopt. Cite exact reports, preserve their dependencies, and permit unresolved conflicts. Questioning a report is not evidence that its source lied. |
| Retain the ledger and social machinery | Adopt. Existing source/reading doubt and retraction are assets to preserve. The Workshop's strongest-path rule still needs a replacement that permits corroboration. |
| Accept only forced conclusions | Do not adopt as a persuasion rule. Conditional arguments and soft evidence must be able to influence belief. Reserve “must follow” for entailment, and report subjective agreement separately. |
| One working world determines suspicion | Experimental only. A current theory can explain behavior without collapsing uncertainty into categorical guilt or innocence. Compare it against a small set of alternatives. |
| Hide all cross-card results behind NPC interactions | Defer to production playtests. Keep full diagnostics available in the Workshop; test an optional player-facing presentation with fewer spoilers. |

## Correct the teaching example first

These results are conditional on the current seed-692 Workshop rules: three evil
people, one good Marked person, the displayed block assignments, and accurate reports
whose sources are good and have functioning claimed gifts. This fixture is not a
reconstruction of the original case trace.

| Reports accepted, before player answers or private knowledge | Consequences |
| --- | --- |
| Surveyor only | Every block has a positive registration. Bartholomew being good does not exclude him being Marked, so Constance is not uniquely identified as Chapel Hill's positive. |
| Surveyor + Rumormonger | Hollis is evil: the Market needs a positive, Merrin is good, and the Marked is Constance or Nisha. If Nisha is Marked, Constance is evil. If Constance is Marked, the Square's evil can be Nisha, Odette or Agnes. Twelve compatible alignment/Marked assignments remain. |
| All three core readings | Hollis and Lian are evil. Two assignments remain: Constance evil/Nisha Marked, or Nisha evil/Constance Marked. |
| All three, plus Nisha's knowledge of being good at that time | Constance evil/Nisha Marked is the remaining assignment. |

Odette's knowledge of being good reduces the second row to nine assignments. Adding
the Dowser reduces that to two but does not newly force Hollis: he was already forced.
The additional persuasive value is a second supporting route, not the bare reduction
in the number of worlds. Compatible-world counts are not automatically probabilities.

Opus's first stage table (pasted discussion lines 48–50) skips these qualifications.
Its “either/or” sentence at line 20 also reverses the relationship: Constance evil and
Nisha Marked occur together in one branch; they are not mutually exclusive.

## Initial implementation audit (before slices 1 and 2)

| Area | Verified structure and implication for the plan |
| --- | --- |
| Conditional logic | [solver.gd](../workshop/solver.gd) enumerates alignment/Marked assignments and separate night walker sets. It does not yet model joint role, route, health or transition histories. |
| Credibility | [jury.gd](../workshop/jury.gd) evaluates subsets and retains the strongest weighted path. Distinct-source qualities multiply; equal alternate paths add nothing. These qualities are tuning scores, not calibrated probabilities. |
| Convergence | Reading support and outing patterns compete for the strongest path; pattern support is only selected for a suspicious conclusion. The prototype does not jointly reweight the reading alternatives using movement or trace explanations. |
| Personal knowledge | The jury adds its own reports as reliable constraints. Future health hypotheses must distinguish knowing what result one received from knowing that result was accurate. |
| Claim citations | Night-gift explanations recognize selected explicit claim cards. Agnes's Lamplighter report is not currently converted into a usable claim citation. The UI does not expose a specific citation link. |
| Conflict arguments | All selected cards supply the scope. The conflict conclusion has coefficient zero and no persistent report-doubt effect. Replacing an earlier accusation can still retract its old effect. |
| Existing belief engine | [mind.gd](../sim/mind.gd) already tracks justification supports, period-specific reading doubt and source honesty, and recomputes effects. [test_beliefs.gd](../tools/test_beliefs.gd) contains regressions for discrediting a source, chained deductions, own poisoned readings and unaffected ordinary testimony. |
| Confidence and Insight | Workshop confidence currently scales the numerical effect; it does not bound reasoning. Main-game sighting recall uses `2 + round(4 * Insight)` (2–6 people), not the pasted discussion's 3/4/5. Recall capacity is not automatically the right reasoning budget. |
| Test coverage | Existing Workshop tests cover mirror worlds, replacement/retraction, duplicate reports, outing incidents, conditional choices and hidden-truth independence. They do not establish the new proposals below. |

## Slice 1 — make cases and objections explicit

**Deliverable:** a player can distinguish a report, its associated role claim, their
own explanation, and a specific conflict without needing implementation terminology.

- Give each evidence item a stable underlying fact/event identity, reporting source,
  event or reading time, statement time, learned time and provenance. Preserve these
  through relays, derived cards, export and replay. Do not confuse when a reading was
  received with when its contents were communicated.
- Expose an associated role claim from a role-based report as a linked assertion,
  not an independent corroborating witness. Accepting “Agnes claims Lamplighter”
  must be possible without accepting her count as accurate. Record whether an
  explicit role claim was heard or the attribution is implicit in the report.
- Replace “Night gift (cite the claim)” with a visible supporting-claim picker. Show
  the chosen source and time, plus a plain explanation of why the gift could explain
  this outing. Include “other/unknown”; an explanation label alone grants no credit.
- Separate “who registered?” from optional “why?”. Allow partial answers and clearly
  mark which further conclusions depend on those answers.
- Give “these reports conflict” explicit report selection and a statement of the
  incompatible claims. Hide the irrelevant accused-person selector. An optional
  “I think this report is wrong” choice targets a report, not automatically its source.
- Compute inclusion-minimal conflicting sets: removing any member resolves that
  conflict. Do not promise the globally smallest set or blame every member. There
  can be several distinct conflicts. An unresolved conflict is a legitimate case.
- A derived conflict card links to its original evidence; it is not a new independent
  fact. Preserve partial slots: three answers plus one `?` on a four-slot card is
  valid. Prevent duplicate/out-of-range selections; let players present substantive
  mistaken or conflicting theories.

**Acceptance checks:** cite Agnes's claim without accepting her reading; cite a
wrong-person or wrong-time claim and get an intelligible objection; select a specific
alibi/sighting conflict among unrelated cards; preserve unresolved slots; a derived
conflict and its originals cannot multiply support; save/reopen preserves all links.

## Slice 2 — corroboration, doubt and revision

**Deliverable:** a new independent route can strengthen a case, while shared premises,
repeated presentations and relayed copies cannot manufacture extra evidence.

- Represent minimal sufficient support sets and their shared premises. For Hollis,
  the core example has routes `Surveyor AND Rumormonger` and `Dowser AND Rumormonger`:
  together, `Rumormonger AND (Surveyor OR Dowser)`. This is a description of these
  support routes, not a universal formula for all conclusions.
- Replace strongest-path aggregation in an experimental evaluator. Evaluate shared
  assumption states once, or use an equivalent dependency-aware calculation. Do not
  simply sum the two routes or apply an independence formula to overlapping proofs.
  A shared witness, poison episode or relay can correlate otherwise different reports.
- Keep logical entailment, credibility of premises, subjective conviction and actual
  attitude change separate in the assessment. Replies should identify which one is
  uncertain. “I don't buy that conclusion, but the sighting concerns me” is legitimate;
  an unexplained “reject” followed by a hidden positive effect is not useful feedback.
- Compare the old tuning with the new aggregation in the jury inspector. Do not
  silently interpret the existing trust/quality scores as probabilities. If a
  probability-based comparator is used, label its assumptions and calibrate it.
- Adding unrelated optional support must not weaken an existing proof. An argument
  that newly *depends* on another uncertain source can be weaker, even when its world
  is more specific. Contrary evidence must still be able to weaken a case. Never
  reward case length or world-count reduction by itself.
- Keep report accuracy, claimed role, health at reading time, reporting honesty and
  source alignment distinct. Evil people can report truths; good people can lie.
  An unreliable report is not necessarily the logical negation of its contents.
- A supported conflict creates localized uncertainty over which premise failed.
  It does not immediately label both witnesses evil. Retraction should affect all
  conclusions using that premise and preserve independent surviving support.
- Preserve replaceable effects. Remove an old case's effects before reassessing it.
  Before supporting multiple simultaneous cases, deduplicate their shared evidence
  and prevent circular credibility reinforcement across cases, not only within one.

**Acceptance checks:** the Dowser strengthens Hollis's case under a fixture where
Surveyor and Dowser supply independently uncertain routes; Merrin is counted once;
doubting Bart leaves the Dowser route; doubting Merrin weakens both routes; unrelated
cards add no credit; repeated, reordered, relayed or renamed evidence adds no credit;
contradictory evidence can weaken a case; replay and venue changes preserve results.
At maximal certainty or complete redundancy, extra support need not move suspicion.

## Slice 3 — bounded NPC reasoning as a controlled experiment

**Deliverable:** low- and high-Insight jurors can react differently for visible reasons,
without changing the referee's answer or making low-Insight allies automatic converts.

- Add attention and alternative-search budgets, using named presets initially. The
  presented case gets attention priority; private knowledge is always checked. For
  oversized cases, report which parts were considered rather than silently treating
  ignored claims as validated. Do not copy sighting-memory capacity without testing.
- Keep `entailed under these premises` separate from `persuaded after limited search`.
  A juror can accept a plausible theory without finding its rival. The log must retain
  the limited search and the referee's separate diagnostic. Empty or incomplete search
  is never proof. Repetition must not reroll insight until the player gets agreement.
- Count/shape of dependencies can inform difficulty, but minimal conflict size alone
  is not reasoning depth. A direct self-contradiction and a multi-step temporal chain
  should not be treated alike merely because they contain the same number of cards.
- Personal knowledge means the listener's available experience, not hidden truth.
  Knowing an ability returned “yes” does not guarantee health; a Sleepwalker may not
  know they went out. Apply role/self-knowledge exceptions according to actual game
  mechanics. Time-stamp knowledge of alignment and respect conversion/restoration.
- Test confidence as persistence of a provisional theory, alongside the current
  effect multiplier. Do not stack both dampening mechanisms without comparing them.
  Insight is reasoning capacity, trust is source acceptance, and confidence is
  commitment; none substitutes for the others.
- “Perhaps Fenwick was poisoned” must incur a visible assumption and respect legal
  causes, targets and timing. Confidence cannot invent a cost-free exception that
  immunizes a preferred theory against every contrary report.
- Compare a preferred partial theory plus retained uncertainty against a small
  shortlist. Do not derive all suspicion from one arbitrary completed world. Keep
  limited autonomous reasoning as an option; player presentation focuses attention
  without necessarily being the only way NPCs ever combine evidence.

**Acceptance checks:** same premises produce identical referee results across Insight
levels; a low-Insight juror can provisionally accept Constance while a stronger rival
search finds Nisha; neither is mislabeled a different logical truth; all jurors catch
available direct self-knowledge conflicts; new contrary evidence can dislodge a
confident theory; repeat presentations do not farm fresh reasoning rolls. Log the
premises noticed, alternatives tested and precise source of each attitude change.

**Implemented experiment:** deterministic Low/Medium/High attention and search profiles;
direct candidate construction independent of the referee; considered/ignored evidence
and line connections; tested alternatives and explicit provisional versus exhaustive
statuses. Comparisons clone the same juror and starting attitudes. Private alignment,
reading receipt and known whereabouts are protected without making gifts infallible.
Confidence persistence is an alternative to effect scaling, remembers only a partial
target/epoch commitment, and can revise without inventing illness explanations.
Repetition is stable; version-5 replay reconstructs theories and all character effects from presentations.
This slice does not add autonomous town-wide theory construction or temporal exceptions.

## Separate step before Slice 4 — evaluated claims and collateral effects

**Delivered:** named intermediate claims are assessed in their own evidence scope,
within the headline's attended evidence. The jury distinguishes “Hollis follows if these
reports are sound” from “Constance versus Nisha remains unresolved”, disputes incorrect
intermediate claims, and reports what a branch contributes to its parent. Claim-less
groups preserve nested claims. Original sources remain the inference inputs; accepted
intermediate labels never become independent testimony or extra suspicion awards.

Every person's evil/good support is compared from one frozen baseline. The comparison
subtracts what private evidence and prior rankings already supported; actual suspicion
can rise or fall. Private good alignment is protected. Headline conviction remains a
separate diagnostic. One vector replaces this case's prior effects on all people;
source credibility cannot feed back halfway through a presentation. Shared reports,
duplicate derivations, venue changes and repeats cannot stack effects. Counterfactual
branch diagnostics retain roots cited through other paths and are not additive awards.

The existing outing-pattern route and alignment comparison use a provisional stronger-
absolute-effect envelope rather than being summed when they can describe the same
incident. This can hide weaker independent contributions; Slice 4 must replace that
conservative bridge with the shared movement/trace model. It is not new final tuning.
Bounded projections share public attention and use per-conclusion search limits; a total
town-wide reasoning-work budget remains future work. Conflict-only presentations assign
no alignment effects. Multiple simultaneous cases and cross-case provenance are deferred.

**Verified in `tools/test_workshop_consequences.gd`:** a Constance headline affects
Hollis and unclaimed Lian, leaves the core Constance/Nisha ambiguity, and can exonerate
others; direct/grouped/duplicate derivations have equal effects; mistaken intermediate
claims are challenged; claim-less nested groups preserve scope; all effects are stable
on repeat and retract together, including at clamping limits; person order creates no
feedback; unattended or firsthand-rejected reports supply no collateral pattern effect;
version-4 history replays all effects and claims after edited social inputs. Jury controls
display all consequences and claim-to-parent explanations.

## Slice 4 — soft evidence in the same case interface

**Delivered:** the Movement & soot fixture uses one activity/route/haunt likelihood
across sightings, explicit coverage, evening observations, crime-scene material and
personal items. Credible gift/private-errand claims change the good explanations;
Marked excludes an additional secret modifier. Repeated nights share latent causes,
duplicate facts are conjoined, and eligible passers remain alternatives. The old
pattern heuristic and 2× bonus are disabled in this fixture. Conditional trace/drop
rates are checked against 10,000 actual generator calls; profile priors remain exposed
experimental assumptions. Actual role-assignment/route planning for a whole town is
outside this bounded deliverable. See the experiments guide for controls and limits.

**Completed prerequisite/UI step:** citing a home alibi as a statement to challenge
no longer endorses its contents beside a contradicting observation. The 692 canvas
automatically merges that direct contradiction, preserves both originals for inspection
and unlinking, and can route its circumstantial contribution through a suspiciousness
premise into an alignment case. The only new factor is a visible, uncalibrated 2×
comparison for the challenged alibi, conditional on observation credibility. A false
account does not establish intent or evil. The movement/trace work below is delivered
as a separate selectable experiment. The canvas preloads fixture evidence
instead of integrating transfer from the live board.

Evidence and premise links compile to original roots. Direct/chained versions of the
same three-reading argument are equivalent; intermediate claims supply no independent
facts. Claim-less groups use the same premise-card object. Answer windows share one
interpretation per evidence copy, and premise windows hold scoped identity assumptions.
Future duplicate interpretations and collapse/expand behavior are deferred.

**Deliverable:** compare two recurring patterns, unexplained outings and crime-scene
soot, using explicit hypotheses and observation opportunities. Keep this bounded to
fixtures before expanding to every physical evidence type.

- Reuse explanation slots and citations. The relevant question is “how would this
  evidence arise in this explanation?”, not simply “how many suspicious cards exist?”
- Separate an underlying incident from reports about it. Two witnesses can increase
  confidence that one outing happened without making it two outings. Different nights
  are distinct incidents but may share uncertain role, route or witness assumptions.
- Model or marginalize the route, eligible action, observation opportunity and trace
  cause needed by each fixture. Role does not always determine destination or activity.
  Do not equate being unseen with staying home. Do not give an assumed explanation
  the weight of evidence supporting that explanation.
- Share or reference simulation parameters where practical, but calibrate the
  observation model against generated samples. The 4.2%/1.8% personal-item rates are
  conditional on walking; finding a particular item also depends on location and
  search. Crime-scene misdirection requires an eligible passer, and a matching passer
  need not change the trace. Generic dropped material comes from the walker's home
  block; crime-scene trace material comes from an evening location. Keep them distinct.
- Combine nights conditionally on shared hypotheses. Do not blindly multiply marginal
  weights for each card. Expose both occurrence confidence and incriminating strength.
- Keep likelihood-based belief and the social decision to accuse/vote separate. Apply
  personality effects once in a documented place, then compare with current tuning.

**Acceptance checks:** a second independent night contributes; copied observations
do not; credible gift/secret explanations reduce incrimination without erasing the
sighting; lack of observation is handled according to coverage; repeated soot can
favor a shared evening-location explanation while retaining plausible passer causes;
changing the hidden actual cause alone cannot change the NPC's assessment. Validate
likelihoods against the specified generative conditions, not just hand-picked examples.

## Slice 5 — temporal fault and conversion stress tests

**Delivered:** separate legal poison/recovery and Revenant/restoration fixtures; dated
reading versus reporting credibility; one shared health cause per supported interval;
explicit unsupported fault hypotheses; epoch selectors and dated assumptions; unknown
eligible conversion candidates; public withdrawal without erasing original readings;
native curse/totem restoration, cover-boundary filtering, and version-5 canvas/history
replay. Native generator paths are exercised, and hidden causes are excluded from
assessment. Scion succession remains reserved and explicitly unsupported, as planned.
The fixed public chronology is known to these jurors; uncertain or multiple event
histories and production NPC integration are not implied by completion of this slice.

**Deliverable:** small deterministic fixtures, not a full campaign integration: a
poisoned period with recovery, and a Revenant conversion followed by restoration.

- Separate event/reading time, reporting time and learning time. Model alignment,
  role and health in explicit intervals/events. A later conversion does not retroactively
  corrupt an earlier healthy reading; a later dishonest retelling is a different issue.
- “Question this report” can reference a supported or hypothetical fault. Multiple
  reports in the same affected interval share that cause. Match the real poison
  duration and transition rules rather than assuming a universal night-sized window.
- Revenant activation, eligibility and totem destruction remain event evidence with
  their own questions and dependencies. Per-report menus alone cannot represent the
  transition. Identify which person acquired the curse at that event; avoid ambiguous
  wording that conflates the executed Revenant with the newly converted person.
- Scion succession has different timing and role implications; reserve the schema
  for it but defer its implementation until the two initial fixtures pass. Do not add
  “misremembering” or another failure cause unless the game actually supports it.
- Reuse the same epistemic boundary for evil shadow selves, with only their permitted
  cover knowledge. Restoration must follow current knowledge/memory rules rather
  than simply handing the former evil NPC everything the simulation knows.

**Acceptance checks:** an earlier good reading survives later conversion; a retelling
after conversion can be doubted separately; affected-period doubt retracts dependent
conclusions without damaging ordinary sightings or other nights; restoration does not
leak erased knowledge; invalid poison/transition explanations are rejected or marked
unsupported; exported chronology reproduces the same assessments.

## Performance and integration gates

The current solver considers 840 alignment/Marked assignments before report filtering
and up to 1,024 walker masks per night. That is not a benchmark for all role, route,
fault and conversion histories. Four to six claims can still leave many hidden choices.

Measure cold and cached assessment time, number of assignments/search nodes, and
conflict extraction separately as each slice lands. Cache by normalized evidence,
premises, knowledge and relevant model version. Weight changes must invalidate weight
results even when the logical worlds are reusable. Prefer pruning and separating
irrelevant dimensions before considering C# or GDExtension. Record the hardware and
choose an interaction latency budget from actual measurements, not an NPC-count claim.

For each implemented slice, extend the focused semantic/UI tests, verify save/replay,
and visually exercise the new interaction. Run existing argument/belief regressions
when an adapter touches the main engine. Documentation review is not runtime validation.

Only after the Workshop experiments pass should a separate integration plan adapt
private presentation, meeting presentation and nomination speech to the same semantic
assessment. Venue may change audience, disclosure, pressure and voting consequences;
it should not reinterpret the same underlying argument or award duplicate evidence.
Keep old/new comparisons available until persuasion, social pressure and voting effects
can be inspected independently.

## Disagreements and decisions left open

References below identify line numbers in the user-provided Opus paste, headed
“Answering the card's question: my take” and “Two clarifications”, reviewed October 21.

| Passage | Qualification or disagreement |
| --- | --- |
| Lines 18–20: “None … can be fixed by retuning”; “a scoring system can't” reopen options | Retuning cannot recover a lost joint constraint. But some reply/weight mismatches can be tuned, and this game's scoring ledger already retracts dependent evidence. Extend that foundation instead of discarding it. |
| Lines 20, 48–50: the Constance/Nisha branches | Corrected above. Good Bart can be Marked; two readings do not yet force the full Constance/Nisha mirror. |
| Lines 33–42 versus 188–192: only forced conclusions earn acceptance, then low Insight accepts a coherent choice | These are different policies. Use precise conditional validation plus defeasible subjective persuasion. A threshold may simplify the explanation, but retain graded credence for weighing uncertain premises. |
| Lines 82–89, 163–170: read off generator weights; no extra dimensions; corroboration nearly factual | Generator rates are inputs, not ready-made posterior odds. Outing reasons depend on actions/routes and circumstances; sightings and testimony also have uncertainty. Marginalizing nuisance variables is possible, not free. |
| Lines 94–100: lying means evil; conversion/Scion handled through reading menus | Source alignment and honesty differ. Conversion needs temporal event constraints and distinct reading/report times. A menu is an interface, not the full causal model. |
| Lines 110, 195: three of four slots is an error; conflict size is difficulty | Partial answers remain valid. Conflict size is a useful signal, not an exact cognitive difficulty measure. |
| Lines 119–120: all cross-card implications available only through NPCs | A promising production experiment, not a restriction on the current test environment. Do not charge questions/time until the underlying interaction has been tested. |
| Lines 183, 223: reuse 3/4/5 memory; four to six claims are cheap | Current recall is 2–6; recall and reasoning have different jobs. Measure solver costs before setting budgets. |
| Lines 199, 203–216, 243–244: fixed private facts, one theory, automatic poison excuses, searched worlds called forced | Protect experienced facts without assuming infallible gifts or omniscience. Make theory commitment defeasible and alternatives visible. Never call limited-search acceptance proof. |

**Earlier checkpoint (slices 1–3):** shared credibility states replaced strongest-path
selection for reading arguments; an old-model comparator remains visible. Source trust
and per-reading accuracy are separate experimental inputs. Conflict questions preserve
their evidence roots and report-level accuracy weights. The case supports six reasoning
lines, isolated alternatives, citations and intermediate claims, with version-3 replay.
Bounded reasoning has separate attention and rival search, visible missed connections
and a complete referee comparison. Confidence can alternatively sustain a defeasible
partial theory without stacking the original incoming-effect multiplier.
Tests cover genuine corroboration, shared Merrin dependence, indirect convergence,
neutral/contrary factors, duplicate incidents, retraction, hidden-truth independence and
actual UI controls, paired Insight, private knowledge and confidence revision. The
interface was rendered and inspected; main-game argument and
belief regression suites also passed.

**Current scope:** slices 4 and 5 are delivered within their bounded experiment scope;
see [the experiment guide](CASE_WORKSHOP_EXPERIMENTS.md). The pre-integration reference
and portable examples are in [the checkpoint](CASE_WORKSHOP_CHECKPOINT.md). Arbitrary
health/transition histories, autonomous reasoning, multiple simultaneous cases and full
production integration remain follow-on work. This is not a commitment to a full
Bayesian mind or one-world NPCs.
