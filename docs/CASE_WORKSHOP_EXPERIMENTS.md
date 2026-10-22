# Remaining Workshop experiments: movement and chronology

Slices 4 and 5 are implemented as bounded experiments. Open **More > Case Workshop**
and use the experiment selector beside **Make a Case**. The original 692 reading-chain
example remains available. Switching experiments starts a fresh workspace; save first
to retain an arrangement. These experiments do not alter the running main-game case.

## Movement & soot

The dawn-4 fixture adds a third legal attack, two crime-scene soot reports, two Market
evening observations, a further vigil, explicit observation coverage, a private-errand
claim, and a personal item. The existing reading ambiguity remains. Constance and Nisha
have declared movement hypotheses; this is not a general route planner for every role.

Present the supplied case, then unlink/relink the second soot/evening pair. Compare
the jury's **Effects on everyone** and calculation. Answer a sighting to cite an
applicable walking-gift claim or the private-errand claim. A Medium can only visit
eligible homes of people already dead; claiming Medium does not explain every route.
Nisha's Warden hypothesis has different eligible destinations. A complete vigil on the
Square cannot establish that someone stayed home elsewhere.

The likelihood sums over a shared activity profile and preferred evening haunt with
variable daily visits, then over legal
routes each night. Reports of the same outing are conjoined; copied facts do not become
new incidents. Distinct nights share the profile/haunt and are conditionally combined.
The model compares evil hypotheses (hunting Demon or minion) with good hypotheses
(unidentified lawful activity, claimed walking gift, private errand). Marked registration
is separate from alignment, and the Marked cannot simultaneously have another secret
modifier explaining outings. A claimed explanation changes a hypothesis mixture only
through an actually cited, credibility-gated statement; selecting a label alone does not.

The profile priors are **experimental**, not measured prevalence in the main game:

| Hypothesis | Prior / activity rule |
| --- | --- |
| Evil | 1/3 hunting Demon, 2/3 minion; the minion mixture walks with probability 1/4 |
| Good without supporting claim | .75 unidentified lawful activity, .15 walking gift, .10 private errand |
| Good with credible gift claim | .20 unidentified activity, .70 gift, .10 errand |
| Good with credible errand claim | .20 unidentified activity, .10 gift, .70 errand |
| Night activity | Hunt/gift 1 when eligible; private errand .55; residual lawful activity .05 |
| Preferred evening haunt | Uniform over four blocks; each evening visits it with probability .70, each other block .10 |
| Home account while out | Hunt/minion .70, private errand .65, gift .15, residual activity .20; home account while home .90 |

The residual lawful profile represents uncertainty about other legal roles/activities;
it is not a new ability added to ordinary townsfolk. Full role-assignment constraints,
shared criminal targets and a generative town-wide distribution are outside this fixture.

Two conditional mechanisms are checked against **10,000 calls to the actual game
generator**, rather than treating those priors as calibrated:

- A crime scene starts with the killer's evening material. If an eligible passer exists,
  the game selects one on a 40% branch; matching material leaves the trace unchanged.
  The experiment includes explicit alternative passer/background hypotheses.
- A walker drops something with probability .35 for the Demon or .15 for someone else;
  the item is personal with probability .12. Thus .042/.018 are conditional on walking,
  before route-block, location selection and search opportunity. Dropped material is
  from the walker's **home**; crime-scene material is from an **evening** location.

The inspector shows conditional good/evil likelihoods and their ratio, separately from
observation credibility and final suspicion. These are not probabilities of guilt.
Soft likelihoods never delete logical reading worlds. This experiment disables the
earlier outing heuristic and fixed alibi bonus: observations enter one shared model.
Challenged home accounts enter that same likelihood; a good private errand can also
explain concealment. The account probabilities above are experimental, not measured
lying rates and not a determination of deliberate deception.

The movement experiment also separates conviction from entailment. Its conviction
adjustment is twice the change in the best-support/best-rival preference fraction,
clamped to [-1, 1], over the original disposition score. A neutral or irrelevant
factor adds zero. Bounded jurors use only their checked candidates (or direct factor
odds when no rival was checked). This lets sufficiently strong circumstantial evidence
cross the acceptance threshold while a rival remains logically possible. It is still
experimental tuning, not a Bayesian probability of guilt. The signed alignment effect
is capped at ±.45 before player/confidence multipliers, and social multipliers apply once.
The original reading fixture retains its earlier provisional tuning for comparison.

