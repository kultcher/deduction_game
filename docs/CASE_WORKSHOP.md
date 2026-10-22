# Case Workshop proof of concept

Open **More > Case Workshop** in the game. The experiment opens in its own window;
closing it preserves its state and leaves the running case alone. Alternatively, open
`ui/case_workshop.tscn` in Godot and run that scene with F6.

The Workshop freezes a scripted ten-person town at dawn on day 3. It tests expressing,
interpreting and revising a case. Its new interpreter does not change the main game's
argument, persuasion, voting or dialogue systems.

Slices 1–3 of the [implementation plan](CASE_WORKSHOP_PLAN.md) are implemented:
explicit claims/citations, report conflicts, multiple reasoning lines, and shared
support, followed by bounded Insight reasoning and experimental confidence persistence.
The controlled soft-factor experiment tests convergence; actual movement and trace
likelihoods remain slice 4. A separate pre-Slice-4 step adds scoped intermediate-claim
assessments and one replaceable set of effects on everyone implicated or exonerated.

The default screen is now a freeform card canvas, limited to fixture 692. The previous
list-based experiment remains available by running `ui/case_workshop_lab.tscn` with F6.
It retains the seed generator and supplied-factor controls. Earlier experiment formats
are refused because their belief-update semantics differ.

## Canvas workflow

1. The workspace starts with all sixteen evidence cards and a Constance accusation.
   **Load mockup** assembles the user's proposed reading chain and challenged alibi.
   The reading answers stay unknown so the alternative Constance/Nisha explanations
   remain available to explore. **All evidence** fits the scratch cards; **Fit case**
   fits the selected card and its incoming argument.
2. Drag a card with the left button. Drag empty space or use the middle button to pan;
   use the wheel to zoom. **Answer** opens a separate editor. Answers remain on the
   card and are shared wherever that evidence is used. Closing the editor keeps edits.
3. **Add Case Premise** creates a claimed conclusion or a generic **Supporting evidence**
   group. A group's claim is optional. Its incoming evidence supplies the argument;
   its intermediate conclusion never becomes an additional accepted fact. **Answer**
   on a premise edits its assumed alignments/Marked identities. Root assumptions apply
   to the whole selected case; supporting premises contribute their local assumptions.
   Conflicting assumptions, including inside a nested branch, are reported.
4. Click **Link**, then a destination card. Arrows point from support to the thing it
   supports. Evidence-to-evidence links normally mean **read together**. An applicable
   walking-role claim linked to a sighting defaults to **could explain outing**, using
   the same citation checks as the list editor. Right-click switches applicable role
   links between context and an outing explanation; an explicit outing answer takes
   precedence over the default. A home alibi and same-night observation
   that its subject was out automatically form a merged red contradiction card.
5. **Inspect** a contradiction to see both originals and its interpretation. It means
   that the observation challenges the home alibi. If the observation is accurate,
   the alibi is false; deliberate lying and evil are further inferences. Right-click
   **Unlink merged contradiction** restores the originals, retaining their answers and
   references. Ordinary connections can also be removed through the right-click menu.
   Premises can be removed while retaining their evidence. Circular links are refused.
6. Select a premise with a claim and **Present selected premise**. Only its incoming
   argument is presented. Disconnected cards remain scratch work. A conflict premise
   can ask whether the original accounts conflict, without first resolving which is
   wrong or assigning alignment guilt. The mock jury opens in its own window, with
   the existing trust, Insight, confidence and comparison controls. Close/reopen it
   using **Mock jury**. Remembered discussion still replaces this one case's prior
   effects on every character; it does not maintain several independent case ledgers.
   **Effects on everyone** shows collateral changes and retractions. **Claims and their
   connections** shows each scoped inference, its doubts, unattended evidence, and
   whether its evidence strengthens the parent or leaves an alternative available.
7. **Save/Open** stores the graph, card positions, answers, active premise, view, jury
   settings and replayable discussion. Canvas files use `demonologist-workshop-canvas-1`,
   containing the version-4 experiment. Imports validate provenance and graph structure
   before replacing the current workspace. Older histories require their original code
   version; they are not silently replayed under the new model.

