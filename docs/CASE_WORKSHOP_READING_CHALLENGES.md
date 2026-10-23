Subsequent evidence support and remaining boundaries are tracked in [the evidence expansion checkpoints](CASE_WORKSHOP_EVIDENCE_EXPANSION.md). This document records the earlier reading-challenge implementation.

# Case Workshop: reading challenges and Clerk, Archivist, Seer integration

Design reference, 2026-10-23. Adapted from Gemini/Argon's complete
`gemini-code-1792730994240.md`, with the user's accepted amendments and subsequent
discussion. The implementation below is now present; future extensions and explicit
capability limits remain identified separately.

The user accepted the alibi, feedback, Surveyor generation, and role-integration
direction. The agreed explanatory modifiers are Misled and Lying. Misled includes good-faith
information that misdirects, including Red Herring, Marked and Delusional behavior;
it does not necessarily allege an antagonistic actor or broken gift. Unlikely remains
a separate structural challenge. Cause unresolved is an NPC assessment, not a third
explanatory modifier. Skepticism weights remain experimental gameplay tuning.

Related references: [live integration](CASE_WORKSHOP_INTEGRATION.md),
[checkpoint](CASE_WORKSHOP_CHECKPOINT.md), [performance](CASE_WORKSHOP_PERFORMANCE.md),
and [backlog](../BACKLOG.md).

## 1. Argument intent and evidence preservation

Case 44814 exposed a difference between citing a report as accurate support and
citing its existence to question it. Preserve both uses explicitly. An intermediate
claim is a question evaluated from its evidence; it is never a new independent fact
or an extra numerical award. Two paths using the same original receipt still have
one evidence owner.

### Home alibi versus night sighting

- Preserve the full subject list on live sighting cards. The current canvas view
  keeps only `receipt.subjects[0]`, while the contradiction matcher compares a single
  subject. Vigil #51 named Constance and Nisha; retaining Constance alone prevents
  recognizing the conflict with Nisha's home alibi #64.
- The user remembers the cards being connected by a visible string. A failed merge
  can leave a generic evidence-to-evidence link. Investigate inclusion and link
  direction separately: the filed case #65 retained only #64. The trace establishes
  that omission but cannot reconstruct every editor gesture or prove its cause.
- In the Workshop, matching a home alibi to a positive sighting of that person on
  that night should default to a merged contradiction card. Generic links remain
  available where there is no unambiguous contradiction. Board display strings and
  Workshop argument links must not be confused with one another.
- Retain both original receipts. Treat the alibi as disputed testimony, not as an
  accurate account to enforce alongside the preferred sighting. Preserve provenance
  through filing, preview, private presentation, meetings and nomination speech.
- A contradiction can stand alone or support an intermediate suspicion claim and a
  main case. Recognizing incompatible accounts is separate from assigning deliberate
  deception or evil. An NPC who distrusts the sighting need not concede the alibi.
- For a good NPC who knows they were out and whose false home alibi has been
  established, default to: "Fine, I was out. Doesn't mean I was doing anything wrong."
  Do not force this admission on an NPC who genuinely stayed home or cannot remember
  an outing. Preserve evil's strategic dialogue layer. Pressure-based follow-up and
  possible forced gift/secret revelation are deferred in the backlog.
- Filing/inspection must list the included originals and explain excluded or
  disconnected support. A visible relationship must not silently imply that the
  complete intended argument was understood.

## 2. Reading challenges: accuracy, cause and honesty

Use an attached modifier card, created by a reading's context menu, rather than
making the player contradict their own answer slots. A slot answers the card's
question *assuming its interpretation is accurate*. A challenge asks whether that
assumption should be granted.

### Agreed distinctions

| Player's argument | What the listener is asked to reconsider | What is not established merely by selecting it |
| --- | --- | --- |
| The reader was misled | Whether a good-faith reading misdirected the reader, through impairment or misleading registration | A Poisoner identity, confirmed impairment window, or established innocence of the source |
| The reader is lying | Whether this statement was knowingly deceptive | That a discrepancy alone proves intent, or that a liar must be evil |
| This reading is unlikely | Whether the report requires an unusually restrictive layout | That rarity proves error, impairment, or dishonesty |

