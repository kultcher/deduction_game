# The Seer looks for the likeliest Demon (Lantern's DemonCandidates)

- **Agent:** Claude-Beadle
- **Base:** main at `78e82991` (`baseline_14f5b7d`)
- **Branch:** `claude/beadle-seer-demon-candidates`
- **Status:** PR open. Golden moves on one seed (900), in word order only. Re-baselined here as
  `baseline_ebea777`.
- **Next actor:** Bailiff (review and merge). Lantern, for a read of the ranking.
- **Item:** Michael, Nov 21 (`docs/design/reading_interpretation.md` section 2.1): the Seer
  picks the most likely Demon, not just the most likely evil. Seneschal gave the go on Nov 23,
  once Burdens had landed.

## What changed

- **`seer.gd` `demon_ranked`:** the Seer ranks the living by its suspicion of each (its
  chance they're evil) times the joint judgement's chance they're the Demon if evil.
  - That chance comes from `DemonCandidates.given_evil_of_npc`, Lantern's, worked out from the
    NPC's last belief refresh. It costs one judgement per refresh, and only when a Seer picks.
  - A Minion it's sure of, whom its own readings put outside the Demon's seat, now ranks below
    someone it only half suspects.
  - Ties keep the suspicion order.
  - With no refresh staged (before the first one), it ranks by suspicion alone, as before.
- **Unchanged, as Michael set them:**
  - those its own "no" cleared go last;
  - a confirming read is 50/50 beside someone fresh or someone trusted;
  - it narrows a "yes" only when its top suspect is one of the two;
  - the Red Herring response.
- **The `seer_pick` log entry** now records `by_demon`: whether the ranking had the judgement.

## Measured

- **20 passive 10-NPC games with a good Seer**, from seed 9000, played to day 5. Old and new
  rules used the same deals.

  | | Before | After |
  |---|---|---|
  | Seer readings | 56 | 61 |
  | Readings with the Demon in the pair | 16 | 20 |
  | Seers who ever read the Demon | 12 of 20 | 13 of 20 |
  | First night with the Demon (mean) | 1.08 | 1.00 |
  | Seers with two or more "yes" on the Demon | 3 | 4 |
  | Picks that used the judgement | 0 of 56 | 39 of 59 |

  The 20 picks without the judgement are first-night picks (random) and picks made before any
  refresh. A Seer now has the Demon in about one reading in three, up from about one in
  three and a half. It's a small sample.
- **Golden:** only seed 900 moves, at record 52 (day 2). Greta, the Seer, reads the same
  pair, but names Odette before Kiran: the new ranking put Odette higher. That flips the
  wording of her reading ("I looked at Odette and Kiran") in her ledger, the board and the
  public log. No suspicion value, vote or outcome changes. 42, 54875, 692 and 98933 are
  identical. Two captures were identical at `--tol 0`.
- **Tests:** `test_seer_targets` gains 2 checks: the Demon-first ranking, and the fallback with
  nothing staged. It passes, as do `test_demon_candidates` and the Seer suites on the CI lists.

## Proposed for the backlog

None.
