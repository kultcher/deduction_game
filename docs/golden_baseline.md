# Golden behaviour baseline

A recorded run of the game to diff against during a port (the C# migration) or any
refactor that should not change behaviour. If the candidate matches the baseline,
nothing drifted; if not, the diff names the first refresh or command where the two
runs part ways.

## What is recorded

`tools/golden_capture.gd` plays fixed seeds with the passive player from
`test_trace` (decline, bye, wait, vote no, sleep) to the start of Day 4 and writes one
JSON line per:

- **refresh**: every shared belief refresh (after phase) for every mind, covers
  included: suspicion, outside layer, requested/applied joint effects, circumstantial
  effects, `source_doubt`, owned entries, issues, resentments, `npc_trust`, trust.
- **step**: every command, with the reply text, the world RNG state, day/phase/state,
  public log, executions, meeting, board, and the full traced state
  (`DevLog.TRACE_FIELDS`) of every NPC and cover, plus each cover's RNG state.
- **meta / end**: seed, size, day reached, refresh count, fallbacks, executions.

Default seeds: 900 and 42 (7 NPCs), 54875, 692 and 98933 (10 NPCs). RNG states are
strings (they are 64-bit); doubles are written at full precision.

## The baseline

`tools/golden/baseline_3bd51ea/` holds the capture from main at `3bd51ea` (purge 2b
plus the dialogue pass, Nov 2), gzipped. It was recorded twice in parallel and the two
captures were identical at zero tolerance, so the game is deterministic under capture.

## Using it

```
godot --headless --path . --script res://tools/golden_capture.gd -- --out /abs/candidate
python3 tools/golden_diff.py tools/golden/baseline_3bd51ea /abs/candidate
```

Options: `--seeds 900:7,54875:10` and `--day N` on the capture (a subset only diffs
against the same seeds in the baseline); `--tol` on the diff (default `1e-9` relative,
`0` for exact); `--ignore key1,key2` to skip keys anywhere, for fields intentionally
retired (for example `discounted,honesty`, which the legacy recompute still fills).

A full capture takes about 13 minutes in the container (the 10-NPC seeds are
3 to 5 minutes each).

## Porting notes

The usual sources of drift in a port, in rough order of likelihood:

1. **Iteration order.** GDScript dictionaries keep insertion order; C# `Dictionary`
   does not promise it. Loops over people, ledger entries and cards feed sums, sorts
   and tie-breaks. Use an insertion-ordered map.
2. **RNG call order.** Keep Godot's `RandomNumberGenerator` and the same seeds; one
   extra or reordered draw shifts everything after it (the step records' `rng` field
   shows exactly when).
3. **Floating point.** Both use 64-bit doubles, but reordering a sum or a different
   clamp/snap changes the last digits. Prefer exact matches; where a tolerance is
   needed, note which values needed it.
4. **Integer division, string formatting and sorting stability**, which differ
   subtly between the languages; some keys are built from formatted strings.

Matching numbers proves the port is faithful, not that the game plays well; if
behaviour is tuned during the migration, rerecord the baseline from the tuned commit
and rerun the passive A/B as well.