Use Misled reading and Suspected lie in the menu. Keep the ordinary flow simple: add a challenge, inspect
its proposed explanation and cite supporting cards. "Unlikely" is a reason for
skepticism; "misled" and "lying" are possible causes. Do not make them mutually
exclusive categories of the same kind. The same rarity argument cannot earn separate
discounts by being represented with several modifier cards.

The player can emphasize an explanation and ask NPCs to assess it. This chooses a
question; it does not directly set NPC confidence or credibility. Permit NPCs to agree
that the report is unreliable while rejecting the allegation of lying. Likewise,
skepticism about a result does not automatically establish the reader as honest.

### Conditional coherence versus persuasion

For the player's hypothetical explanation, releasing a challenged report's content
can restore coherence. Display this as conditional: "Your explanation fits if this
reading is unreliable." Do not call it established just because a contradiction
disappears when the player removes a constraint.

The two gift-reading explanations assume a good reader for Misled and an evil reader
for Lying in the player's conditional world. These assumptions never become new
facts in the applied union. Unlikely makes no alignment assumption. This is separate
from an ordinary false whereabouts statement, which a good NPC can knowingly tell.

For NPC conviction, an unsupported modifier supplies no automatic discount. Supporting
evidence changes the listener's weight on alternatives; it must not create a free
fixed 50/50 impairment branch simply because the player chose a menu option.

Misled is broader than a failed health assumption. A supported Red Herring or Marked
explanation retains the healthy registration constraint; it does not discount a
correctly reported registration. A failed reliability assumption removes a constraint;
it does not negate the report.
For example, a possibly impaired Seer `no` does not establish that one of the pair is
the Demon. In the generator, an impaired Seer can even return an accurate result.
"Impaired" and "false" are therefore different hypotheses.

Source honesty and gift accuracy must remain distinct. The mixture already has
source and accuracy assumptions, and the fixture chronology has evidence-gated fault
windows. Extend those mechanisms rather than introducing an independent error flag
for every display of the same receipt.

An accepted accuracy challenge is scoped to the original reading. A supported
impairment cause can affect other readings in the same legally affected interval;
it must not indiscriminately discount earlier/later results. A supported dishonesty
claim may affect source credibility more broadly, with a separately justified scope.
The generic Misled hypothesis does not identify a Poisoner or validate a complete
poisoning schedule; attaching specific impairment-window evidence remains gated.
Neither effect stacks with repeated presentations or duplicate branches. Suspicion
and credibility effects from one incident require a single causal accounting, not
an accusation that lowers credibility and then feeds back to strengthen itself.

Use the shared ownership/retraction machinery. Editing or withdrawing a case retracts
its exclusive grounds; independent testimony and other cases retain their ownership.
Reassess challenges when corroboration, public facts or contrary evidence changes.
Do not write a permanent source-wide `discounted` value directly from a checkbox.

### Computational implications

Allowing a report to be unreliable usually broadens an existing alignment domain;
it need not enumerate every alternative false number or pair. However, averaging
over trustworthy/untrustworthy explanations is additional work. With k independent
binary uncertainty factors there can be up to 2^k combinations. Reuse existing
source/accuracy factors, share genuine interval causes, group identical active report
sets and preserve workload gates. A single challenge may reuse an existing factor;
there is no general zero-cost guarantee. Naming a Poisoner, enforcing a poisoning
schedule or tracking new alignment transitions is additional semantic scope, not
implied by generic accuracy challenges.

## 3. Surveyor: generation and player-driven skepticism

### Generator

Heavily favor counts 2-3 for fabricated and impaired Surveyor results, respecting
population/setup rules and existing false-result rules. Keep occasional extreme
counts. If impairment must differ from the true count and the truth is 3, favor 2.
Do not change healthy true readings or automatically apply a hidden discount to
extreme reports. Use measured configurable weights rather than a universal cutoff.

### Unlikely-reading modifier