## Poison & recovery

This fixture changes Hollis's actual minion role to Poisoner, scripts a legal Night-1
visit to Fenwick, updates Watch/Lamplighter observations, and calls the real Dowser
routine while poisoned and after recovery. The bad Day-2 report, its retelling and the
Day-3 recovered report retain different observation/reporting times.

Open **Answer** on the affected Dowser card. **Possible poisoning — unsupported** is
a hypothesis with no free reliability discount. Citing the vial observation opens one
shared healthy/poisoned uncertainty across reports within the interval, provided that
observation is also linked into the case. The vial supports poisoning, not certainty.
Remove it to withdraw that support. The recovered report and unrelated sightings retain
their own credibility.

Poison lasts from Night 1 until Night 2 starts, including the intervening day, matching
`World.resolve_night`. The experiment supports only its declared interval/subject;
arbitrary poison histories are rejected as unsupported. The health branch is 50/50
conditional on accepting the supporting witness, an exposed experimental prior. Witness
credibility is shared with that source's other evidence. Retellings of one reading share
an accuracy origin as well as the poison episode, rather than creating independent tests.

## Revenant & restoration

This fixture exercises `World._revenant_curse` and `World.find_totem`/`free_turned`.
Merrin is the scripted developer-truth victim, but that identity never enters the
assessor. The public chronology states only that one originally-good surviving yes-voter
was converted: Merrin, Nisha or Odette. Activation also establishes that the executed
person was the evil Revenant. The native restoration clears evil intel and disowns an
actual fake report recorded during conversion.

Answer the warning card to propose **who became evil when the Revenant was executed**.
Answer a premise to choose **before curse**, **during curse**, or **after restoration**.
The proposal narrows the player's explanation; it is not new evidence identifying the
converted person. Dated assumptions can say Merrin was good before and evil during
without creating a false contradiction. The premise card displays its epoch.

Reliable reports constrain source alignment at the time of the reading. Credibility of
a later retelling is keyed to its reporting period. Consequently an earlier healthy
reading survives later conversion. A publicly withdrawn retelling is disabled only if
the withdrawal is in that listener's permitted knowledge; the original reading remains.
The good-cover restoration adapter accepts only explicit permitted fields and filters
withdrawn own retellings. Evil-only intel is not copied.

The public event sequence is fixed and known to this fixture's jurors. Uncertain event
occurrence, unobserved restoration, multiple curses and full NPC memory simulation are
not implemented. The Workshop still revises one case/effect vector at a time; changing
the queried epoch replaces that vector rather than maintaining a complete historical
belief database. Scion succession has a reserved schema name and remains unsupported,
as specified in the plan. There is no invented misremembering exception.

## Replay, testing and performance

Version **5** exports identify the fixture and preserve chronology, fault hypotheses,
dated assumptions, canvas layout and presentation history. Old model histories are
explicitly refused. Outcomes are reconstructed from inputs, never accepted as imported
NPC beliefs. Native generation is deterministic and hidden causes remain optional
developer data.

Run `tools/test_workshop_remaining.gd` alongside the six earlier suites. It exercises
the actual selector, poison answer, converted-voter answer, premise epoch control,
presentation and canvas save/open for all three new fixtures. The test prints whole-jury
latency, cold/cached model assessment, state/search/assignment counts and separate
healthy-report conflict-extraction time. Ranked-world, constraint and movement caches use bounded entries and exact
input checks; time, eligibility, observations, credibility and model changes invalidate
the relevant results.

The Workshop latency budget is **five seconds for the supplied four-juror experiments**
on the development machine (i5-12400, Godot 4.7.2, Windows). Tests report actual timing
rather than asserting a hardware-sensitive deadline. Larger uncertainty stress cases
remain synchronous and may exceed this budget. This is not sufficient evidence for
production latency; integration needs separate workloads, pruning and a stricter budget.

The next work is a separate [main-game integration plan](CASE_WORKSHOP_INTEGRATION.md),
not further automatic expansion of these fixtures into a campaign simulator.
