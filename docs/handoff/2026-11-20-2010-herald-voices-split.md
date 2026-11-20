# Herald: one voice file per character (`sim/voices/`)

- **Agent:** Claude-Herald
- **Base:** main at `49e1530` (#415 merged)
- **Status:** PR open
- **Next actor:** Bailiff
- **Zero drift**

## What changed and why

This is the last of Argon's audit Tier 2 splits. #438 and #439 were the Workshop UI ones. `sim/dialogue_voices.gd` was a single 3,970-line table, and every wording PR edited it, so it waited on #415 and #446 to merge.

- **`sim/voices/<id>.gd`:** one file for each of the 15 characters, agnes to odette.
  - Each holds `const LINES`, that character's whole voice pack, moved verbatim.
  - Fenwick's file also holds `TARGET_EPITHETS`, which used to be `FENWICK_EPITHETS` at the top of the shared file.
- **`sim/dialogue_voices.gd`** now only assembles `VOICES` from those files, in cast order. Every caller still uses `Voices.VOICES`, so no caller changed.
- **Docs:** README's code map lists `sim/voices/`, and DIALOGUE_DESIGN's two references to where voice lines live now point at it.

**Adding a line from now on:** put it in each character's own file. `test_dialogue_voices` still checks that all fifteen carry the same keys.

## Measured

- **The assembled table is byte-identical** to the old one. I dumped `VOICES` from the old file and from the new one with `var_to_str` and compared: same content, same key order.
- **Golden:** identical at `--tol 0` on all five seeds (against `baseline_7005cc6`, on main at `49e1530`).
- **Suites:** 17/17 pass: every suite that reads the voices or the composer (test_day_conversation_view, test_daytime_defence_lines, test_dialogue, test_dialogue_decisions, test_dialogue_fixes_accusations_votes, test_dialogue_fixes_gossip_reasons, test_dialogue_fixes_testimony, test_dialogue_opinion_pass, test_dialogue_voices, test_npc_fixes_shifts_dead_haunt, test_playtest_89077, test_wording_23973 and test_workshop_regressions), plus test_text_terms, test_augur_wording and test_too_clean_bluffs.

## Proposed for the backlog
None.
