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
