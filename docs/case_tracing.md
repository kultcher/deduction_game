# Detailed case tracing: milestone 1

This branch adds logging foundations only. It has not been run in Godot in the
authoring session: the execution service was unavailable. Run the smoke tests
below before merging. There are no intentional gameplay/tuning changes.

## Run locally

From the repository root (use your Godot executable's name/path):

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/test_trace.gd
godot --headless --path . --script res://tools/test_beliefs.gd
godot --headless --path . --script res://tools/test_shadow.gd
godot --headless --path . --script res://tools/test_outcomes.gd
```

The new suite exits nonzero if a check fails and prints
`TRACE: ... checks, 0 failures` on success. Also check for Godot parse/runtime errors;
some older suites only print their failure count rather than returning nonzero.

The new suite exercises small changes, direct relationship assignments, ledger
capture, real/shadow ordering, JSONL export, reconstruction from deltas, and six
paired passive cases (seeds 42, 61251, 25923 with 7 and 10 NPCs). Each pair compares
trace enabled/disabled gameplay state, RNG state, shadow RNG state, board, and
player-facing output after each command. This is a smoke test, not exhaustive
coverage of every dialogue/action branch. Report the first Godot error and the
final failure count if anything fails.

For a manual check, play a short case, ask a question/present evidence, then use
`log`. Find `case_<seed>.trace.jsonl` beside the usual JSONL/text files. Automatic
end-of-case export writes it too. The existing displayed paths and `log_paths`
retain their two-file contract; the extra path is `g.w.dlog.trace_path`.
No trace is uploaded anywhere by the game.

## Enable/disable

`Game.detailed_logging` defaults to true for current development/playtest exports.
Set it before `new_case`; it is passed to `World.detailed_logging` before setup.
Direct World callers can set that property before `setup`. Configure it for the
whole case; switching it mid-case is not supported in this milestone. This is
separate from the spoiler/debug overlay and does not invalidate scoring.

Optional `Game.trace_build` and `trace_tuning` strings are passed to the header.
They default to empty (unknown), not an invented revision. Set them in a test
harness/release configuration when comparing tuning builds.

Legacy `.jsonl` and `.txt` logs and their local sequence numbers are unchanged.
The detailed sidecar is one combined, versioned real/shadow export. A failed
sidecar write reports a Godot error and does not claim a successful trace path.

## Trace schema 1

Every row has `schema`, global `seq`, `day`, `phase`, `type`, `actor`,
`target`, `stream` (real/shadow), `action_id`, `data`, and `reason`.
Ordinary log events are copied into the trace at their actual execution order;
the two legacy streams remain separate. Schema 1 is independent of the existing
case-summary schema.

- `trace_header`: seed, roster size, engine, optional build/tuning identifiers,
  and coverage marker. It precedes roster setup.
- `action_begin/end`: setup or player-command scope. Events outside a command
  (for example direct UI APIs or test calls) can have action_id 0. This means
  unscoped, not an inferred association with the preceding command.
- `state_checkpoint`: tracked NPC state with explicit `mind` real/shadow and tag.
  Includes all NPCs, including dead people, and full rolled relationship maps.
- `state_delta`: exact differences since the previous observation of that mind.
  Changes have string-array `path`, `had_before`, `has_after`, `from`, `to`.
  Dictionaries are diffed recursively; arrays are replaced atomically. Existence
  flags distinguish an absent property from a null value. JSON object keys are
  strings, including numeric ledger-effect keys.
- `value_change`: precise central trust/cap/suspicion updates; requested versus
  applied values reveal clamping. Suspicion events include a ledger id when supplied.
  These explain substeps; do not apply them again when replaying state deltas.
- `decision_roll`: the existing sigmoid decision's exact score parts, probability,
  already-consumed draw, and outcome. It makes no additional RNG calls.

Replay each mind from its first checkpoint, applying only its state deltas.
Subsequent checkpoints must match the reconstructed state; they also allow a
viewer to seek without replaying from the beginning. Existing ordinary events and
value_change records supply context, not an additional set of state mutations.

Tracked state includes relationships, trust/caps, suspicion, pressure, disclosure,
claims, credibility/doubt, role beliefs, protection/spare preferences, knowledge,
information results, and the ledger (entries, source/night reliability references,
weights, effective influence, supports/justifications, and applied contributions).
The ledger's applied contributions are its accounting values; they are not the
same as actual clamped movement of the suspicion score.

## Capture boundaries and honest limits

Checkpoints occur after setup and at existing phase/night snapshot points.
State differences are also captured before/after commands, at export, after belief
recomputation, and around shadow synchronization/return. Copies are immutable and
reading them never creates or synchronizes a shadow.

Boundary differences capture direct writes such as relationship adjustments,
pressure decay, death clears, or conversion resets. The recorded boundary is an
observation time, not a claim that every change occurred at that exact instant.
Multiple direct writes within a boundary may collapse to a net change, including
a net zero. Central value_change events retain finer trust/suspicion substeps.
Shadow sync can overwrite its trust/pressure with the real NPC's values; those
overwrites remain visible rather than being mislabeled as player interactions.

Not yet covered: individual reasons for every relationship/pressure write,
all early disclosure gates, complete vote/interpretation decision schemas,
stable cross-card provenance beyond existing fact/ledger ids, direct UI API action
scopes, file-size/performance budgets, a standalone loader or graphical viewer.
The sidecar currently accumulates in memory; assess real-case sizes before large
batch runs. Legacy logs remain useful but cannot acquire missing history.

## Next milestone after smoke-test results

1. Add specific reasons/causal ids to remaining direct mutations and UI actions.
2. Standardize vote, nomination, disclosure-gate and interpretation records.
3. Add the Python loader/validator and local interactive history/ledger viewer.
4. Measure trace size/time on real cases; optimize without dropping small changes.
