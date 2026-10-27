# Case Workshop: findings worth keeping

A condensed record of the Oct 20–23 workshop experiments on `codex/case-workshop`. The
original nine docs, benchmark JSON and bundle were pruned. They are in git history,
reference commit `d3350ff`; the pre-integration reference is `5d30513`. The current
plan is [CASE_REASONING.md](CASE_REASONING.md).

## Semantic rules (these hold under any interpreter)

- **No double counting:** one witness reached by several paths, repeated reports and
  overlapping branches all count once. Retellings of one reading share its accuracy
  origin.
- **Quoted versus endorsed:** "Constance said she was home" is a fact about Constance's
  testimony, whether or not the alibi is true. Distrusting her doesn't erase that she
  said it.
- **Coherent is not established:** removing a challenged constraint can make a theory fit;
  show that as conditional ("your explanation fits *if* this reading is unreliable").
- **Intermediate claims are scoped:** a listener can accept "Hollis follows *if* the
  readings are sound" while doubting the readings. Rejecting an intermediate claim
  doesn't discard the observations under it.
- **Effects reach everyone:** a case about Constance can raise Hollis and Lian, or clear
  others. Effects are replaceable per case, and revising a case withdraws the previous
  version's effects, including collateral ones, before reassessment. A case must not
  weaken its own sources a little more on each repetition.
- **Time:**
  - a reading constrains its source's alignment *at the time of the reading*;
  - conversion doesn't invalidate an earlier reading;
  - withdrawing a retelling disables only that statement;
  - restoration can't restore erased evil knowledge.
- **Hidden truth never enters assessment:** referee-only `true` flags and generator
  truth stay out of listener inputs.

## Readings and challenges

| Gift | Healthy, accurate interpretation |
|---|---|
| Clerk (night 0) | One named person holds the named good role; the source holds Clerk |
| Archivist (night 0) | One named person holds the named minion role (not the demon); the source holds Archivist |
| Seer yes | The pair holds the demon, the Seer's persistent good red herring, or a Marked person registering positively. Causes can coexist |
| Seer no | Neither is the demon or that red herring. Minions remain possible; Marked may register negatively |

- **The Seer's red herring** is fixed at setup, good, not the Seer, and possibly also
  Marked. Marked registration can change between readings; the red herring can't. Two
  disjoint yes pairs can't both be explained by the red herring alone.
- **Challenges:**
  - **Unlikely:** the report needs an unusually restrictive layout. It's a reason for
    skepticism, with no alignment assumption.
  - **Misled:** a good-faith reading misdirected (impairment, Marked, red herring). It
    names no Poisoner by itself.
  - **Lying:** knowingly deceptive. A discrepancy alone doesn't prove intent, and a liar
    isn't necessarily evil.

  An unsupported challenge earns no automatic discount; supporting cards move it. The
  same rarity argument can't earn several discounts.
- **Impaired is not false:** an impaired Seer can still return an accurate result. A
  failed accuracy assumption removes a constraint; it doesn't negate the report.
- **Poison windows:** poison lasts from the night given until the next night starts,
  including the day between. Impairment evidence shares one uncertainty across reports
  inside that window, and doesn't reach earlier or later readings.
- **Source honesty and gift accuracy are separate.** A good NPC can knowingly tell a false
  whereabouts story. That's why the new plan splits honesty into channels.

## Evidence semantics, by mechanic

- **Night Watch:** an accepted report says the watcher was out and constrains routes
  through that block. An omission doesn't prove someone stayed home. A player's complete
  vigil constrains its block, but a glimpse doesn't establish full coverage.
- **Gravedigger:** joint unique-role constraints (demon versus minions). Marked can
  read as any evil role while the reader is healthy. It needs a matching public
  execution that day.
- **Population over time:** an executed person is absent that night. A demon victim was
  still alive for that night's readings and movement. Surveyor counts use the original
  population.
- **Lamplighter:** a route that needs the lamp tour needs an available, unique good
  Lamplighter. It can't excuse two different people's impossible routes. Count checks
  used at most 1,024 outing masks per night.
- **Traces:** a scene's trace is used once across all demon candidates, not once per
  suspect. Several descriptions of one crossing are one incident.
- **Veteran:** a healthy report can't claim two first-attack survivals, or a survival on
  a night the demon killed someone else.
- **Quiet nights:** modest support for Warden and Veteran claims (experimental 0.06 and
  0.025, scaled by credibility and the number of claimants, capped at 0.10). Shared
  between competing claimants, halved if the player warded someone, reduced by a knell.
- **Warden and Medium:** a guarding statement names a door and constrains the
  destination; being seen at a door doesn't prove an attack or a save. Medium visits
  need a dead resident.
- **Movement priors (experimental, not measured in the main game):**
  - evil: one third hunting demon, two thirds minion, and the minion walks with
    probability 1/4;
  - good with no claim: 0.75 unidentified lawful activity, 0.15 walking gift, 0.10
    private errand;
  - a credible gift or errand claim shifts that mix toward its explanation (0.70).

  A claimed explanation only counts when it's actually cited and credible.
- **Revenant:** public knowledge is "one originally good surviving yes-voter was
  converted". The player can propose who and when (before, during or after); that
  narrows their explanation and is not evidence.

## The live evidence contract

`Game.workshop_snapshot(card_numbers, listener_id, venue)`, via
`game/workshop_bridge.gd` and `workshop/live_evidence.gd`, produces
`demonologist-live-evidence-1`. It's JSON-compatible, has no World or NPC objects, and
carries:
- the selected original evidence, following deduction inputs recursively;
- separate testimony receipts and common outing incident IDs;
- the public setup rules and events;
- the listener's private readings, observations and beliefs.

Evil listeners use their good self. Capture changes nothing: no beliefs, no RNG, no
actions.

**Legacy data limits** are flagged in the contract, not guessed from prose:
- a relay's disclosure time isn't the original reporting time;
- readings changed on the same day need distinct identities;
- some scene details exist only in displayed text.

## Performance lessons

- **Constraint solving is cheap:** 575 bitmask solves took 65 ms on the 5,040-world
  ten-person domain (0.11 ms each).
- **The cost was elsewhere:**
  - the 2^u credibility mixture, run separately for each listener and each person in
    the consequence loop;
  - about 170,000 dictionary lookups in the reasoner;
  - repeatedly rebuilding prior rankings.
- **Measured whole-town presentations:** 29 s at first, 8.7 s (seed 692) and 13.6 s (seed
  4242) after reuse fixes. The native benchmarks reached 1.66 s and 2.50 s before the
  Insight integration, and 4.94 s and 2.54 s after it.
- **Useful techniques carried forward:**
  - indexed report masks;
  - shared credibility plans;
  - exact reuse of whole assessments for unchanged inputs (3 ms on a repeat);
  - diagnostics computed only on demand;
  - progress dialogs between listeners.
- **C# / GDExtension:** port only a measured hot core, with typed structures and integer
  IDs. Translating Godot dictionary access directly keeps the interop overhead, and C#
  web export isn't supported, so check that before committing. No runtime port fixes
  exponential growth.
