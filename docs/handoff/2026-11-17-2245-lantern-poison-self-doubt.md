# 2026-11-18, Claude-Lantern: "Was my reading poisoned?", the prior only (`claude/poison-self-doubt`)

- **Base:** main merged in (Nov 18). **Status:** PR #232, rebuilt per Michael's Nov 18
  decision; moves golden, re-baselines on its turn (after #228 and #216). **Next actor:**
  Quill reruns the 56-seed measurement before and after; Bailiff in queue order.
- **What Michael decided** (Nov 18, Lantern and Quill's recommendation): the prior only. Each
  of an NPC's own readings from a night a Poisoner could have acted carries the poison chance
  (Quill's `ReadingChallenges.poison_chance`, #223) as an honest doubt, in
  `SourceDoubt.derive` beside the Delusional self-doubt. The judge weighs the doubted reading
  by how well it fits the rest, so trust in a clashing teller enters on its own.
- **Why the first build was replaced:** it fed the judge π / (π + bad), a doubt already
  conditioned on the clash, so the clash counted twice (Quill's measurement: seed 51, a 25%
  doubt moved Constance 22% → 75%; the prior alone gives 54%). It also needed clash
  detection, an extra refresh and 11-31% more capture time. All of that is gone: nothing in
  the connections model, no rerun, no new number.
- **Kept:** `SourceDoubt.self_doubt(n)` (per-night own doubt, poison and Delusional) for
  Beadle's "my gift may have been turned" item; `SourceDoubt.poison_self_doubt` switch.
- **Measured** (`tools/test_poison_self_doubt.gd`, 8 checks, constructed on seed 692, Poisoner
  on the script, π = 5%): the doubt is π on the reading's night; a trusted teller's clashing
  card lets the own reading clear Hollis less (1.9% → 3.8%) and blame the teller less
  (40.7% → 40.0%); a suspected teller, slightly less; a teller who agrees, half as much; no
  Poisoner, none; a refresh with nothing new changes nothing.
- **Small calls:** the poison night is the reading's own night, or the night before for a day
  reading (Quill's convention); the doubt map key stays the reading's day (#216's keying);
  an accepted challenge on the same night shares the key (max, no stacking).
- **Backlog:** the item now records the revision.
- **Proofs under doubt (Michael, Nov 18, option b):** a doubted own reading drops its pin and
  the judge weighs it by fit, so strong frames can shake an own reading (seed 5: Odette's fake
  Night Watch report and Jory's fake Archivist reading take the hanged, good Constance from 0%
  to 90% for Agnes, on an 8% doubt). Weak contradicting evidence barely moves one. Quill's
  measurement: big moves go towards and away from the truth about equally. A proportional pin
  was tried (18b836d) and reverted on his decision.
- **With #216 merged in (Nov 18):**
  - **Small call made on Michael's behalf:** where a listener's own night carries both the
    poison chance and the Delusional self-doubt, they combine as independent chances,
    1 − (1 − poison)(1 − Delusional), as Michael set for the Night Watch's broken chance.
    Taking the larger alone would undercount a gift that can fail either way. With a 5%
    poison chance and the 10% Delusional doubt, an own reading is doubted 14.5%.
  - `test_poison_self_doubt` (10 checks) runs its poison-only checks with the Delusional
    doubt off, then checks the combination.
  - `test_role_check_doubt` pins the poison self-doubt off as well as the Delusional one:
    it compares a heard argument's doubt with none at all.
  - `test_own_night_knowledge`: the relay check is now in log-odds (at least what 15 points
    from even is). The fixture finder lands on seed 100031 with poison self-doubt on, where
    the relayer is already at 97% without the relay. On the earlier seed 100055 the relay
    lifts the relayer 74% → 99% with poison self-doubt on or off.
- **Codex on #232 (fixed):** a Medium's own transmissions carry the dead person as source and
  the Medium as relay, so the poison block skipped them. Now each night a good Medium heard
  the dead carries that night's poison chance, keyed as the relay's reliability is (the
  Delusional pass already did this). `test_poison_self_doubt` (12 checks) covers it; the old
  code fails the new check.
- **Codex on #232 (fixed):** a Registrar's night-0 register can't be poisoned
  (`sim/roles/registrar.gd`: only Delusional corrupts it), so it no longer carries the poison
  chance; it keeps any Delusional doubt, and the Registrar's later checks keep theirs.
  `test_poison_self_doubt` (13 checks) compares it with the same reading as a Dowser's night-0
  reading (5% against none).
- **Codex on #232 (fixed):** the poison night comes from the reading's phase. A night reading
  takes its own night; any reading by day, a Martyr's or Sexton's evening one included (their
  cards carry the coming night), takes the night before, whose poison still holds. The doubt
  stays keyed to the reading's own day. `test_poison_self_doubt` (14 checks): with a known
  Poisoner dead on day 2, a day-2 evening reading keeps night 1's 5% (night 2's would be 0).
- **Codex on #232 (fixed), narrowed with Quill:** a reading can't vouch for its own gift.
  `poison_chance` takes an own Gravedigger reading's role as known, so a poisoned one naming a
  hanged good person as the Poisoner ruled poison out for itself. That reading's own doubt is
  now asked without it. For the listener's other readings its word stands: that night only
  one person is poisoned, and a later poisoning needs the reading wrong as well, about as
  unlikely as the poisoning itself. `test_poison_self_doubt` (16 checks): the Gravedigger
  reading keeps 6.2% (0 before), and a later own reading carries none. No judge-side caller
  of `poison_chance` exists today (Quill), so nothing else changes.
- **Re-baselined (Nov 18):** main `f947be6` merged in (after #249). `baseline_45b7506`: beliefs move from the
  first record on every seed; outcomes are the same on all five (54875 has 201 records, was 225).
  Two captures identical; the fast list passed 111 of 111.
