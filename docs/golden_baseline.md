# Golden behaviour baseline

A recorded run of the game to diff against during a port (the C# migration) or any
refactor that should not change behaviour. If the candidate matches the baseline,
nothing drifted; if not, the diff names the first refresh or command where the two
runs part ways.

## What is recorded

`tools/golden_capture.gd` plays fixed seeds with a passive player (decline, bye,
wait, vote no, sleep) to the start of Day 4 and writes one
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

### Post-purge baseline (the C# oracle)

`tools/golden/baseline_82faa5b/` is the capture from `claude/purge-2c-3` at `82faa5b`:
legacy purge 2c and 3 plus the tuning literal hoist, Nov 2. **This is the reference
the C# migration diffs against** (`--tol 0`). Recorded twice in parallel, identical.

Against `baseline_3bd51ea` (with `--ignore engine,discounted,honesty,effects,applied,eff,enabled`,
the fields the purge retired) seeds 42, 54875 and 900 are identical; 692 and 98933 differ
only by two intended 2c fixes:

- 98933: the Revenant curse's "+0.15 to every yes-voter" ledger entry was never owned
  by the shared model, so the legacy path pushed five outside values to 0.245. 2c
  stops generating legacy effects, so the outside layer stays flat at 0.1.
- 692: role beliefs were derived from the previous refresh's source doubt. Greta kept
  believing Constance's Clerk claim after catching her lying; now she doesn't.

### Current baseline (Nov 5, night): `baseline_9379b1e`

`tools/golden/baseline_9379b1e/` is the capture from `9379b1e` (branch `claude/npc-openness`):
`baseline_b9a0376` plus NPCs being more open with each other. Chats pass on up to three
things; readings go far more readily to trusted listeners; hints and claims reach
acquaintances; the dead's private readings get passed on and told at the meeting. Two
captures identical. Every seed parts from `baseline_b9a0376` early (record 0 to 36),
at the first NPC conversations.

Passive A/B, seeds 2000-2011, 12 games per cell, Default script:

| Cell | Good wins (main → new) | Good hanged | Evil hanged | NPC shares |
|---|---|---|---|---|
| 7 NPCs | 4 → 3 | 10 → 12 | 9 → 7 | 133 → 228 |
| 10 NPCs | 5 → 3 | 14 → 18 | 20 → 17 | 460 → 633 |

Within noise for 12 games, but both cells lean the same way. Share mix at 10 NPCs, per game
(main → new): readings 2.2 → 4.1, role hints 1.0 → 2.7, claims 0.8 → 1.5, relayed readings
0 → 0.6, meeting relays of the dead's readings 0 → 0.08.

### Previous baseline (Nov 5, night): `baseline_b9a0376`

`tools/golden/baseline_b9a0376/` is the capture from `b9a0376`: `baseline_e9f1e47` plus the
playtest 13910 dialogue fixes (PR #73), which are wording only. Before main moved, the same
fixes were checked against `baseline_a42ef71`: all five seeds identical with `--ignore
reply,said,why_own,why_public,text,statement,why,dialogue_memory,reasons` (reason wording,
reply text, the new `meeting.said` record). Against `baseline_e9f1e47` all five seeds are identical with
the same `--ignore`. An accusation floor in that PR was reverted
before merging (BACKLOG, NPC behaviour); its A/B notes are in the handoff log.

### Previous baseline (Nov 5, evening): `baseline_e9f1e47`

`tools/golden/baseline_e9f1e47/` is the capture from `e9f1e47` (`claude/evidence-honesty-fixes` with main merged in, including the 2026-11-05 maintenance fixes):
main after patch 015 plus the Nov 5 evidence honesty fixes:
- report chance content is the share of worlds where the content holds;
- the vigil exclusion is soft, about 10:1 against a walker's claim;
- walker claims bind to the duty;
- the Medium is modelled visiting earlier Demon victims only.

Two captures, identical. Against `baseline_a42ef71` every seed parts at record 1: the first
belief refresh already weighs readings differently. The passive and bot A/B is in
`docs/handoff_log.md`.

### Previous baseline (Nov 5): `baseline_a42ef71`

`tools/golden/baseline_a42ef71/` is the capture from `a42ef71`: `baseline_9187b09` plus the
fixes from the 2026-11-05 maintenance report. Two captures identical. Captures now write
user-data paths as `user://` (the dev-log reply at game over), and `golden_diff.py`
normalizes them, so a baseline compares on any machine (the Nov 4-5 red X on CI was the
`/root/...` path in `baseline_9187b09`, not gameplay). Against `baseline_9187b09` only seed
42 differs, from day 3's vote on Merrin: Agnes (the Demon) now votes to hang Merrin (the
Revenant, totem hidden), since a Revenant with its curse ready is cheap to let hang. The
other four seeds are identical.

### Previous baseline (Nov 4, night): `baseline_9187b09`

`tools/golden/baseline_9187b09/` is the capture from `9187b09`: `baseline_175e1f5` plus
Argon's patch_014 (Monitor, Confessor) and meeting plan M2b (podium press). Two captures
identical. Against `baseline_175e1f5` the only differences are the pending nomination's
new `press` field and the prompt text that offers the press (`--ignore engine,press,reply`
shows every seed identical): the new roles aren't on the Default script the seeds deal from.

### Previous baseline (Nov 4, late): `baseline_175e1f5`

`tools/golden/baseline_175e1f5/` is the capture from `175e1f5`: main with dynamic scripts and
patch 013 (Psychologist rework, Muddler), plus the C# cutover, the Warden packing fix and
the `_fraction` C# port. C# only. Two captures identical. Identical to the
C# capture of `47913b7` (dynamic-script before the cutover); every seed differs from
`baseline_0534e6b` because of patch 013.

### Previous baseline (Nov 4, evening): `baseline_0534e6b`

`tools/golden/baseline_0534e6b/` is the capture from `0534e6b` (Argon's patch_012
playtest fixes plus meeting plan M2a: anchored/raw player nominations, block safety,
reactive testimony and crowd fading; plus the M1 second-hand opinion note and the single
refresh call). Two GDScript captures identical,
`--mode csharp` identical. Against `baseline_4f7ba7f` every seed parts at record 1:
012's Rumormonger/Chronicler `chance_content` moves day-1 case-derived suspicion. Passive
A/B over seeds 2000-2011 (C#): good wins 42% -> 17% (7 NPCs), 8% -> 25% (10 NPCs);
executions similar. 12 seeds is noise-sized; M4's 150-seed sweep is the real measure.

### Previous baseline (Nov 4, afternoon): `baseline_4f7ba7f`

`tools/golden/baseline_4f7ba7f/` is the capture from `4f7ba7f` (Argon's patch_011:
Chunk 2 world-mask roles Augur, Chronicler, Magistrate; Chunk 3 Executor and Registrar;
Surveyor/Dowser rework). Two GDScript captures
identical, `--mode csharp` identical. Against `baseline_165ce09` every seed parts at the
first record: the new roles change the starting deal. Passive A/B over seeds 2000-2011:
good wins 25% -> 42% (7 NPCs), 33% -> 8% (10 NPCs); worth a larger sweep at 10.

### Previous baseline (Nov 4): `baseline_165ce09`

`tools/golden/baseline_165ce09/` is the capture from `165ce09` (meeting plan M1, peer
role hints and claims, on top of the Seer bluff fix and the refresh cost cleanup).
Recorded twice in parallel (identical),
and the `--mode csharp` capture is identical to it, so it is also the C# oracle.

Against `baseline_82faa5b`, the Seer fix and the refresh cleanup changed nothing on
these seeds (identical with `--ignore engine,sus_why,sus_src`). M1 moves all five from
the first private gift share on: new `role_hint` / `role_claim` hearsay, the small trust
bump those shares give, and the plays that follow (seed 98933 parts at step 8, Agnes
hearing Dorian's hint). Passive A/B over seeds 2000-2011: good wins 33% -> 25% (7 NPCs)
and 17% -> 33% (10 NPCs), executions similar; within noise for 12 seeds.

`baseline_82faa5b` and `baseline_3bd51ea` stay for history.

### One check (from Nov 4 evening: C# is the only solver)

The GDScript solver kernels were retired on Nov 4 (snapshot: branch
`archive/gdscript-solver-final`, commit `47913b7`), so there is no parity check any more.
CI captures once (C#) and diffs it against the fixed baseline at `--tol 0`, and that diff
is the gate:

- Behaviour-neutral work (refactors, ports, UI) must show "identical".
- An intended behaviour change will differ: re-record the baseline from that commit in
  the same branch (two captures, identical to each other), point `BASELINE` in
  `.github/workflows/ci.yml` at it, and run the passive A/B.

Changes to the solver kernels go in C# only (`workshop/cs/`); the GDScript files in
`workshop/` marshal inputs and call it. History: Nov 3 to 4, CI also diffed a GDScript
capture against a C# one from the same commit (the migration gate).

Check a capture's log for `SCRIPT ERROR` lines before trusting a diff: Godot keeps
running when a script fails to compile, and the capture then records the broken game.

## Using it

```
godot --headless --path . --script res://tools/golden_capture.gd -- --out /abs/candidate
python3 tools/golden_diff.py tools/golden/baseline_9379b1e /abs/candidate
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