Merrin linked through Bart/Fenwick and all three linked directly to the Hollis premise
have the same evidence roots and assessment. Shared paths do not duplicate a witness.
Rearranging cards has no effect. Explicit grouping can still affect which connections a
bounded-Insight juror attends to; named source trust and gift explanations retain their
distinct roles. Links support editing and attention, not an ordering-dependent evidence bonus.

The only added evidence-weighting rule in this UI step is the challenged home alibi:
one fixed, uncalibrated **2× evil/good comparison factor**, gated by the contradicting
observation's credibility. The quoted alibi records known testimony without assuming
its contents true; distrusting Constance does not erase the fact that she made the claim.
Repeated references to the same outing share this factor. It can favor Constance while
both logical alignment alternatives remain possible. Its value is exposed in Inspect
and in the jury calculation; it is not a general likelihood model for deception.

## Intermediate claims and collateral consequences (pre-Slice-4 step)

A Constance headline no longer limits the outcome to Constance. With the three core
readings, Hollis and Lian can gain suspicion while Constance versus Nisha remains
unresolved. Reliable reports can also exonerate people. A juror can acknowledge that
Hollis follows **if the readings are sound**, while doubting the witnesses enough to
remain only partly persuaded. Logical implication and social acceptance stay distinct.

Each named premise is assessed using its own incoming evidence and assumptions, within
the presentation's shared attention window. Claim-less groups preserve nested named
premises. The NPC can dispute an incorrect intermediate claim and explain why its
connection does not settle the parent. The label itself never becomes an extra report
or a sequential suspicion bonus. Original observations can remain relevant even when
the player's interpretation of them is mistaken; there is no hard all-or-nothing gate
that discards them merely because an intermediate claim is rejected.

For every person, the experiment compares support for evil and good using the same
starting attitudes, source credibility, reading accuracy and attended evidence. It
subtracts the comparison already supported by private reports and prior dispositions.
The provisional alignment signal is `0.45 * (evil evidence change - good evidence change)`.
This prevents a merely possible accusation from automatically increasing everyone's
suspicion and prevents repackaging the juror's own known reading as fresh evidence.
The reference subtraction is an experimental disposition comparison, not a posterior
probability or a calibrated measure of information.

The earlier outing-pattern heuristic remains available. Because it can describe the
same incident as the challenged-alibi factor, the experiment takes the stronger absolute
alignment/pattern route for that person, **never their sum**, then applies player trust
and confidence once. This conservative envelope can hide a weaker independent route;
it is deliberately temporary pending Slice 4's shared causal movement/trace model.
The inspector distinguishes headline conviction from this actual signed effect.
An explicit conflict question still assigns no alignment effects.

Claim-to-parent diagnostics compare the parent with and without the branch's exclusive
original evidence. Sources that also reach the parent through another path remain
included. These differences are not additive contributions, and no extra persuasion is
awarded for an accepted intermediate claim or a positive connection diagnostic. Grouping
can affect bounded attention, but projections never receive extra unattended public
cards. Each conclusion has the existing bounded search budget; this is not a single
fixed total computation budget for an entire multi-conclusion presentation.

The ledger records the actual clamped effect on each character. Before any revision,
the whole old vector is retracted; all new consequences are computed from that frozen
baseline and applied together. Hollis cannot become a less credible source halfway
through the same presentation. Repetition, reused roots, duplicate derivations and
switching the headline cannot stack effects. Independent simultaneous case ledgers and
cross-case provenance remain future work.

Board-to-workshop transfer, independent duplicate interpretations, collapsing whole
cases, relationship-choice prompts for ambiguous future evidence, and automatic
movement/soot likelihoods remain future work. This canvas preloads the existing fixture;
it does not read or alter the running main-game case. A linked role claim does not
silently accept its associated gift result.

## List lab experiments

1. **Load example > Surveyor only.** Leave slots unknown and present the case. A partial
   explanation is allowed. Accepting the Surveyor claim assumes the source was good,
   held that gift, and was healthy at the reading's time; good does not exclude Marked.
