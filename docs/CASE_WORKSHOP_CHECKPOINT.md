# Workshop checkpoint before live integration

The completed bounded proof of concept is commit **`5d30513`** on
`codex/case-workshop`. Its reading, movement, impairment and conversion experiments
are the reference, not a commitment to the present enumeration algorithm or weights.

## What survives a framework change

- The card-question interaction and graph: answer cards, cite original reports,
  connect intermediate claims, merge contradictions and revise a case.
- Evidence semantics: source attribution, original incidents, observation/report/learning
  times, quoted testimony versus endorsed contents, and uncertainty about health.
- Behavioral requirements: Bart can be Marked; coherent does not mean established;
  Hollis can be implicated without convincing the listener about Constance; repeated
  reports and overlapping branches cannot multiply the same evidence.
- Temporal requirements: conversion does not invalidate an earlier reading; withdrawal
  concerns the particular statement; restoration cannot restore erased evil knowledge.
- Revision requirements: remove the previous case's consequences before reassessment,
  retract collateral effects too, and do not let a case undermine its own sources on
  each repetition.

These discoveries are more portable than the numerical model. A new interpreter still
needs to preserve dependencies, uncertainty, temporal exceptions and revision behavior.
That is meaningful implementation work even when individual examples are easy to explain.

## Portable specimens

`tests/fixtures/workshop_checkpoint_v5.json` contains six frozen input/output examples:
the four experiments, the converging graph with intermediate claims, and Bart-as-Marked.
Only permitted evidence, case structure and listener settings are included. Generator
truth is absent. No world generation is needed to evaluate the saved examples.

Run `tools/test_workshop_checkpoint.gd` to compare the current interpreter with these
examples. Use `-- --record` only when intentionally replacing the reference. The saved
stance, search status, compatible-world count, claim responses and signed effects
document model v5. Matching its floating-point values is a migration aid, not a design
requirement for a deliberately different model. These six specimens supplement the
broader semantic suites; they are not a complete behavioral specification.

## Live boundary

Integration starts with `Game.workshop_snapshot(card_numbers, listener_id, venue)`.
`game/workshop_bridge.gd` collects permitted data; `workshop/live_evidence.gd` produces
the versioned, JSON-compatible `demonologist-live-evidence-1` contract. It contains no
World/NPC objects. Another interpreter can consume this contract without reproducing
the Workshop generator or depending on the UI.

The adapter reads selected original evidence and recursively follows deduction inputs.
It preserves separate testimony receipts, common outing incident IDs, public setup rules,
public events and the selected listener's private readings, observations and beliefs.
An evil listener uses its existing cover mind. Capture neither creates nor synchronizes
that mind, changes beliefs, advances RNGs, nor spends player actions.

Legacy data has limits: relay disclosure time is not the original reporting time;
same-day changed readings need distinct assertion identities; some scene/event details
exist only in displayed text. These are retained with explicit incomplete/unsupported
issues, not interpreted by parsing prose or filled from hidden causes. Content identity
is not proof of a shared original acquisition event. Direct witness report times are
first witnessed reports, not claims to know an earlier undisclosed statement.

Live rules permit four modifier kinds, whereas the fixture assumes one Marked person.
The adapter therefore reports `assessment_ready: false`. It does not feed live cases to
the narrower fixture solver or apply additional suspicion over the old reading ledger.
The next integration slice must represent those legal alternatives, resolve supported
timing/provenance gaps, and compare assessments without enabling new belief effects.