The context-menu option is visible on reading cards, enabled on every Surveyor
reading initially regardless of count. Unsupported types explain why it is disabled.
Never enable or gray it according to whether a challenge will succeed.

Compute restrictiveness against the listener's permitted established knowledge.
Exclude the report itself and the player's proposed answers from the reference
space. Condition source-role/health assumptions consistently so that the count does
not mistake the source's general credibility uncertainty for an implausible layout.
Do not consult hidden alignment, actual impairment or the real killer.

Raw compatibility fractions are structural diagnostics, not error probabilities.
Adding equivalent role/Demon/Red Herring completions must not change the apparent
rarity merely by changing representation. If weighted mass is used, its weighting
must be explicit and consistent across the numerator and denominator.

- Impossible under established knowledge: identify which assumptions cannot coexist.
  This establishes an incompatibility, not its cause.
- Extremely restrictive but possible: a player-raised challenge can justify a modest,
  bounded, provisional skepticism effect. Explain the required layout.
- Fits ordinary layouts: reject the challenge with an explanation; no automatic
  reliability change.
- Later corroboration or contrary evidence: reconsider the challenge.

Do not implement Gemini's proposed `clamp(f / 0.05, 0.15, 1)` reliability rule as an
inferred probability, or grant `agreement >= 0.6` solely from a low raw fraction.
Those are uncalibrated gameplay proposals. A rare accurate reading can be powerful
evidence. Stronger future discounting could compare result likelihood under accurate
and faulty reporting, using generator-matched behavior.

Case 44814 is a regression specimen: accepting good, healthy Greta's Surveyor count
of 1 forces Odette, Hollis and Constance onto the evil side. The neutral restricted
domain has 41 assignments with that same trio; selecting Nisha as a positive answer
fits none. Challenging the count must not accidentally endorse that conclusion.

## 4. Clerk, Archivist and Seer semantics

Match the generator in `sim/world.gd`, not the dev log's referee-only `true` flag.
Marked/Red Herring registrations can be correct gift behavior while that flag says
the result differs from actual alignment or Demon identity.

| Gift | Acquisition | Accurate healthy interpretation |
| --- | --- | --- |
| Clerk | Night 0 | One named person holds the named good role; the granted source holds Clerk. |
| Archivist | Night 0 | One named person holds the named minion role, not Demon; the granted source holds Archivist. |
| Seer yes | Night 0 onward | The pair contains the Demon, the source's persistent good Red Herring, or a good Marked person registering positively. Multiple causes may coexist. |
| Seer no | Night 0 onward | Neither named person is Demon or that Red Herring. Minions remain possible. Marked may register negatively. |

These are constraints in credibility branches that grant the report's source and
accuracy, not hard facts derived merely from a report being on the canvas.

### Role claims and answers

- Clerk/Archivist Answer: unknown/either, A, or B. No "neither" answer: use a challenge
  or conflict argument for that interpretation.
- An accepted good-role claim constrains the claimant to be good and hold that role
  in the branch where it is granted. A merely included claim does not prove goodness.
  Share the speaker's honesty factor; a role claim does not require gift health.
- Keep unique good-role and named minion assignments consistent across accepted
  claims/reports and the listener's own role. Use compatible role completions or a
  compact equivalent; avoid enumerating every full role permutation by default.
- A Clerk pair plus a trusted matching claim can corroborate an interpretation.
  Two good candidates do not alone establish which holds the named role or prove the
  Clerk honest. A third person's accepted claim to that unique role conflicts with
  the granted Clerk report; it does not unconditionally identify the liar.
- If other evidence establishes one Clerk candidate evil, the other must hold the
  named good role in branches granting that evidence and the healthy Clerk report.
- Archivist must respect named minion uniqueness, available minion slots and legal
  setup roles. A Demon plus an otherwise good pair member cannot satisfy a minion
  report. Both pair members established good conflicts with the healthy report, but
  identifying that conflict does not by itself establish an Archivist lie.