2. **Add Rumormonger**, then **Three core readings**. In seed 692 there are two worlds:
   Constance/Hollis/Lian evil with Nisha Marked, or Nisha/Hollis/Lian evil with Constance
   Marked. These are compatible assignments, not equally likely outcomes or probabilities.
   Argue that Hollis is evil to compare a forced conclusion with the unresolved Constance
   accusation.
3. Answer the Rumormonger card with Nisha, or choose **Good · Marked** for Nisha under
   **Assumed alignments & Marked**. That narrows your proposed explanation. The jury can
   acknowledge the conditional inference without treating your selection as testimony.
4. Leave **Continue remembered discussion** off to compare from identical starting
   attitudes. Turn it on to present, revise, and present again. Remove a core report;
   the earlier effect is replaced, including retraction when its support disappears.
5. Load **Repeated night outings**. Add your vigil: the same night remains one incident.
   Answer **Night gift** on a Watch card, then choose a specific supporting claim in
   the picker below it. Agnes's Lamplighter claim is separately available: citing it
   does not accept her count. Wrong-person, non-walking and wrong-period claims grant
   no discount. Inspect any report's associated role claim from the evidence column.
6. Load **Conflicting reports**. The home alibi and sighting cannot both be accurate.
   Select the specific reports in the conflict scope. Minimal conflicting sets appear
   in the case check; keep one as a derived question or optionally name the report
   you question. The jury stores accuracy weights for the reports, without assigning
   alignment guilt. Naming a report as wrong supplies no new evidence. Derived
   questions refer to the originals and cannot multiply their effect.
7. Under **Adjust this juror**, vary confidence, trust in you, or trust/suspicion toward
   a report's source. **Show calculation & accepted path** exposes agreement, premise
   quality, confidence mode and the actual old/new ledger effects. The original mode
   scales attitude change, not the logical result. Restore the generated jury or reset
   discussion as needed.
8. Set the conclusion to **Hollis is evil**, compare Surveyor + Rumormonger with all
   three readings, and inspect the calculation. Both force Hollis conditionally, but
   the second sufficient route now adds support. Merrin is a shared dependency, not
   two independent witnesses. The inspector shows the old strongest-path score too.
9. Load **Converging lines (test factor)**. Select a line to edit its title, evidence,
   assumptions, answers and optional intermediate claim. Supporting lines combine;
   alternative explanations are checked separately. Unassigned selected evidence
   remains part of the whole case. Intermediate claims are diagnostics, not new facts.
   The displayed test ratio is a supplied input: 1× is neutral, above 1 favors evil
   for its selected person, below 1 favors good. Change the target to Nisha and favor
   good to see support move indirectly toward Constance through the reading chain.
   Both logical alternatives can remain possible while conviction changes.
10. Under **Adjust this juror**, change one reading's accuracy separately from trust
    in its source. Doubting Bart's reading preserves the Dowser/Rumormonger route;
    doubting Merrin's reading weakens both. Even a juror's own reading can be questioned
    without denying that they received that result.
11. Load **Insight comparison**, or choose **Compare Insight levels** under any juror.
    This compares full reasoning with Low, Medium and High Insight using the same juror,
    private knowledge and starting attitudes. It does not change the discussion history.
    Under **Adjust this juror**, choose **Bounded reasoning (Insight)** to use that model
    for presentations. Inspect the explanation checks, rival checks, ignored evidence
    and ignored lines. A coherent explanation without a rival search is provisional.
12. Choose **Confidence sustains a theory (experiment)** and enable **Continue remembered
    discussion**. Present, then revise the evidence or supplied factor and present again.
    The inspector shows the remembered partial position and whether it was retained or
    revised. Confidence no longer scales the incoming effect in this mode. **Reset
    discussion** starts a fresh theory. Use the original confidence mode for comparison.

There are up to six reasoning lines and eight derived questions per case. Duplicate
or out-of-domain slots are blocked; unknown slots remain valid. Conflicting hypotheses
can still be presented. Supporting lines cannot quietly use incompatible identities.
Repeated references share their underlying fact/incident identities. Two witnesses to
one outing can support its occurrence without making it two outings. Overlapping or
contradictory supplied test factors receive explicit feedback instead of multiplying.

