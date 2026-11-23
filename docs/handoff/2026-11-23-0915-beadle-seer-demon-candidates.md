# The Seer looks for the likeliest Demon (Lantern's DemonCandidates)

- **Agent:** Claude-Beadle
- **Base:** main at `78e82991` (`baseline_14f5b7d`)
- **Branch:** `claude/beadle-seer-demon-candidates`
- **Status:** PR open. Golden moves on one seed (900), in word order only. Re-baselined here as
  `baseline_ebea777`.
- **Next actor:** Bailiff (review and merge). Lantern reviewed the ranking; its accessor (#550) is merged in.
- **Item:** Michael, Nov 21 (`docs/design/reading_interpretation.md` section 2.1): the Seer
  picks the most likely Demon, not just the most likely evil. Seneschal gave the go on Nov 23,
  once Burdens had landed.

## What changed

- **`seer.gd` `demon_ranked`:** the Seer ranks the living by its chance each is the Demon:
  `DemonCandidates.demon_chances_of_npc` (Lantern, #550, merged in here). That's the NPC's own
  belief-model evil chance for each, from its last refresh, times the joint judgement's chance
  they're the Demon if evil, scaled to one Demon.
  - A Minion it's sure of, whom its own readings put outside the Demon's seat, ranks below
    someone it only half suspects.
  - Ties keep the suspicion order. With nothing staged (before the first refresh), it ranks by
    suspicion alone, as before.
  - **First version, replaced on Lantern's review:** suspicion × P(Demon | evil). Suspicion is
    a lean from the NPC's baseline, not an evil chance, and it zeroed out anyone at average.
- **The trusted confirmation partner** is the least suspected of evil (`ranked_suspects`), not
  the least likely Demon (Codex on #549). A Minion it's sure of is never its "trusted" partner.
- **Unchanged, as Michael set them:**
  - those its own "no" cleared go last;
  - a confirming read is 50/50 beside someone fresh or someone trusted;
  - it narrows a "yes" only when its top suspect is one of the two;
  - the Red Herring response.
- **The `seer_pick` log entry** records `by_demon`: whether the ranking had the judgement.

## Measured

- **50 passive 10-NPC games with a good Seer** (seeds from 9000 and from 9100), played to day 5.
  Old and new rules used the same deals.

  | | Before | After |
  |---|---|---|
  | Readings with the Demon in the pair | 44 of 144 (31%) | 41 of 152 (27%) |
  | Seers who ever read the Demon | 31 of 50 | 30 of 50 |
  | First night with the Demon (mean) | 1.00 | 1.07 |
  | Seers with two or more "yes" on the Demon | 10 | 7 |
  | Picks that used the judgement | 0 of 144 | 98 of 148 |

  **The Seer doesn't find the Demon more often.** If anything it does slightly less, but the
  gap is within what 50 games can't separate. The first version (suspicion × P(Demon | evil))
  looked better on the first 20 games (20 of 61 readings with the Demon), but it multiplied by
  the wrong thing, per Lantern. The picks without the judgement are first-night picks, which
  are random, and picks made before any refresh.
  What changes is whom it looks at: its likeliest Demon by its own beliefs, which is what
  Michael asked for, not a better hit rate.
- **Golden:** only seed 900 moves, at record 52 (day 2). Greta, the Seer, reads the same
  pair but names Odette before Kiran. That flips the wording of her reading in her ledger, the
  board and the public log. No suspicion value, vote or outcome changes. 42, 54875, 692 and
  98933 are identical. The capture is byte-identical between the first and final versions, and
  two captures of the final one were identical at `--tol 0`, so `baseline_ebea777` stands.
- **Tests:**
  - `test_seer_targets` gains 3 checks: the Demon-first ranking, the fallback, and the trusted
    partner. Its fixture clears any staged refresh, since its readings are written in by hand
    and no refresh has judged them.
  - `test_roles_night_sight` now takes the Seer's top suspect from its Demon ranking.
  - `test_shared_model`'s Day-4 smoke gains seeds 1007–1009 and 1011. Only three of its old
    seeds reached Day 4 with the new Seer.
  - CI is green on `fc897408`.

## Proposed for the backlog

None.