- Seer yes Answer: who explains the ping, and optionally Demon/Red Herring/Marked.
  Unknown remains legal. An answer selects an explanation, not necessarily the only
  positive person/cause. Seer no has no required positive slot; annotations are player
  hypotheses, not consequences of a negative reading.

### Persistent correlated identities

Distinguish Demon and minions only when inputs/questions need it. Preserve the
existing alignment-only path and checkpoint counts. Conditional expansion or compact
state is acceptable, but a Demon-candidate mask alone is insufficient for Seer.
Retain correlated Demon/Red Herring possibilities across the entire accepted reading
set, including selected causes and named role constraints.

The native Seer has exactly one good Red Herring other than themself, chosen at setup.
It is persistent and can also be Marked. Healthy negatives exclude that identity from
their pairs. Marked registration can change between readings; Red Herring cannot.
Two disjoint positive pairs cannot both be explained solely by one Red Herring, but
can have different valid causes. A same-pair no/yes sequence can be explained by a
changing Marked registration without any impairment. It does not automatically earn
a poisoning hypothesis or a default 50/50 discount on the earlier report.

Add Demon/minion questions as needed to express conclusions correctly. A negative
Seer result must not exonerate a minion. Keep unsupported temporal role/alignment
transitions explicitly gated until their adapter exists.

## 5. Live integration and feedback

- Extend live role, timing and payload validation for Clerk, Archivist and Seer.
  Preserve exact original receipts and source/observation/report/acquisition times.
- Handle relevant role claims as credibility-gated inputs, not silently ignored
  decorations. Expand contribution selection and shared ownership, not only the
  headline solver, so private, meeting and nomination delivery use the same semantics.
- Support scoped quoted/challenged reports and alibi disputes, including intermediate
  premises. A supported subclaim cannot silently discard its challenge metadata.
- Show capability limits before filing/presentation. Unsupported causes, mixed
  mechanisms, exhausted budgets and native fallback must be explicit.
- Preview separately reports answer validity, conditional coherence, headline stance,
  collateral effects, challenge assessments and actual effect application status.
- Suggested invalid-answer wording: "Your selected explanation does not fit. The
  underlying report still changes these assessments." Say weight was withdrawn only
  when the relevant owned effect actually was removed. A fresh neutral preview has
  no earlier presentation to retract.
- Show "This explanation works if you set aside reading X" separately from "The
  listener finds enough grounds to distrust reading X." Show disagreement about a
  proposed cause separately from agreement that a report is unreliable.
- Ghost previews remain read-only and neutral; actual NPC private knowledge, trust,
  Insight, Confidence and theory memory can produce different responses.

## 6. Delivery and verification

Work in verified slices: (1) preserve sighting subjects and fix alibi interpretation,
(2) accurate preview/application feedback, (3) Surveyor generation and challenges,
(4) Clerk/Archivist role constraints, (5) correlated Seer reasoning. Implement the agreed Misled/Lying distinction, retaining cause-unresolved NPC replies. Backlog entries
are recorded now; the broader dialogue/disclosure fixes remain separate work.

Regression requirements:

- Case 44814: multi-person vigil, both link directions, merged/generic links, correct
  full roots through preview/filing/presentation, later revision/retraction. A real
  false-alibi admission differs from a genuine home account or unremembered outing.
- Accuracy/impairment/deception: unsupported claims cannot farm discounts; report
  rejection does not imply its negation; faulty results may still be correct; NPCs
  can accept an accuracy objection but reject the allegation of lying. Shared
  sources/intervals and duplicate modifiers have no duplicate awards.
- Surveyor: rare possible versus impossible versus ordinary layouts; correct extremes
  remain useful; no automatic menu spoiler; weights honor generator false-result
  rules; fractions are stable under equivalent latent-state representations.
- Clerk: role matching, pair elimination, conflicting third-party/own-role claims,
  honest healthy grants versus disputed claims, no free mutual corroboration.
- Archivist: named unique minion identity, Demon exclusion, both candidates good,
  contradictory reports with uncertainty about which source/cause is wrong.