**Save experiment** exports the seed, public evidence, current case/version, jury settings,
each presentation, objections and actual changes. **Open experiment** validates the file
and replays its history rather than trusting the exported outcomes. Imports support up to
200 presentations. Developer truth is omitted unless its checkbox is enabled; that data
never reaches the interpreter. Version 4 adds intermediate-claim scopes, dependency
links and replay of multi-character effects to the earlier provenance and reasoning
settings. Personal knowledge belongs to the fixture; theories are reconstructed
from presentations, not accepted as injected baseline memory. Version-1 through version-3
exports are explicitly refused because the assessment model changed; they are not
silently replayed with different semantics.

## Scenario and evidence boundaries

- Seed 692 is a teaching fixture inspired by case 692, **not a replay of that trace**.
  Agnes has the Lamplighter gift and Greta the Veteran gift so the five chosen evidence
  types coexist in one legal lineup. The five types are Surveyor, Rumormonger, Dowser,
  Night Watch and Lamplighter. Sixteen cards include associated role claims, a separate
  Warden claim, an alibi and player sighting. The quiet night in this fixture is a
  Veteran survival, not confirmed corroboration of the Warden claim.
- Other seeds permute cast assignments within this same scenario structure. They are
  reproducible variations, not an unrestricted three-day campaign generator. The fixtures
  deliberately retain the four-block Surveyor result and the core Marked ambiguity.
- `workshop/scenario.gd` constructs real World/NPC objects. It uses the existing
  `_receive_info` and `_day_gifts` routines, rejection-sampling the teaching reports.
  Night routes and the two legal Veteran attacks are scripted; full night AI is not run.
- Role, alignment and registration are separate. There are three original evil people
  and exactly one good Marked person. Marked registration can differ between readings.
  Reading/event time, reporting time and learned time are separate fields. In this
  fixture testimony is reported when the player acquires it. Role assertions retain
  whether they were implicit in a report, their origin and their asserted interval.
- The proof of concept has no alignment transitions, poisoner, or role changes. The
  exported alignment epoch explicitly covers opening through day 3. Revenant/Scion
  transitions, arbitrary poisoned readings and the remaining roles require further work.
- The movement solver checks possible sets of walkers and the Lamplighter's count,
  excluding the Lamplighter. Watch sightings require those people to be out. It does not
  solve alternative routes or infer that an unseen person stayed home. Full route/alibi
  reasoning and physical trace patterns remain outside this slice.

## Interpreter shape and provisional tuning

`case + listener + context -> assessment + ledger update + response`

`workshop/solver.gd` enumerates compatible alignment/Marked assignments and separate
night-outing assignments. Selected reliable reports constrain their sources to good at
the report time. Player answers constrain the proposed explanation; implication before
those answers is reported separately. Duplicates and impossible selections get feedback;
the Workshop lets the player present a mistaken case.

`workshop/case_graph.gd` compiles supporting lines to one case, expands derived questions
to their evidence roots and checks incompatible assumptions. Alternative explanations
are isolated. Its output never treats an intermediate conclusion as an independent premise.

`workshop/support_model.gd` evaluates a mixture of credibility scenarios. A shared source
variable gates that source's reports; a separate accuracy variable can disable a particular
reading. Disabling a report removes its constraint, rather than asserting its opposite.
Each consistent scenario contributes once, so overlapping proof routes do not duplicate
Merrin. Inconsistent scenarios are excluded and remaining weights normalized, exposing
localized report-accuracy doubt. These are experimental tuning weights, not calibrated
probabilities or a full generative Bayesian model. A source variable is a coarse shared
dependency; causal poison periods and conversion histories remain future work.

The jury retains player trust, confidence, stance, suspicion and a replaceable evidence
ledger. Private knowledge of being good is fixed; own readings participate through their
accuracy settings. For unresolved cases, strongest supporting/rival worlds are ranked
using suspicion/trust terms shaped like `Argue._expl_weight`. Supplied soft factors modify
those rankings and can favor either alternative. Counts of worlds never become probabilities.
The inspector retains the previous strongest-path calculation for comparison.

### Bounded Insight reasoning

Full reasoning remains the default comparison mode. Bounded reasoning constructs and
checks candidate explanations independently; it does not take the referee's surviving
worlds and pretend to have searched them. The deterministic profiles are experimental:

