# Case Workshop proof of concept

Open **More > Case Workshop** in the game. The experiment opens in its own window;
closing it preserves its state and leaves the running case alone. Alternatively, open
`ui/case_workshop.tscn` in Godot and run that scene with F6.

The Workshop freezes a scripted ten-person town at dawn on day 3. It tests expressing,
interpreting and revising a case. Its new interpreter does not change the main game's
argument, persuasion, voting or dialogue systems.

The [revised implementation plan](CASE_WORKSHOP_PLAN.md) records the October 21
design review, known interaction gaps, proposed next slices and acceptance checks.
That plan describes future work; the behavior below describes the current prototype.

## Try these experiments

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
   Attach the accused's gift claim and answer **Night gift** on each Watch card; a
   credible walking gift reduces the suspicious interpretation. Merely selecting that
   label without supporting testimony does not.
6. Load **Conflicting reports**. The home alibi and sighting cannot both be accurate.
   You can argue that the accounts conflict, or argue suspicion from the outing plus
   the inconsistent alibi. Neither establishes evil alignment.
7. Under **Adjust this juror**, vary confidence, trust in you, or trust/suspicion toward
   a report's source. **Show calculation & accepted path** exposes agreement, premise
   quality, confidence scaling and the actual old/new ledger effects. Confidence scales
   movement, not the logical result. Restore the generated jury or reset discussion as
   needed.

**Save experiment** exports the seed, public evidence, current case/version, jury settings,
each presentation, objections and actual changes. **Open experiment** validates the file
and replays its history rather than trusting the exported outcomes. Imports support up to
200 presentations. Developer truth is omitted unless its checkbox is enabled; that data
never reaches the interpreter.

## Scenario and evidence boundaries

- Seed 692 is a teaching fixture inspired by case 692, **not a replay of that trace**.
  Agnes has the Lamplighter gift and Greta the Veteran gift so the five chosen evidence
  types coexist in one legal lineup. The five types are Surveyor, Rumormonger, Dowser,
  Night Watch and Lamplighter. Supporting cards supply a claim, alibi and player sighting.
- Other seeds permute cast assignments within this same scenario structure. They are
  reproducible variations, not an unrestricted three-day campaign generator. The fixtures
  deliberately retain the four-block Surveyor result and the core Marked ambiguity.
- `workshop/scenario.gd` constructs real World/NPC objects. It uses the existing
  `_receive_info` and `_day_gifts` routines, rejection-sampling the teaching reports.
  Night routes and the two legal Veteran attacks are scripted; full night AI is not run.
- Role, alignment and registration are separate. There are three original evil people
  and exactly one good Marked person. Marked registration can differ between readings.
  Report timestamps and the day the player learned a report are separate fields.
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

`workshop/jury.gd` retains the existing vocabulary and broad persuasion shape: agreement,
source credibility, player trust, confidence, stance, suspicion and an evidence ledger.
The jury adds its own reports and knowledge of being good. It examines smaller support
paths so adding optional support does not simply multiply down a stronger argument.
Explicitly conflicting premises can reopen/retract it. For unresolved cases, the listener's
strongest supporting and rival worlds are ranked using suspicion/trust terms shaped like
`Argue._expl_weight`; counts of worlds never become probabilities.

The initial tuning is deliberately visible and experimental:

| Component | Rule |
| --- | --- |
| Forced implication | agreement 1.0 |
| Conditional on player choices | agreement 0.4; does not promote a chosen conclusion into its own premise |
| Merely possible implication | 0.02–0.18, ranked by the listener's best supporting/rival explanations |
| Source credibility | `clamp(0.2 + 0.65 * NPC trust - 0.35 * suspicion, 0.05, 0.95)`; own sources 1.0 |
| Multiple sources | multiply distinct-source credibility within a path; retain the strongest path |
| Player multiplier | `0.5 + trust in player` |
| Confidence multiplier | `1.4 - 0.8 * confidence`, matching the current incoming-evidence shape |
| Conclusion effect | evil +0.45; good -0.4; Marked -0.1; suspicious +0.3; conflict 0 |
| Outing pattern | 0.3 per distinct night, credibility-scaled; 0.2 for a conflicting alibi; capped at 0.8 |
| Gift explanation | reduce that outing's weight by `0.8 * credibility of supporting gift claim` |
| Stance | accept at 0.6 agreement; partial at 0.35; otherwise reject; actual numerical effect stays visible |

These are not calibrated probabilities or final balance recommendations. Health is an
explicit premise of accepting a reading, not a simulated hidden-health likelihood. Chosen
assumptions get a provisional conditional tier, not a full Bayesian posterior or a model
of every premise's individual probability. Marked currently changes suspicion only;
there is no separate learned-secret belief ledger. No public-pressure or vote-threshold
effects are simulated. Player trust is held fixed as an experimental input, so its shown
before/after change is zero. NPC responses use deterministic assessment text rather than
the production voice system.

One editable case has one replaceable ledger entry per listener. The old effect is
removed **before** assessing a revision, avoiding feedback through the case's own
accusation of a witness. Repetition, wrapper changes and venue changes cannot stack it.
Independent simultaneous cases and support graphs shared between them are future work.

## Verification

Run with the project's Godot executable:

```text
godot --headless --path . --script res://tools/test_workshop.gd
godot --headless --path . --script res://tools/test_workshop_ui.gd
godot --headless --path . res://ui/case_workshop.tscn -- --workshop-smoke
```

The semantic suite covers the mirror worlds, conditional choices, source-dependent
persuasion, retraction, duplicate evidence, distinct outings, gift explanations, differing
priors, confidence, hidden-truth independence, seeded coherence and JSON replay. The UI
suite exercises actual slot signals, feedback on mistakes, remembered presentation,
save/open, and opening/reopening the Workshop without replacing the running game.

For a rendered smoke test add `--workshop-smoke --screenshot <absolute-path.png>` after
the user-argument separator when launching the Workshop scene without `--headless`.
