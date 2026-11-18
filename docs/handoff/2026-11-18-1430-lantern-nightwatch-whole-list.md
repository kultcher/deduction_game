# 2026-11-18, Claude-Lantern: a Night Watch list is sound or broken as a whole (`claude/nightwatch-whole-list`; moves golden, baseline_cacd3d0)

- **Base:** main `0670d55`. **Status:** PR open. **Next:** Bailiff. Argon should look at the speed
  afterwards.
- **What and why:** BACKLOG "A Night Watch list that wrongly names the listener". Michael chose
  the whole-list model on Nov 18, with no new number:
  - A list is sound or broken as a whole.
  - The broken chance is the watcher's poison and Delusional priors.
  - The judge weighs sound against broken by fit, and a broken list clears nobody.
  - The void rule stays only on scripts with neither secret.
- **How:**
  - `SourceDoubt.list_broken_chance` gives the broken chance, 1 − (1 − poison)(1 − Delusional):
    the poison chance read with outings, and `DELUSIONAL_SELF_DOUBT` when Delusional is on the
    script.
  - `CaseEval._list_broken` stamps it on copies of another's Night Watch reports, and the
    compile key carries it.
  - `LiveActivity._list_mix` builds the movement factor with and without each list (up to two,
    latest nights first; `LIST_MIX_MAX`).
  - `LiveActivityKernel.ScoreMixed` (C#) scores (1 − b) × with + b × without in worlds where the
    watcher is good, and with-the-list where the watcher is evil, since the sighting contest
    already lets an evil teller say anything.
  - `Reasoner.direct_checks` and `SourceDoubt.derive` set the list aside and void its night only
    when the broken chance is zero.
  - Switch for tests: `SourceDoubt.list_mix_enabled`.
- **Measured on seed 692's deal** (`test_nightwatch_whole_list`, hand-built, broken chance 0.14):

  | Chance of being evil | No list | List wrongly naming the listener | Sound list |
  |---|---|---|---|
  | The watcher | 0.20 | 0.51 (0.20 under the old void) | |
  | The other named person | 0.33 | 0.34 | 0.42 |

- **Measured in played games:** seeds 100014–100076, 7 NPCs, day 3. Eight listeners named by an
  evil Night Watch on a night they were home. Same game state, switch off → on:

  | Seed | Watcher | Old rule → new model |
  |---|---|---|
  | 100014 | Kiran | 0.69 → 0.55 |
  | 100022 | Greta | 0.44 → 0.36 |
  | 100034 | Constance | 0.10 → 0.07 |
  | 100038 | Greta | 0.99 → 0.99 |
  | 100068 | Merrin | 0.50 → 0.35 |
  | 100069 | Lian | 0.09 → 0.08 |
  | 100074 | Hollis | 0.99 → 0.99 |
  | 100076 | Lian | 0.71 → 0.77 |

  - In game terms, a Night Watch caught "seeing" someone who was home is now partly excused as
    possibly poisoned or Delusional (about a 15% chance on these scripts). The old rule doubted
    all of the watcher's word at once.
  - So the listener suspects the lying watcher less than before in five of eight games, and as
    much or more in the other three.
  - These lists named only the listener, so the "other names" effect isn't in them.
- **Golden:**
  - 42, 54875, 692 and 98933 diverge; 900 is identical.
  - Executions, nominators and winners are the same on every seed. Two captures were identical.
  - Committed as `tools/golden/baseline_cacd3d0`.
- **Tests:**
  - Fast list 116/116, including the new `test_nightwatch_whole_list` (4 checks, about 4 s; added
    to the fast list).
  - `test_relay_bluff` 4/4.
- **Proposed for the backlog:** none.