| Insight | Presented cards | Connected lines | Explanation checks | Rival checks |
| --- | ---: | ---: | ---: | ---: |
| Low, below 0.34 | 3 | 1 | 8 | 0 |
| Medium, below 0.67 | 5 | 2 | 48 | 16 nearby swaps |
| High | 10 | 6 | 840 | 840, exhaustive when necessary |

These are upper limits, not work the juror must always perform. Source trust, count
readings and references to the target affect attention priority. Duplicate line wrappers
share one attention group. Own reports remain available outside the card limit. A juror
can remember sightings while missing their connection to another line; the inspector
shows ignored lines as well as ignored cards. Ignored evidence cannot silently add
outing suspicion or cancel conviction through the referee's more complete assessment.

The search can find a coherent proposal, a rival, a conditional implication, or remain
unresolved. Medium Insight tests swaps from a found proposal; exhausting those swaps
does not prove uniqueness. Only exhaustive rival absence can certify an implication,
and only under the attended premises. A failed limited search is not disproof. The
referee's logical answer is independent of Insight and stays visible as a diagnostic.
Spoken alternatives come only from the juror's own search.

Direct personal conflicts are checked even outside attention: being good at this epoch,
what result the juror actually received, and their known whereabouts. Receipt does not
guarantee a healthy gift result. A rejected report is disabled individually, without
automatically discrediting its source's other reports. A direct home/sighting conflict
within attended evidence is also recognized. This fixture has no Sleepwalker or personal
conversion history; those exceptions still require slice 5.

The displayed search grants reports with source weight at least 0.4 and reading accuracy
at least 0.5. Numeric conviction separately averages the credibility states, running a
bounded search in each. A checked but unchallenged proposal starts at 0.3 with one active
core reading or 0.76 with two or more, before credibility and supplied-factor adjustments.
This deliberately exposes a tunable limited-search acceptance rule; it is not a probability
or a general measure of argument strength. Distrusted sources still weaken agreement.

### Confidence as a provisional commitment

The original mode retains the incoming-effect multiplier below. The alternative mode
uses a multiplier of 1 and remembers a partial commitment about the target at the
alignment epoch, with a separate Marked question. It compares at most the supporting
and rival candidates found in the displayed search, rather than deriving everyone's
suspicion from an arbitrary completed world. Initial adoption has no persistence bonus.

On changed evidence, a retained commitment biases hypothesis ranking by `3^confidence`.
A contrary candidate can dislodge it at comparison odds of `1 + 4 * confidence`; direct
personal facts and an exhaustive opposite implication without extra player choices can
override it. Low confidence can also rebuild provisionally when the prior alternative
is unavailable. Source trust and reading accuracy do not change, and confidence cannot
invent a poisoning excuse. Repeating identical inputs reuses the decision; it cannot
incrementally reinforce the theory. Removing the evidence retracts the case's numerical
effect even if a remembered theory label remains.

This is an experiment in per-target commitments during revision of one editable case,
not an autonomous, coherent theory of the whole town or production NPC integration.

The initial tuning is deliberately visible and experimental:

| Component | Rule |
| --- | --- |
| Forced implication in a credibility scenario | agreement 1.0, weighted once by that scenario |
| Conditional on player choices | agreement 0.4 inside that scenario; does not promote a chosen conclusion into its own premise |
| Merely possible implication | 0.02–0.18 within a reading-supported scenario, ranked by best supporting/rival explanations |
| Source credibility | `clamp(0.2 + 0.65 * NPC trust - 0.35 * suspicion, 0.05, 0.95)`; own sources 1.0 |
| Multiple sources/routes | shared source states; average agreement over consistent states, permitting alternative proof routes |
| Reading accuracy | separate 0–1 inspector setting per report; defaults to 1, including own readings |
| Supplied test factor | 1/16–16 evil/good likelihood ratio; same-incident factors share corroborating witness routes |
| Player multiplier | `0.5 + trust in player` |
| Confidence multiplier | Original: `1.4 - 0.8 * confidence`; persistence experiment: 1 |
| Actual alignment effect | `0.45 * (evil evidence change - good evidence change)`, compared against private-evidence reference |
| Overlapping pattern route | `0.3 * pattern weight`; choose stronger absolute alignment/pattern route, not their sum |
| Outing pattern | 0.3 per distinct night, credibility-scaled; 0.2 for a conflicting alibi; capped at 0.8 |
| Gift explanation | reduce that outing's weight by `0.8 * credibility of supporting gift claim` |
| Stance | accept at 0.6 agreement; partial at 0.35; otherwise reject; actual numerical effect stays visible |