- Seer: Night 0, negative minion allowance, fixed Red Herring across yes/no readings,
  Marked flips, overlapping Red Herring/Marked, multiple positive causes, joint
  Demon/Red Herring consistency and challenged earlier readings.
- Native good and evil cover minds, restricted private knowledge, all presentation
  venues, stable repeated delivery, ownership withdrawal and read-only ghost preview.

Preserve frozen checkpoint fixtures without rewriting expected semantics. Rebaseline
performance on the current live cognitive model and compare full behavior objects
for unchanged workloads. Gemini's 1.66/2.50-second references and `253d9f9a...` /
`da951a4d...` hashes describe the older full/scale reference, not today's native
cognition baseline. The later recorded live timings are approximately 4.94/2.54
seconds for 692/4242; see `benchmarks/workshop-cognition-2026-10-22.json`.
Profile new role combinations and uncertainty counts by listener and stage. Neither
"zero overhead" nor sub-0.05-ms challenge checks are established guarantees.

## Implementation checkpoint (2026-10-23)

- All five delivery slices are implemented within the live capability gates above.
- Context menu creates attached Misled/Suspected lie cards for supported readings;
  Unlikely remains visible and is enabled for every Surveyor count. Existing outgoing
  links are preserved through the modifier, and removal restores evidence paths.
- Live alibi disputes use the existing shared circumstantial envelope and one gated
  2x comparison factor, never two added awards. General route/trace and walking-role
  citations remain explicitly unsupported in live cases.
- A count below 5% of the structural reference space receives a provisional 0.65
  accuracy multiplier when challenged as Unlikely; an impossible healthy report
  receives 0.25. A cited credible actual conflict receives 1 - 0.65 * witness quality.
  These are tuning values, not calibrated error probabilities. A same-pair Seer flip
  alone does not establish impairment, and Red Herring/Marked misdirection retains
  the accurate registration constraint rather than discounting it.
- A Lying allegation needs grounds. Disposition can favor dishonesty over honest
  misdirection, while firsthand knowledge of a duplicate unique gift is stronger.
  Accepted dishonesty affects the source's supported testimony in the shared model
  and one bounded suspicion envelope. It does not directly rewrite native honesty
  or permanently mutate a source-wide discount. Bare allegations add nothing.
- Individual first-night role sources share honesty with their claims; single-receipt
  source/accuracy factors can be combined exactly as one acceptance factor, preserving
  multi-receipt correlations and the 64-state gate. Cases with additional independent
  uncertainty beyond that gate still fall back explicitly.
- Demon identity expands only sensitive live domains by the number of evil players.
  Red Herring possibilities are intersected jointly for each Demon identity across
  readings and selected causes. Unique role completions use a small matching problem,
  not a permutation of every unobserved role. Equivalent role completions do not
  multiply compatible-world counts.
- New tests cover modifier UI/filing, the 44814 alibi regression, shared ownership,
  healthy misleading registrations, role constraints, all three new role deliveries,
  explicit Demon/minion questions and Seer answer controls. Frozen fixtures are
  unchanged. Desktop visual polish is not asserted by headless interaction tests.
- Native ten-person profiles: seed 692, four reports, 6.23 seconds; seed 4242, five
  reports, 13.15 seconds. Both runs record seven shared and three legacy deliveries;
  fallback remains explicit. Candidate searches dominate. These broader workloads
  include changed supported roles and storyteller draws, so the old 4.94/2.54-second
  cognition profile is not a same-input performance comparison. Full behavior objects
  agree before/after role-completion caching. See the
  [listener/stage profiles](benchmarks/workshop-reading-roles-2026-10-23.json).

The four separate dialogue/disclosure backlog items remain open. Pressure-based
forced revelation after a false-alibi admission is deferred as requested.

Verification at this checkpoint: 117 checks across the two new suites; the frozen
checkpoint (36), efficiency (226), live cognition (71), ownership (57), live canvas
(85), presentation (62), core/remaining/reasoning/consequences, live adapters and UI
suites pass. Native belief, argument, shadow, trace and UI/board checks also pass.
Editor import is clean. These are automated/headless checks, not a completed human
playthrough of the new interactions.
