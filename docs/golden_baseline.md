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

### Current baseline (Nov 19, private sharing grows each day): `baseline_851e676`

`tools/golden/baseline_851e676/` is the capture from `claude/beadle-private-share` at `851e676`
(main with #344 merged in). An NPC who hasn't claimed a gift publicly
brings up its gift and its readings in private talk a little more often each day past day 1
(`SHARE_UNCLAIMED_DAY_BOOST` 0.15, new, pending Michael).
- **Divergence from `baseline_ee15238`:** 98933 from record 81 (day 2, the first private-talk
  draw of the day); 42, 54875, 692 and 900 are identical.
- **Outcomes:**
  - **98933:** main hangs Dorian on day 2 and Isolde on day 3. Now it hangs Merrin on day 2,
    with no winner by day 4 either way.
  - **42, 54875, 692 and 900:** unchanged.

### Earlier baseline (Nov 19, movement factor handles on their own scale, #344): `baseline_ee15238`

`tools/golden/baseline_ee15238/` is the capture from `claude/factor-norm-handles` at `ee15238`
(main with #345 merged in). A movement factor's compiled handle is now shared only between uses
scored on the same scale. Before, a mixed Night Watch list's broken branch could share a handle
with an identical factor used on its own and rewrite that factor's scale; the last mix to attach
decided how it scored.
- **Divergence from `baseline_2ac19a1`:** seed 42 only, in 2 values at rounding level (the
  first at record 67, Fenwick's raw posterior on Kiran: 0.07560079988852052 to
  0.07560079988852055). That's one such collision on main, between two scales that differed only
  in the last digit. The other four seeds are identical, and seed 42 matches at `--tol 1e-12`.
- **Outcomes:** all five unchanged.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 19, Argon's single end-of-night belief flush, #289): `baseline_2ac19a1`

`tools/golden/baseline_2ac19a1/` is the capture from `claude/nice-mayer-naok85` at `2ac19a1`
(Argon's `argon/dawn-belief-flush` at `72be00b` with main `7d9246f` merged in, by Bailiff on
Seneschal's instruction, Nov 19). The night's belief refreshes are consolidated into a single
flush at the end of the night, so each NPC refreshes fewer times. The values move only slightly
in each refresh that remains.
- **Divergence from `baseline_2829999`:** every seed, at the first night's refreshes (42 at
  record 9, 54875 at 56, 692 at 166, 900 at 17, 98933 at 55). There are fewer refresh records
  (69 to 64, 301 to 293, 250 to 245, 138 to 132, 253 to 245), and belief values differ in the
  third or fourth decimal place.
- **Outcomes:** all five unchanged: the same hangings on the same days, the same nominators and
  voters, and the same winner.
- **Stability:** two captures were identical, with engine fields included.

### Earlier baseline (Nov 19, "their readings agree with what I know"): `baseline_2829999`

`tools/golden/baseline_2829999/` is the capture from `claude/beadle-readings-agree` at `2829999`
(main with #319 merged in). A good listener whose record holds a moderate or known
confirmation of someone's readings gives it as its reason, in a vote against them or asked its
opinion of them, with a card citing the confirmed reading. Wording only: no suspicion moves.
- **Divergence from `baseline_8d946e7`:** 54875, 692 and 98933 at day 2's vote, where a no-voter
  gives the new reason; 42 and 900 are identical.
- **Outcomes:** all five unchanged.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 19, trust from readings that confirm): `baseline_8d946e7`

`tools/golden/baseline_8d946e7/` is the capture from `claude/beadle-reading-trust` at `8d946e7`
(main with #320 merged in). The trust a confirming reading earns counts in the same refresh's
solve (Bailiff's `test_workshop_action` catch), so it takes effect one refresh sooner than in
the earlier captures of this branch. A good listener gains trust in a teller whose reading
confirms what it knows or strongly believes (small 0.06, moderate 0.12, known 0.20), once per
reading by its logical origin. The agreement step from #292 becomes 0.02 (Michael, Nov 19, set
R3). The record of confirmations is kept in `workshop_state`.
- **Divergence from `baseline_6569929`:** every seed, from record 1 (the record's place in each
  NPC's `workshop_state`, and the first day's refreshes judging the night-0 readings).
- **Outcomes:**
  - **42, 692 and 900:** unchanged.
  - **54875:** hanged Edda on day 3 with no winner by day 4. Now it hangs Edda on day 2 and
    Hollis on day 3, still with no winner by day 4.
  - **98933:** good won on day 2, hanging Odette. Now it hangs Dorian on day 2 and Isolde on
    day 3, with no winner by day 4.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 19, self-doubt from the judge): `baseline_6569929`

`tools/golden/baseline_6569929/` is the capture from `claude/self-doubt-posterior` at `6569929`
(main `aef2ff9` merged in). A good NPC's self-doubt is now the judge's chance each night's own
reading was wrong (`OwnGiftDoubt`), computed when first read rather than stored; the poison and
Delusional prior that `workshop_state.self_doubt` used to hold is stored as
`workshop_state.self_doubt_prior`.
- **Divergence from `baseline_659996a`:** every seed from record 1, only in those stored fields
  (`self_doubt` gone, `self_doubt_prior` added). With `--ignore engine,self_doubt,self_doubt_prior`
  all five seeds are identical: no belief, vote, nomination or execution moves, since nothing in
  play reads self-doubt yet.
- **Outcomes unchanged:** the same executions, nominators, winners and record counts on every
  seed.

### Earlier baseline (Nov 19, "Demon" capitalised in player-facing text): `baseline_659996a`

`tools/golden/baseline_659996a/` is the capture from `claude/herald-hanged-refusals` (#312) at
`659996a` (main `05d81a3` merged in). Michael approved capitalising "Demon" throughout (Nov 19):
"the demon" becomes "the Demon" in readings, role descriptions, filed-case text, endings, logs and
dialogue. #312 also carries Michael's two hanged-Demon refusal lines, which golden doesn't reach.
- **Text only:** every record is identical to `baseline_d6a93f1` once case is ignored, on all five
  seeds. No belief, vote or outcome moves, and the record counts are the same.
- **First text difference:** 42 and 900 at record 1 (a Seer reading's text), 54875 and 98933 at
  record 54, and 692 at record 25 (the evening reply).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 19, meetings feed the gossip network): `baseline_d6a93f1`

`tools/golden/baseline_d6a93f1/` is the capture from `claude/beadle-evil-confer` at `d6a93f1`
(main `8801906` merged in). Those at the place where two people talked after the player had
gone see it. A witness passes on a meeting in conversation, and asked about either person an
NPC reports it, first or second hand (BACKLOG item 3, Michael, Nov 18-19). The pairing itself is
unchanged.
- **Divergence from `baseline_22733aa`:**
  - 54875 from record 84 (day 2: a meeting seen after the player had gone);
  - 692 from record 40 (Bart's refresh on day 2, after hearing of a meeting);
  - 98933 from record 82 (Dorian's refresh on day 2);
  - 42 and 900 are identical.
- **Outcomes:**
  - **692:** hanged Constance on day 3; now also hangs Greta on day 2. No winner by day 4.
  - **42, 54875, 900 and 98933:** unchanged.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 19, a Warden's guard read with its night): `baseline_22733aa`

`tools/golden/baseline_22733aa/` is the capture from `claude/warden-night-item` at `22733aa`
(main `0670ba8` merged in). A Warden's guard report now sits in its night's movement item with
that night's sightings and alibis (`Connections.NIGHT_ROLES`), so a quiet-night guard is weighed
together with who was seen near the guarded door, instead of alone.
- **Divergence from `baseline_74eb971`:** 692 from record 32 (Nisha's refresh on day 2, the
  first refresh that holds a Warden's guard). 42, 54875, 900 and 98933 are identical.
- **Outcomes:** 692 hangs the same person, Constance, on day 3, with the same eight yes votes.
  Nisha now nominates her instead of Fenwick. It still reaches day 4 with no winner, in 249
  records (was 251). Every other seed is unchanged.
- **Stability:** two captures were identical. The same divergence and outcome as this branch's
  earlier captures on older mains (`baseline_e1d1934`, `baseline_3710796`, never on main).

### Earlier baseline (Nov 19, backing a case builds trust): `baseline_74eb971`

`tools/golden/baseline_74eb971/` is the capture from `claude/beadle-agreement-trust` at `74eb971`
(main `4248293` merged in, with #296). A good NPC warms a little to those who vote
the same way, and to someone who nominates or accuses a person it already suspects (Michael,
Nov 18). The reading steps were taken out on Nov 19 and moved to their own item, so readings
change no trust here. It replaces this PR's earlier `baseline_6c45840`, which was on main before
#296; against it, only 98933 moves (from its day-2 nomination, under #296's retuned lie call),
with the same outcome.
- **Divergence from `baseline_21df80d`:** every seed, at the first ballot or the refresh after
  it. 54875 and 98933 from record 52 (day 1's vote), 42 from 55 and 900 from 74 (day 2's vote),
  692 from 62 (Nisha's refresh on day 2).
- **Outcomes:**
  - **42:** unchanged (good on day 3, hanging Agnes).
  - **692:** unchanged (Constance hanged on day 3, no winner by day 4).
  - **900:** unchanged (Lian hanged on day 3, no winner by day 4).
  - **54875:** hanged Greta on day 2 and Edda on day 3; now hangs only Edda, on day 3.
  - **98933:** hanged Dorian on day 2 and Isolde on day 3; now good wins on day 2, hanging Odette.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, the Mistaken label): `baseline_21df80d`

`tools/golden/baseline_21df80d/` is the capture from `claude/honest-mistake` at `21df80d`
(main `678838f`). "misled" and "failed gift" become one honest-mistake label, Mistaken, and a
lie call's gate and floor are retuned so it moves suspicion.
- **Divergence from `baseline_e287b3d`:**
  - 98933 from record 147, 900 from record 138 and 54875 from record 295. Each is only the
    stored mode of an NPC's "misled" defence challenge, now "impaired", the merged mode's
    code name.
  - 42 and 692 are identical.
  - With `--ignore engine,mode`, all five seeds are identical, so no belief, vote or
    execution moves. Nothing in an autoplay game makes a player lie call.
- **Outcomes unchanged:** the same executions, nominators, winners and record counts on every
  seed.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, a Night Watch list sound or broken as a whole): `baseline_e287b3d`

`tools/golden/baseline_e287b3d/` is the capture from `claude/nightwatch-whole-list` at `e287b3d`
(main `0670d55`). Another's Night Watch list is mixed as sound (each name at its small error)
or broken (it says nothing about who walked), with the watcher's poison and Delusional priors as
the broken chance. A list wrongly naming the listener is kept instead of set aside.
- **Divergence from `baseline_96e729f`:**
  - 692 and 98933 from record 1 (the first day's beliefs: small shifts wherever a Night Watch
    list is held).
  - 54875 from record 13 (Dorian's refresh on day 1).
  - 42 from record 61 (Fenwick's refresh on day 2).
  - 900 is identical.
- **Outcomes unchanged:**
  - The same executions, nominators and winners on every seed: 42 good on day 3; 54875, 692,
    900 and 98933 reach day 4 with no winner.
  - Record counts are the same except 54875 (345, was 352) and 98933 (291, was 307).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, bluffers blend in or disrupt by evil type): `baseline_96e729f`

`tools/golden/baseline_96e729f/` is the capture from `claude/beadle-bluff-blend` (#269) at `96e729f`
(main `c4f5dc6` merged in): the Rumormonger, Clerk, Martyr, Gravedigger, Executor and Confessor
bluffs choose by evil type (Michael, Nov 18), with new rolls on the first night.
- **Divergence from `baseline_a3fd022`:** 54875, 692, 900 and 98933 from record 0 (the world's
  random state after the first night's fabrications). 42 is identical.
- **Outcomes:**
  - **42:** unchanged (good on day 3).
  - **54875:** was good on day 2 after hanging Constance. Now day 4 with no winner, after
    hanging Greta on day 2 and Edda on day 3.
  - **692:** hangs only Constance, on day 3. Merrin is no longer hanged on day 2.
  - **900:** hangs Lian on day 3, not Constance on day 2.
  - **98933:** now hangs Dorian on day 2 and Isolde on day 3 (none before).
  - Every seed but 42 reaches day 4.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, premise centring B): `baseline_a3fd022`

`tools/golden/baseline_a3fd022/` is the capture from `claude/premise-centre-b` (#246) at `a3fd022`
(main `2430ea5` merged in). An item a case brings is judged against what the listener already
held of it, so only what it adds by itself is centred on the case's premise. A stored case
carries every person it argues about.
- **Divergence from `baseline_1dd16d5`:**
  - 42 from record 40 (Kiran's refresh on day 2).
  - 692 from record 30 (Constance's cover on day 1).
  - 900 from record 126 (Isolde's cover on day 2).
  - 98933 from record 155 (Merrin's refresh on day 2).
  - 54875 is identical.
- **Outcomes:**
  - The executions and winners are the same on every seed: 42 good on day 3, 54875 good on
    day 2, and 692, 900 and 98933 reach day 4 with no winner.
  - On 692, Bart rather than Nisha now nominates Constance for her hanging on day 3.
  - Record counts are the same except 692 (296, was 277) and 98933 (387, was 386).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, eleven hint families): `baseline_1dd16d5`

`tools/golden/baseline_1dd16d5/` is the capture from `claude/hint-families` at `1dd16d5`
(main `92a247a` merged in): eleven hint families with deliberate overlaps, and a gift in
several families hints from the one with the most gifts on the script (`C.hint_package`).
- **Divergence from `baseline_45b7506`:** only which family a hint names, its wording and
  its role list. 692 from record 1 (Nisha hears a Medium's hint as night sight, not the
  dead) and 900 from record 5 (Kiran hears a Psychologist's hint as light against the
  dark, not reading people). With `--ignore engine,package,roles,text,reply,lines,statement`
  every seed is identical: no belief, vote or execution changes.
- **Outcomes:** all five unchanged; the end records are identical.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, "was my reading poisoned?"): `baseline_45b7506`

`tools/golden/baseline_45b7506/` is the capture from `claude/poison-self-doubt` (#232) at
`45b7506` (main `f947be6` merged in): with a Poisoner possible, each of a good listener's own
readings carries the chance a Poisoner picked it that night as an honest doubt (combined with
the Delusional self-doubt as independent chances), and the judge weighs the reading as genuine
or broken by fit.
- **Divergence from `baseline_1e6b846`:** beliefs from the first record on every seed (the first
  day's own readings carry the doubt).
- **Outcomes unchanged:** the same executions, nominators and winners on every seed (42 good
  day 3; 54875 good day 2; 692, 900 and 98933 reach day 4 with no winner). Record counts are the
  same except 54875 (201, was 225).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, "it's another of us"): `baseline_1e6b846`

`tools/golden/baseline_1e6b846/` is the capture from `claude/beadle-group-defence` (#249) at
`1e6b846` (main `23136f3` merged in): a nominee named by a reading over a group (a Dowser's count,
a Chronicler's three, a Surveyor's mixed street, a Medium's relay of one) says it's one of the
others, naming them when there are one or two and none is a teammate.
- **Divergence from `baseline_23d0330`:** 54875 from record 42 (Hollis's refresh on day 1) and
  692 from record 39 (Constance's cover on day 1): an owned defence that was a challenge is now
  the group defence ("rival"). 42, 900 and 98933 are identical.
- **Outcomes unchanged:** the same executions, nominators, votes and winners on every seed
  (54875 good on day 2; 692 reaches day 4 with no winner). Record counts are the same.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, a relayed sighting's only teller is its relayer): `baseline_23d0330`

`tools/golden/baseline_23d0330/` is the capture from `claude/relayer-in-contest` at `23d0330`
(main `b65b728` merged in): in the sighter contests a Medium's relay is contested only as the
relayer's word. The dead person never told it, so it can't have invented it; counting them
as a teller too let the two-sighter cap drop the relayer, and an evil Medium's invented relay
was weighed as the dead's honest word.
- **Divergence from `baseline_be621cd`:** 98933 only, from record 209 (Agnes's refresh on day
  2, after the good Medium Agnes's relays): beliefs move in the fourth decimal. 42, 54875,
  692 and 900 are identical.
- **Outcomes unchanged:** the same executions, nominators and winners on every seed. Record
  counts are the same.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, evil's lie reasons in plain words): `baseline_be621cd`

`tools/golden/baseline_be621cd/` is the capture from `claude/herald-lie-reasons` (#241) at
`be621cd` (main `040d115` merged in): evil's "think: lie" lines and fabrication reasons are
reworded for the reveal (names, roles, ordinal nights, "evil's scapegoat").
- **Divergence from `baseline_490cdcf`:** text only. 394 strings differ (the `why` of fake
  readings and sightings, and the lie lines), no number, list or other value. 42 and 900 are
  identical; 54875 differs from record 84, 692 from 82, 98933 from record 1.
- **Outcomes:** all unchanged (42 good day 3; 54875 good day 2; 692 and 900 reach day 4 with no
  winner, the same executions; 98933 reaches day 4 with no executions). Record counts unchanged.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, a good listener doubts its own Delusional gift): `baseline_490cdcf`

`tools/golden/baseline_490cdcf/` is the capture from `claude/delusional-self-doubt-2` (#216) at
`490cdcf` (main `f23566a` merged in): with Delusional on the script, a good listener that
could hold it gives each night of its own readings a small honest doubt
(`DELUSIONAL_SELF_DOUBT`, 10%), so its own gift's word softens a little, never as a charge
of lying.
- **Divergence from `baseline_58dac68`:** beliefs from the first record on every seed (the
  first day's own readings carry the doubt: a Lamplighter's, Night Watch's, Clerk's,
  Surveyor's or Seer's reading weighs about a tenth less to its holder).
- **Outcomes:** 42, 54875, 692 and 900 unchanged (42 good day 3; 54875 good day 2; 692 and 900
  reach day 4 with no winner, the same executions). **98933 changes:** the town no longer
  hangs Isolde (the Revenant, evil) on day 3; all five day-3 nominations fail, Nisha's of the
  Demon Odette at 3 of the 5 votes needed. It still reaches day 4 with no winner. Record
  counts are the same except 98933 (386, was 414).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, a "taken together" reason measured in the belief model): `baseline_58dac68`

`tools/golden/baseline_58dac68/` is the capture from `claude/joint-reasons-in-belief-model` at
`58dac68` (main `80f7605` merged in): reason attribution weighs a joint ("taken together")
reason by re-running the listener's own connections refresh without the card, so the reason
an NPC gives is what moved it in the belief model.
- **Divergence from `baseline_44073d9`:** reasons first, then what NPCs say and hear: 42 from
  record 77 (Fenwick's reason for Agnes, day 3), 54875 from 196 (Edda's reasons, day 2), 692
  from 38 (Nisha's suspicion, float noise at 1e-17, day 1), 900 from 116 (a few beliefs by
  about 0.2 points, day 2), 98933 from 117 (Lian's reasons, day 2). With the new measure's
  results thrown away but its refreshes still run, seeds 900 and 692 are identical to
  `baseline_44073d9`, so the change comes through the reasons, not a side effect. Record
  counts: 692 has 277 (was 266), 900 201 (was 202); the others are the same.
- **Outcomes unchanged:** the same executions, nominators and winners on every seed (42 good
  day 3; 54875 good day 2; 692, 900 and 98933 reach day 4 with no winner).
- **Stability:** two captures were identical, and identical to the capture before main was
  merged in.

### Earlier baseline (Nov 18, own home nights in the movement model): `baseline_44073d9`

`tools/golden/baseline_44073d9/` is the capture from `claude/own-night-knowledge` (#228) at
`44073d9` (main `65a41b4` merged in): a good listener's known home nights reach its movement
model as soft alibis, and the sighting contests take their balance from what an outsider
could know, so an invented sighting or relay of a home-staying listener counts against the
teller.
- **Divergence from `baseline_fdaccb0`:** beliefs only: 42 from record 9 (Isolde, day 1),
  54875 from record 65 (Odette, day 1), 692 from record 6 (Merrin, day 1), 900 from record 28
  (Constance, day 1), 98933 from record 85 (Lian, day 2).
- **Outcomes unchanged:** 42 good day 3; 54875 good day 2; 692, 900 and 98933 reach day 4 with
  no winner. Record counts are the same.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, bluff motives in plain words): `baseline_fdaccb0`

`tools/golden/baseline_fdaccb0/` is the capture from `claude/herald-bluff-motives` at
`fdaccb0` (main `5ef66da` merged in): every fabricated reading's recorded motive (`why`)
now reads in plain words, as Michael approved (Nov 17). "Whom evil meant to hang" replaces
"scapegoat", "a fellow evil" replaces "teammate", street and role names replace codes, days
are ordinals, and numbers the player never saw are gone.
- **Divergence from `baseline_e1f0fc2`:** text only, on every seed, all in `why` fields
  (1,148 strings). Record counts are the same.
- **Outcomes unchanged:** the same hangings, votes and nominators as `baseline_e1f0fc2`.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 18, the vigil watches who leaves): `baseline_e1f0fc2`

`tools/golden/baseline_e1f0fc2/` is the capture from `claude/vigil-leavers` at `e1f0fc2`
(main `eb74fad` merged in): the vigil sees residents leaving the watched block instead of
walkers arriving (Michael, Nov 17, `docs/design/vigil.md` option A), with Herald's wording.
- **Divergence from `baseline_823d388`:** text only, one string on every seed: the night
  prompt's help line, "'vigil <block>' (watch for activity arriving on a block)" is now
  "'vigil <block>' (watch who goes out from a block at night)". All five seeds diverge at
  the first night's prompt (42 record 6, 54875 61, 692 60, 900 23, 98933 71). With that
  string put back, all five are identical to `baseline_823d388` at `--tol 0`. Record counts
  are the same.
- **Why the rule itself doesn't move golden:** the passive golden player never keeps a
  vigil.
- **Outcomes unchanged:** the same hangings, votes and nominators as `baseline_823d388`.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, joint reasons measured within one model): `baseline_823d388`

`tools/golden/baseline_823d388/` is the capture from `claude/count-reading-reasons` (#204) at
`823d388` (main `c1e1b70` merged in): a "taken together" reason's weight is what removing its
card really changes, measured within the attribution's own model. Beliefs don't change; what
NPCs cite does, and so what they do with it.
- **Divergence from `baseline_89770fe`:** where a cited reason changes: 42 from record 77
  (day 3), 54875 from record 87 (day 2), 692 from record 83 (day 2), 900 from record 131
  (day 2 meeting), 98933 from record 99 (day 2).
- **Outcomes:** 42 good day 3, 54875 good day 2, 692 and 900 reach day 4 with no winner (all
  unchanged). **98933 changes:** good won on day 3; now play reaches day 4 with no winner.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, 89077 routing): `baseline_89770fe`

`tools/golden/baseline_89770fe/` is the capture from `claude/beadle-89077-routing` (#205) at
`89770fe` (main `f408a60` merged in): which answer a nominee gives. A sighting the nominator
already told the town now reaches the defence, a dead accuser is said to have "lied", the
"Then ... is lying" opener needs a line before it, and a gift's readings recap as one reason.
- **Divergence from `baseline_1f2e761`:** 42 (record 108, day 3) and 54875 (record 51, day 1)
  in spoken text only. 692 (record 111, day 2): Merrin answers Fenwick's sighting with where
  they were and "Fenwick lied" instead of a reading challenge, so listeners' beliefs about
  Merrin shift slightly and the record count changes. 900 (record 72, day 2): Constance's
  nomination keeps her told sighting for the defence, and Greta's line loses its "Then".
  98933 (record 60, day 1): Nisha's "made it up" line, with small belief shifts after it.
- **Outcomes unchanged:** same hangings, votes, nominators and deaths. 42 good day 3; 54875
  good day 2; 692 and 900 reach day 4 with no winner; 98933 good day 3.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, Insight's joining bar): `baseline_1f2e761`

`tools/golden/baseline_1f2e761/` is the capture from `claude/insight-core-bar` (#199) at
`1f2e761` (main `ae6637a` merged in): Insight sets how readily a card joins an NPC's core
(the joining bar runs from 0.8 for a dull NPC to 0.1 for a sharp one; it was 0.8 for all).
- **Divergence from `baseline_eb8e59b`:** beliefs only, where a sharper NPC's core now takes
  in a card a dull one wouldn't: 42 from record 35 (Isolde, day 2), 54875 from record 24
  (Greta's cover, day 1), 692 from record 17 (Fenwick, day 1), 900 from record 88 (Kiran,
  day 2), 98933 from record 14 (Odette's cover, day 1).
- **Outcomes unchanged:** 42 good day 3; 54875 good day 2; 692 and 900 reach day 4 with no
  winner; 98933 good day 3.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, bluff motives name people): `baseline_eb8e59b`

`tools/golden/baseline_eb8e59b/` is the capture from `claude/beadle-motive-names` at `eb8e59b`
(main `bf7b4f9` and #224 merged in): each fabrication's recorded motive (`why`) swaps
people's ids for their names (Steward A3).
- **Divergence from `baseline_5c99636`:** all 5 seeds, from record 1, in the `why` field
  only. Record counts are the same, and no other field differs.
- **Outcomes unchanged:** 42, 54875 and 98933 good wins as before; 692 and 900 unfinished
  as before. Same hangings, votes and nominators.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, 23973 wording): `baseline_5c99636`

`tools/golden/baseline_5c99636/` is the capture from `claude/herald-23973-wording` at
`5c99636` (main `f754421` merged in): playtest 23973's wording. Of what it changes, only
Nisha's agreement line reaches these games: "My own model aligns with {accuser} regarding
{target}" is now "My own reckoning agrees with {accuser} about {target}".
- **Divergence from `baseline_3ef0e2f`:** text only, 3 strings, all that line: 692 from
  record 189 (day 3 meeting) and 98933 from record 117 (day 2 meeting). Record counts are
  the same. 42, 54875 and 900: identical.
- **Outcomes unchanged:** the same hangings, votes and nominators as `baseline_3ef0e2f`.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, 89077 wording): `baseline_3ef0e2f`

`tools/golden/baseline_3ef0e2f/` is the capture from `claude/herald-89077-wording` at
`3ef0e2f` (main `ae6c304` merged in): playtest 89077's wording fixes. Nights are spoken as
ordinals (the Warden, the Medium, a home alibi for an earlier night), and a Lamplighter's
count given as a reason says "my count of folk abroad that night doesn't square with what
we've been told" instead of "...leaves them among the likeliest" (Michael, Nov 17).
- **Divergence from `baseline_f554c4a`:** text only, on two seeds; every changed field is a
  string (133 in all) and record counts are the same.
  - 692 from record 173 (day 3): Agnes's Medium reading, "...on the Docks on night 0" now
    "...the night before you arrived".
  - 98933 from record 134 (day 2): Bartholomew's nomination of Dorian gives the count line.
  - 42, 54875 and 900: identical.
- **Outcomes unchanged:** the same hangings, votes and nominators as `baseline_f554c4a`.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, lie severity): `baseline_f554c4a`

`tools/golden/baseline_f554c4a/` is the capture from `claude/lie-severity` at `f554c4a`
(main `317e040`, after #194, merged in): a good person's own "I was home" is no longer
certain (`Tuning.Workshop.GOOD_OWN_ALIBI_OUT` = 0.2, measured: 26% of good people who were
out told the player "home"), so being seen out after saying "home" is strong evidence, not
proof.
- **Divergence from `baseline_928cb8b`:** 42 (record 23), 54875 (record 1), 692 (record 2)
  and 98933 (record 9): suspicion shifts wherever someone's own "home" meets a sighting.
  900 is identical.
- **Outcomes:** 42, 692, 900 and 98933 unchanged (same hangings, votes and nominators).
  - **54875 changes:** Constance (the Demon) is hanged on day 2 (5 to 4, Jory nominates)
    and good wins that day. Before, Dorian, a good Archivist and a Sleepwalker, was hanged
    on day 2: Isolde (good Lamplighter) saw him out on the Docks the night Hollis died,
    and Dorian, who honestly believed he'd been home, said so. A good person's own "home"
    against a sighting was proof; it is now 1 chance in 5 of an honest mistake, so the town
    doesn't hang him on it and turns to Constance a day earlier.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, Delusional readings): `baseline_928cb8b`

`tools/golden/baseline_928cb8b/` is the capture from `claude/delusional-double-charge` at
`928cb8b` (main `730897c` merged in): in play a world where a reading's teller is the
Delusional holder no longer checks that reading's content in the role check (the
false-report likelihood already prices it), so "they were Delusional" stands beside "they
lied". The listener's own readings keep their check: nobody doubts what they read
themself (Bailiff's run of test_connections_pairings).
- **Divergence from `baseline_85e9b36`:** every seed from record 1. Delusional is a
  possible modifier on these scripts, so another teller's role-checked reading is a little
  less binding in the worlds where that teller could be Delusional: small shifts in
  suspicion from the first day.
- **Outcomes:** 42, 54875, 692 and 900 unchanged (same hangings, votes and nominators).
  - **98933 changes:** Isolde (the Revenant) hanged day 2, then Odette (the Demon) day 3,
    and good wins; before, Merrin, a good Surveyor with a Lovers secret, was hanged day 3
    and the case was open at day 4. On day 2 Merrin's Surveyor reading "doesn't fit the
    facts"; a Delusional Surveyor now explains part of that, so the nomination of her gets
    1 vote, not 4. Merrin owns her night out (meeting Hollis), and the town turns on
    Isolde, who had said she saw Merrin out where someone was killed. (My reading of the
    transcript, from the same change on an earlier base; the outcomes match.)
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17, latest): `baseline_85e9b36`

`tools/golden/baseline_85e9b36/` is the capture from `claude/beadle-better-lie` at
`85e9b36` (main `c676018` merged in): a liar who notices its fabrication would point the
town at itself or a teammate tells a better lie from its gift's own alternatives, and a
held reading is checked again on the day it would be told.
- **Divergence from `baseline_a0a378d`:** two seeds.
  - **54875, from record 179 (day 3, afternoon):** Constance, bluffing Dowser, would
    have given a count that lifts the town's suspicion of her by about 0.24. She says
    "on the Square I sensed 1 evil among Odette and Edda" instead (about 0.06).
  - **900, from record 143 (day 3, morning):** Isolde's held-back Gravedigger reading
    ("Constance, whom we hanged, was the Scion") is checked again before it's told. It
    would now lift her by about 0.9, and this time she doesn't notice, so it goes out.
- **Outcomes unchanged:** 42 (Agnes hanged day 3, good wins), 54875 (Dorian day 2,
  Constance day 3, good wins), 692 (Merrin day 2, Constance day 3, open at day 4), 900
  (Constance day 2, open at day 4), 98933 (Merrin day 3, open at day 4). Every hanging's
  vote counts are the same.
- **Stability:** two captures were identical, and identical to a capture taken before
  main `c676018` was merged in.

### Earlier baseline (Nov 17, later): `baseline_a0a378d`

`tools/golden/baseline_a0a378d/` is the capture from `claude/beadle-fabrication-check` at
`a0a378d` (main `45ebd82` merged in): evil fabrications are checked against the public
readings before they're told (`sim/fabrication_check.gd`).
- **Divergence from `baseline_1c9ac48`:** every seed from record 1, because each
  fabrication now carries its check (`vet`: the lift it would give the liar's team, and the
  outcome) in the evil member's and its shadow's readings. Only one fabrication in the five
  games is self-incriminating: on 900, Isolde (bluffing Gravedigger) would have said
  Constance, a good woman just hanged, was the Scion, which beside the public record lifts
  the town's suspicion of Isolde by about 0.8. She notices and holds it back a day.
- **Outcomes unchanged:** 42 (Agnes hanged day 3, good wins), 54875 (Dorian day 2,
  Constance day 3, good wins), 692 (Merrin day 2, Constance day 3, open at day 4), 900
  (Constance day 2, open at day 4), 98933 (Merrin day 3, open at day 4); every hanging's
  votes are the same.
- **Stability:** two captures were identical.

### Earlier baseline (Nov 17): `baseline_1c9ac48`

`tools/golden/baseline_1c9ac48/` is the capture from `claude/martyr-alternatives` at
`1c9ac48`: a Martyr's public promise followed by the chosen's hanging, with the Martyr
still standing, is now read by the judge (the chosen evil or Marked, or the promise false).
- **Divergence from `baseline_bb6f01c`:** only 692, from record 244 (Hollis's cover, day 3
  night). Hollis, an evil Martyr bluff, promised his teammate Constance, and Constance was
  hanged on day 3 with Hollis alive, so every mind's reading of Constance and Hollis moves
  a little (Constance up about 0.02 for Hollis's cover).
- **Outcomes unchanged:** 692 still hangs Merrin (day 2) and Constance (day 3) and reaches
  day 4; 42, 54875, 900 and 98933 are identical.
- **Stability:** two captures were identical.
- **Re-checked on main `cd3aeb4`** (after Argon's #181, merged into the branch): two fresh captures identical to each other and to this baseline, so it stands unchanged.

### Earlier baseline (Nov 16, later): `baseline_bb6f01c`

`tools/golden/baseline_bb6f01c/` is the capture from `claude/triage-nov16` (#162): the
approach interstitial (2.8/8.3), the "+N people there" note on far sightings (8.2), and a
Lovers confession proving the partner (5.9).
- **Divergence from `baseline_a713ca5`:** text only on 42, 54875, 692 and 98933 (the
  sighting note on the board, the approach passage in replies); outcomes unchanged.
- **900 changes outcome:** Greta and Jory are the Lovers. A confession by one now proves the other
  too, so neither is hanged: Constance is hanged day 2 and play reaches day 4 (was: Greta
  and Jory hanged, evil wins day 3).
- **Stability:** two captures were identical.

### Earlier baseline (Nov 16): `baseline_a713ca5`

`tools/golden/baseline_a713ca5/` is the capture from `claude/triage-behaviour` (#160): the
connections belief model on by default (`Tuning.Workshop.CONNECTIONS`), plus the playtest
triage behaviour batch (3.1-3.6, 3.8, section 6's Dowser bluff, 7.1 the Warden on night 0).
- **Divergence from `baseline_b281427`:** every seed from its first refresh (record 1; 692 at
  its meta record), as every mind now carries `workshop_state.connections`. Outcomes at the
  capture's end:
  - 42: unchanged (Agnes hanged day 3, good wins);
  - 54875: Dorian hanged day 2 instead of Edda, Constance day 3, good wins;
  - 692: Merrin and Constance hanged, play reaches day 4 (was: good wins day 3);
  - 900: Greta and Jory hanged, evil wins day 3 (was: open at day 4);
  - 98933: only Merrin hanged (day 3), open at day 4.
- **Stability:** two captures were identical.

### Previous baseline (Nov 13): `baseline_b281427`

`tools/golden/baseline_b281427/` is the capture from `claude/talk-sightings` (triage 1.7). A
conversation the player sees now also gives each talker their own sighting card (merged with
any sighting already held for them there). Player board only.
- **Divergence from `baseline_4a1a075`:** board length and card tags in every seed (42 at
  record 21, 54875, 692 and 900 at record 1, 98933 at record 4). Nothing outside `board` and
  `reply` changed in any record; record counts and outcomes are unchanged.
- **Stability:** two captures were identical.

### Previous baseline (Nov 13): `baseline_4a1a075`

`tools/golden/baseline_4a1a075/` is the capture from `claude/playtest-fixes` (playtest triage
sections 1 and 2). Two kinds of change:
- **Play:** a Lover no longer passes on their partner's secret, which names them too. In 98933
  Merrin's only gossip was Hollis's "slips out to meet Merrin", so on day 1 afternoon
  Bartholomew approaches instead of Merrin.
- **Text only:** reading-based reason lines say why (`ReasonAttribution` joint lines, the
  off-block Surveyor line), the defence hinge lines, Hollis's and Nisha's "premises" wording.
- **Divergence from `baseline_6a22cac`:** 98933 at record 4 (the approach); 42 at record 40,
  54875 at 186, 692 at 52 and 900 at 62, all reason or speech text. Record counts and
  outcomes are unchanged.
- **Stability:** two captures were identical.

### Previous baseline (Nov 12): `baseline_6a22cac`

`tools/golden/baseline_6a22cac/` is the capture from `claude/relay-bluff`. In play a held Medium
relay no longer proves its relayer is a good Medium (RoleConstraints): a world with the relayer
evil stays possible and the relay is their bluff. A relayed self-sighting is kept, as plain
ones are since #139.
- **Divergence from `baseline_300fe18`:** 42 at record 76 (refresh #57, Kiran, day 3
  evening) and 98933 at record 285 (refresh #251, Nisha, day 3 evening); the other three
  seeds are identical. Both outcomes are unchanged.
- **Record counts:** 98933 334 (was 346); the rest unchanged.
- **Stability:** two captures were identical.

### Older baseline (Nov 12): `baseline_300fe18`

`tools/golden/baseline_300fe18/` is the capture from `claude/self-sighting-clash`. A good NPC's
plain sighting of themselves on a night they know they spent at home is kept in the weighing
(it was rejected), so it counts against the sighter; with the Sleepwalker on the script the
listener's own home nights carry a 10% doubt. Night Watch lists and Medium relays are still
set aside.
- **Divergence from `baseline_f40ca05`:** 42 at record 31 (refresh #20, Nisha, day 2 evening:
  Agnes +0.05); the other four seeds are identical. The outcome of 42 is unchanged.
- **Record counts:** unchanged.
- **Stability:** two captures were identical.

### Previous baseline (Nov 11): `baseline_f40ca05`

`tools/golden/baseline_f40ca05/` is the capture from `claude/gravedigger-bluff`. An evil
Gravedigger's report on a hanged good person reads the town's certainty from the hanging vote
and calls them a Minion more often the surer the town was (one extra evil decision roll).
- **Divergence from `baseline_bd1b404`:** 900 at record 91 (refresh #73, Isolde's cover mind,
  day 2 night); the other four seeds are identical. Counting the player's no vote in the
  town's certainty (Codex's review) moved only 900 again, from record 97.
- **Record counts:** 900 138 (was 143); the rest unchanged.
- **Stability:** two captures were identical.

### Previous baseline (Nov 11): `baseline_bd1b404`

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

### Older baseline (Nov 10): `baseline_a03bf72`

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