These are not calibrated probabilities or final balance recommendations. Accuracy sliders
do not simulate the causes of illness. Chosen assumptions get a provisional conditional
tier, not a full Bayesian posterior. Direct outing suspicion still uses the earlier pattern
heuristic and can now affect implicated people under any alignment headline. It is not
an inferred movement likelihood. Supplied test factors and the challenged-alibi factor
exercise convergence within the world comparison. A Marked headline is assessed, but
does not itself grant a fixed suspicion discount; only the underlying evidence's evil/good
consequences change suspicion. There is still
there is no separate learned-secret belief ledger. No public-pressure or vote-threshold
effects are simulated. Player trust is held fixed as an experimental input, so its shown
before/after change is zero. NPC responses use deterministic assessment text rather than
the production voice system.

One editable case has one replaceable vector ledger entry per listener. The old effects are
removed **before** assessing a revision, avoiding feedback through the case's own
accusation of a witness. Repetition, wrapper changes and venue changes cannot stack it.
Independent simultaneous cases and support graphs shared between them are future work.

## Verification

Run with the project's Godot executable:

```text
godot --headless --path . --script res://tools/test_workshop.gd
godot --headless --path . --script res://tools/test_workshop_cases.gd
godot --headless --path . --script res://tools/test_workshop_reasoning.gd
godot --headless --path . --script res://tools/test_workshop_ui.gd
godot --headless --path . --script res://tools/test_workshop_canvas.gd
godot --headless --path . --script res://tools/test_workshop_consequences.gd
godot --headless --path . res://ui/case_workshop.tscn -- --workshop-smoke
```

The semantic suite covers the mirror worlds, conditional choices, source-dependent
persuasion, retraction, duplicate evidence, distinct outings, gift explanations, differing
priors, confidence, hidden-truth independence, seeded coherence and JSON replay. The UI
suite exercises actual slot signals, duplicate prevention, explicit claim citations,
conflict scope, reasoning-line assignment, the factor control, remembered presentation,
save/open, reasoning/confidence controls, nonmutating comparisons, and opening/reopening
the Workshop without replacing the running game.
The new cases suite covers shared proof routes, localized doubt, neutral/contrary factors,
indirect Nisha-to-Constance support, conflicting/alternative line assumptions, same-incident
corroboration, wrapper identity, provenance and atomic import validation.
The reasoning suite covers paired Insight profiles, independent referee results,
bounded conviction and speech, ignored connections, direct private checks, confidence
revision, repeated presentations, no invented illness exceptions and exact theory replay.
The canvas suite covers equivalence of direct/chained readings, shared roots, nested
assumptions, quoted versus endorsed alibis, conditional circumstantial convergence,
merged provenance, cycles, real drag/link/answer/unlink signals, and canvas/history replay.
The consequences suite covers collateral implication/exoneration, scoped intermediate
claims, rejected inferences, nested claim-less groups, duplicate/shared branches,
order-independent effects, private facts, shared bounded attention, clamping/retraction,
exact replay after social-input edits, and the actual jury-window displays.

On the development machine (Intel i5-12400, Godot 4.7.2, Windows), a representative
single-juror full grouped assessment now includes every character and intermediate claim.
See the cases suite's printed cold/cached and 4,096-state broad-stress timings for current
measurements. Whole-jury assessment is synchronous, so broad stress cases can pause
the UI. These are fixture measurements, not general
campaign performance guarantees. Constraint and movement caches are bounded; credibility
weights are recomputed, so changing trust/reliability does not reuse stale weights.

For a rendered smoke test add `--workshop-smoke --screenshot <absolute-path.png>` after
the user-argument separator when launching the Workshop scene without `--headless`.
