# Case Workshop evidence expansion

Agreed order (Oct 23): Night Watch and Gravedigger; live activity and traces;
quiet nights, Warden and Veteran; Lamplighter; Medium; Martyr and Sexton.
Psychologist remains social information rather than direct alignment proof.

## Checkpoint 1: Night Watch, Gravedigger and activity

Implemented:

- Night Watch receipts retain their complete list and watched block. Accepted
  reports establish the watcher was out and constrain other people's routes through
  that block. An omission does not mean someone stayed home. Empty player vigils
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

Validation: new `test_workshop_nightwatch_gravedigger.gd` (35 checks) and
`test_workshop_live_activity.gd` (25 checks), plus previous role, alibi, ownership,
presentation, efficiency and frozen-checkpoint suites. Further checkpoints below
will record additional supported roles and validation.
