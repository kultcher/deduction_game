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

### Current baseline (Nov 11): `baseline_bd1b404`

`tools/golden/baseline_bd1b404/` is the capture from `claude/sighter-contest`. A sighting (or a
Night Watch's "I saw X pass by") counts at `EVIL_SIGHTER_TRUTH` (0.15) of the time in a world
where its sighter is evil, and otherwise as an invented sighting (belief-model plan, Nov 11).
A sighter converted by the Revenant's curse is doubted only for what they told while converted.
- **Divergence from `baseline_a03bf72`:** every seed. 42 at record 31 (refresh #20, Nisha,
  day 2), 54875 at record 9 (refresh #6, Isolde, day 1), 692 at record 12 (refresh #7, Agnes,
  day 1), 900 at record 12 (refresh #8, Kiran, day 1), and 98933 at record 123 (refresh #105,
  Merrin, day 2). Adding the converted-sighter rule moved only 54875, from record 242 (day 3).
- **Record counts:** 42 101 (was 108), 54875 302 (321), 692 249 (251), 900 143, 98933 346 (285).
- **Stability:** two captures were identical.

### Previous baseline (Nov 10): `baseline_a03bf72`

`tools/golden/baseline_a03bf72/` is the capture from `claude/own-alibi-lie-aware` (#124,
Quill). A person's own home alibi is lie-aware when the world makes them evil (belief-model
plan, Phase 1 fix 3).
- **Divergence from `baseline_73b103a`:** 42 at record 23 (refresh #14, Nisha, day 2),
  54875 at record 1, and 98933 at record 9 (refresh #3, Agnes, day 1). 692 and 900 are
  identical.
- **Record counts:** 42 108 (was 90), 54875 321, 692 251, 900 143, 98933 285.
- **Stability:** two captures were identical.

### Older baseline (Nov 10): `baseline_73b103a`

`tools/golden/baseline_73b103a/` is the capture from `claude/challenge-reliability`. An
accepted "lying" challenge no longer discounts the reading's reliability (belief-model plan,
Phase 1 fix 2).
- **Divergence from `baseline_0e64b81`:** only 98933, at record 256 (refresh #221, Isolde's
  cover on day 3, afternoon), by about 1e-6 in two requested suspicions. 42, 54875, 692 and
  900 are identical.
- **Record counts:** 42 90, 54875 321, 692 251, 900 143, 98933 285.
- **Stability:** two captures were identical.

### Previous baseline (Nov 10): `baseline_0e64b81`

`tools/golden/baseline_0e64b81/` is the capture from `claude/npc-behaviour-1110` (#117).
Everyone now works one shift. The old extra-shift roll still draws, so setup deals the same;
every NPC with an old extra shift now has that phase free.
- **Divergence from `baseline_14f999c`:**
  - 54875 and 98933 part at the meta record (whose NPCs carry extra shifts).
  - 42 parts at record 2, 692 at record 3 and 900 at record 11, all on day 1 (more idle
    moves).
- **Smaller changes on the same branch:** the haunt-roll bonus, the dead's answers, and the
  −0.40 day-1 term.
- **Record counts:** 42 90, 54875 321, 692 251, 900 143, 98933 285.
- **Stability:** two captures were identical.

### Previous baseline (Nov 9, late): `baseline_14f999c`

`tools/golden/baseline_14f999c/` is the capture from `claude/small-fixes-1109` at `14f999c`,
which is stacked on #113. Against `baseline_e25fca9`, only 692 changes, at record 76:
Nisha's defence is now a plea, not a challenge. She was out on the night Constance's
reading put her out, so she gives her account instead of calling the reading a lie (the
true-sighting defence). 42, 54875, 900 and 98933 are identical.

The branch's other changes don't reach the golden seeds:
- the board marks;
- the living-rival line;
- the clash-with-own-beliefs line;
- the doubt-after-a-hanging clause;
- the Breathstealer crowd boost: no Breathstealer acted in a crowd of three.

### Previous baseline (Nov 9, night): `baseline_e25fca9`

`tools/golden/baseline_e25fca9/` is the capture from `claude/log-12926` at `e25fca9`. That
branch rewords an accusation reason when it rests on a reading about someone else. The old
wording was "my own reading contradicts their account". The new wording names the reading,
for example "my reading cleared Fenwick, and that doesn't square with their account".
- **900 and 54875:** only the reason text changes.
- **42 and 692:** behaviour changes too, because the meeting skips a point when its text was
  already spoken (`mind_meeting`, `spoken`). Distinct readings that used to share the
  generic wording no longer collapse into one, so different items get said, and owned
  defences and applied suspicion shift from there.
- **98933:** identical.
- **The Muddler's gossip floor** (also on that branch) changes nothing here: the default
  script has no Muddler.

Against `baseline_db5b24e`: 42 parts at record 43, 54875 at record 208, 692 at record 68,
900 at record 21; 98933 is identical. Record counts: 42 147, 54875 260, 692 207, 900 172,
98933 275. Two captures were identical.

### Previous baseline (Nov 8, night): `baseline_db5b24e`

`tools/golden/baseline_db5b24e/` is the capture from `claude/recency` at `db5b24e`: PR #96
(recency, below) merged with main after #105–#109. It takes in three behaviour changes that
reached main tonight without a baseline of their own, so main's golden check was red between
#108 and this merge (Michael merged them for playtesting):
- #108, playtest 1709 fixes: one accusation per speaker per target per meeting (fewer
  testimony draws), the silenced give no greeting, the ward/sigil showing frees the floor,
  and reworded reasons ("doesn't fit the facts as I know them", the Surveyor's off-block
  line) that change reply text.
- #109, NPC chatter: per-slot conversation rolls, yesterday's talk at the tavern, the
  one-roll gift disclosure in NPC talk and the day-1 confidant. These change world RNG use
  from the first morning, so 54875, 692 and 98933 differ from the meta record on.
- #105 (demon types step 1) changed nothing (share 0).

Against `baseline_9a09894` (recency alone): 42 parts at record 41, 900 at record 2, the
other three at the meta record. Record counts: 42 142, 54875 254, 692 250, 900 169, 98933
275. Two captures identical.

### Previous baseline (Nov 8, recency, branch only): `baseline_9a09894`

Removed: it never reached main (superseded by `baseline_db5b24e` above).

`tools/golden/baseline_9a09894/` is the capture from `claude/recency` at `9a09894` (PR #96,
on main `7017a98`): recency in bounded attention (card age fade, topic of the day, recall
on presentation, and NPCs' spoken reasons recalling their cards), the headline blend
scaled by strength, a dawn refresh of every living mind, and the topic halving from its
capped value (`docs/premises_plan.md`, "Recency as built"). This is meant to change
behaviour, and it does from day 1: cards from night 0 are a day old by the first refresh,
so bounded minds rank their leftover attention differently. Against `baseline_7034f36`,
900 parts at record 1 (greta on odette, 0.1933 → 0.1926), 692 at record 5 (merrin on
nisha, 0.067 → −0.031, an attention swap), 54875 and 98933 at record 16, and 42 at record
21, the first dawn refresh (a new record). Record counts: 42 111 → 142, 54875 267 → 265,
692 312 → 288, 900 133 → 131, 98933 229 → 186. Against the branch's own earlier
`baseline_06d26bf` (never on main, removed, as is `baseline_b157258`), the NPC recall
first shows at the day-1 meeting (900 record 22: a cited card moves up Constance's
attention order). Two captures identical.

### Previous baseline (Nov 7, bare defences ungraded): `baseline_7034f36`

`tools/golden/baseline_7034f36/` is the capture from `7034f36`. An NPC's defence with no grounds is
no longer put through step 3's graded test (decided with Michael). A behaviour change, but a
small one: every seed parts from `baseline_5ba1d64` at its first stored bare challenge, which
has no `graded` result now. Ignoring `graded`, the first belief differences are about 4e-5 in
suspicion, from day 1 or 2's refreshes. Seed 54875 records 267 records instead of 286. The final
results are unchanged. Two captures identical.

### Previous baseline (Nov 7, step 3 speed): `baseline_5ba1d64`

`tools/golden/baseline_5ba1d64/` is the capture from `5ba1d64`: `baseline_4e54261` with graded
challenges no longer running two of their three evaluations (the source's prior comes from the
holds evaluation; the cause isn't weighed when the effect is zero). The games are the same:
ignoring the `graded` diagnostics, every value matches `baseline_4e54261` within 1e-9 and every
seed has the same records (`--ignore engine,graded --tol 1e-9`). At `--tol 0` they part at the
first stored challenge: `graded.cause` and `evil_share` are 0 where the effect is 0, and r,
`wrong` and the agreements differ in the last digits (1e-15). Two captures identical.

### Previous baseline (Nov 6, night, PR #95): `baseline_4e54261`

`tools/golden/baseline_4e54261/` is the capture from `4e54261`. It replaces Quill's
`baseline_858495d` (never on main; removed) after Bailiff's step 3 review fixes: "the
reading's content holds" is now content only, whoever the source is, so the graded test no
longer counts the source's goodness twice. Same divergence points from `baseline_50bd642`
as below (every seed at the first meeting's refresh, about 1e-4 in suspicion); against
`858495d` the values differ by 1e-5 to 1e-4 from the same records. Two captures identical.

Quill's description of `858495d`, which still holds for the shape of the change: the capture is `baseline_50bd642` plus the
premises pass steps 1–3 (Bailiff's review fixes included). The passive golden player never
presents a case, so steps 1 and 2 left it identical; step 3 does not: NPC bare defences ("X
is lying") have no grounds and a 5% hearing weight, and are now graded on each listener's
attended evidence, so they can land very slightly (as planned for step 0). Every seed parts
at the first meeting's refresh by about 1e-4 in suspicion (42 at record 48, 54875 at 27, 692
at 36, 900 at 52, 98933 at 23); 54875 now runs to 286 records (was 267). Two captures
identical.

Passive A/B: for Tally (the step 1–3 A/B rows).

### Previous baseline (Nov 6, early): `baseline_50bd642`

`tools/golden/baseline_50bd642/` is the capture from `50bd642`: `baseline_55cea76` plus the
premises pass, step 0b (one attended set for presentations: salience by the premise's
target, the listener's own readings pinned, the trust reward judged on the case and own
readings; the belief update's focus target follows alignment premises only). Main's M4 bot
and tooling fixes are in it too; they're sim-neutral. Two captures identical. Seeds 42 and
54875 are unchanged; 692, 900 and 98933 part on Day 2 (records 82, 39 and 104), at the
first refresh after a presentation's attention changes.

Passive A/B: not run separately for 0b (the Codex game fixes stack on it the same night;
the next entry's A/B covers both against `baseline_55cea76`'s commit).

### Previous baseline (Nov 6): `baseline_55cea76`

`tools/golden/baseline_55cea76/` is the capture from `55cea76`: `baseline_a64553d` plus the
premises pass, step 0. A bare defence now cites no grounds, so it no longer turns bounded
listeners into full-attention ones. Two captures identical. Every seed parts at the first
refresh after a nominee's defence (record 27 to 52, Day 1 or 2 evening).

Passive A/B, seeds 2000-2011, 12 games per cell, Default script:

| Cell | Good wins (main → new) | Good hanged | Evil hanged |
|---|---|---|---|
| 7 NPCs | 4 → 4 | 12 → 13 | 6 → 5 |
| 10 NPCs | 3 → 1 | 17 → 20 | 21 → 15 |

Within noise, but the direction is plausible. Before the fix, every defence quietly made
its listeners full-attention reasoners, so the town was sharper than its Insight budgets
say. Restoring the budgets makes it a little worse at finding evil.

### Previous baseline (Nov 5, late night): `baseline_a64553d`

`tools/golden/baseline_a64553d/` is the capture from `a64553d`: `baseline_7a96d27` (NPC openness, M2c) plus
meeting plan M2d:
- the player's turn after the town;
- beliefs flushed before the vote;
- recorded voter parts;
- vote resistance lines.

Two captures identical. Against `baseline_7a96d27` every seed parts at the first nomination
(the new prompt text). With `--ignore engine,voter_parts,prev_block,prev_block_count,reply,text,statement,said`
they part at the first vote that the pre-vote flush moves (day 2-3).

### Previous baseline (Nov 6): `baseline_7a96d27`

`tools/golden/baseline_7a96d27/` is the capture from `7a96d27`: `baseline_a9e0301` (M2c) plus NPCs being more open with each other. Chats pass on up to three
things; readings go far more readily to trusted listeners; hints and claims reach
acquaintances; the dead's private readings get passed on and told at the meeting. Two
captures identical. Every seed parts from `baseline_a9e0301` early, at the first NPC conversations. (The
branch alone, before M2c, was captured as `9379b1e`; the A/B below is from it.)

Passive A/B, seeds 2000-2011, 12 games per cell, Default script:

| Cell | Good wins (main → new) | Good hanged | Evil hanged | NPC shares |
|---|---|---|---|---|
| 7 NPCs | 4 → 3 | 10 → 12 | 9 → 7 | 133 → 228 |
| 10 NPCs | 5 → 3 | 14 → 18 | 20 → 17 | 460 → 633 |

Within noise for 12 games, but both cells lean the same way. Share mix at 10 NPCs, per game
(main → new): readings 2.2 → 4.1, role hints 1.0 → 2.7, claims 0.8 → 1.5, relayed readings
0 → 0.6, meeting relays of the dead's readings 0 → 0.08.

### Previous baseline (Nov 5, late night): `baseline_a9e0301`

`tools/golden/baseline_a9e0301/` is the capture from `a9e0301`: `baseline_b9a0376` plus
meeting plan M2c (supporters, `sim/mind_support.gd`). Two captures identical. Against
`baseline_b9a0376` every seed parts at the vote of a nomination where a supporter spoke
(day 1 to 3); earlier records are identical.

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
python3 tools/golden_diff.py tools/golden/baseline_db5b24e /abs/candidate
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
