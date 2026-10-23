# Case Workshop evidence expansion

Agreed order (Oct 23): Night Watch and Gravedigger; live activity and traces;
quiet nights, Warden and Veteran; Lamplighter; Medium; Martyr and Sexton.
Psychologist remains social information rather than direct alignment proof.

## Checkpoint 1: Night Watch, Gravedigger and activity

Implemented:

- Night Watch receipts retain their complete list and watched block. Accepted
  reports establish the watcher was out and constrain other people's routes through
  that block. An omission does not mean someone stayed home. Complete player vigils
  constrain their watched block, excluding same-night victims omitted by native
  vigil collection. Ordinary glimpses do not establish complete observation coverage.
- Gravedigger uses joint unique-role constraints, distinguishing Demon and minions.
  Marked can receive any evil-role result while the reader remains healthy. The
  execution must have a matching public process receipt on that day. No execution
  role or cause is imported from hidden referee state.
- Public executions, Demon deaths and Martyr substitutions provide event-time
  population bookkeeping. An executed person is absent that night; a Demon victim
  was still alive for that night's readings and movement. Earlier Surveyor populations
  remain the original population.
- Direct-road possibilities include the Lamplighter tour. A route requiring that
  tour requires an available, unique good Lamplighter role; it cannot be used to
  excuse two different people's impossible routes.
- Evening sightings, structured crime traces, night sightings, complete coverage,
  role explanations and challenged home accounts enter a joint live activity
  comparison. A scene's trace is consumed once across the possible Demon candidates,
  rather than once per suspect. Multiple descriptions of a crossing remain one
  outing; different nights add evidence under a persistent activity profile.
- New searched crime-scene cards carry scene, victim, material and crime-night
  fields. Old prose-only trace cards remain explicitly marked for fallback.
- Shared ownership retains the exact originals. Repeated presentations replace the
  vector; they do not add another copy. Walking-gift citations include the referenced
  claim as an ordinary evidence root and compete for attention.

The live comparison is deliberately bounded. It marginalizes persistent activity
and evening habits instead of adding every route to the alignment-world domain.
Public role explanations change the lawful-outing alternative. Base good profiles
are ordinary/gift/private-errand weights 0.75/0.15/0.10; a supported walking role
uses 0.20/0.70/0.10. Ordinary outings use 0.05/night, private errands 0.55, minion
outings 0.25. These are experimental gameplay assumptions, not measured prevalence.

Crime material uses the generator's 60% killer-evening component with a conservative
40% uniform possible-passer background. It never reads the actual hidden passers.
The probability that there were no passers and the exact composition of possible
passers are not yet inferred. Repeated evening material shares a latent habitual
block (0.7 repeat propensity); material alone does not single out a resident.
This is circumstantial support, not proof or calibrated odds of guilt.

Native movement and trace fixtures remain frozen and separate from the live adapter.
No full conversion/succession history is enabled by this checkpoint.

Validation: new `test_workshop_nightwatch_gravedigger.gd` (36 checks) and
`test_workshop_live_activity.gd` (28 checks), plus previous role, alibi, ownership,
presentation, efficiency and frozen-checkpoint suites. Further checkpoints below
will record additional supported roles and validation.

## Checkpoint 2: protection, counts, relays and triggered gifts

Implemented after `8e5fbdb`, in the agreed order:

- Veteran attack reports constrain the candidate Demon's approach using the public
  route rules. Healthy reports cannot claim two first-attack survivals, or a survival
  on a night when the Demon killed somebody else. Marked does not alter this gift.
- Quiet-night cards provide modest circumstantial support to Warden/Veteran claims.
  Native quiet-night credit is certified by exact event id, claimant, relation and
  effect before replacement; disabling/withdrawing the shared owner restores it.
  Competing claimants share credit, a known player ward halves it, and a knell reduces
  it further. Repeated copies of a night do not stack. Current experimental base
  weights are 0.06 Warden / 0.025 Veteran, scaled by source credibility and number of
  claimants, capped at 0.10 before normal social scaling. Veteran credit counts one
  night. This support and movement consequences use a stronger-magnitude envelope,
  not additive awards for the same incident.
- Warden guarding testimony preserves the named door and constrains the stated
  destination. Being seen at a door does not establish an attack or successful
  protection. Lawful destinations for Warden and Medium activity use the public
  event-time roster; Medium visits require a deceased resident.
- Lamplighter count consistency uses at most 1024 outing masks per relevant night
  in a ten-person town. Any number of answer slots may remain unknown. Counts exclude
  the Lamplighter, respect who was alive that night, and combine with sightings/home
  accounts to find forced outings. No minimum number of named people is required.
  The soft activity model uses forced consequences; it does not marginalize every
  unresolved cardinality assignment into a new probability model.
- A single Medium relay reuses supported original reading, sighting, home-account
  or guard-testimony semantics. Original source/time and Medium source/visit time
  remain separate. The original speaker's credibility/health is shared across direct
  and relayed copies; transmission credibility and hearing routes remain separate.
  A faithful relay of an already-present original is not independent corroboration.
  Referee cause flags are stripped recursively. Unsupported private Medium opinions
  keep their native owners rather than disabling unrelated supported evidence.
- Martyr choice reports do not establish that the chosen person is good. Explicit
  outcome reports require a matching public execution and permit evil or Marked
  registration. A public substitution identifies the unique good Martyr and good
  saved participant. Conflicting choice claims cannot both be granted.
- Sexton use reports check the public living count, once-per-case use and working
  walking-gift reports on the relevant night. A working toll conflicts with a Demon
  death that night. Secret outings and nonwalking gifts remain possible. Hearing the
  bell alone does not prove the gift worked.

Explicit remaining boundaries:

- A prior Martyr promise plus a later execution needs a distinct dated outcome/health
  adapter. That connected pair is marked for native fallback; the earlier healthy
  choice is not silently promoted into a healthy activation at the hanging.
- Medium cause modifiers need a selector for which speaker/stage is questioned.
  They are visibly unavailable on relay cards. Nested Medium chains and opinions
  remain unsupported. Richer trust/blame relationship changes remain in the backlog.
- Full conversion/succession histories, specific poisoning schedules, old traces
  lacking scene fields, ordinary dropped items and other unsupported receipts still
  retain explicit fallback. Psychologist remains social information, not alignment
  proof. Existing eight-receipt/six-claim/64-state workload gates remain in place.

Six new suites now contain **160 checks**: Night Watch/Gravedigger 36, activity 28,
protection 22, Lamplighter 18, Medium 24, Martyr/Sexton 32. All 32 Workshop/native
regression suites pass, including the frozen fixture checkpoint and headless UI
interactions. These checks are not a human live-game playthrough.

Two expanded native whole-town profiles took approximately **19.25 s** (seed 692,
five reports) and **18.90 s** (seed 4242, seven reports). These are broader workloads
than the prior four-/five-report role benchmarks, not like-for-like speed comparisons.
Listener/stage breakdowns and fallback counts are recorded in
`benchmarks/workshop-evidence-expansion-2026-10-23.json`.
