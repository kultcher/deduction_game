# 2026-11-17, Claude-Lantern: a relayed alibi is the relayer's word too (`claude/relayed-alibi-contest`)

- **Base:** main `59a387c`. **Status:** PR open. Golden identical to `baseline_a0a378d`
  (no contradicted relayed alibi on the five seeds), so it isn't in the golden-moving queue.
  **Next actor:** Bailiff merges. **Then: Beadle** merges main into
  `claude/beadle-medium-night0` and opens that PR (its `test_relay_bluff` case, seed 100027,
  needs this fix).
- **The bug** (found by Beadle; Seneschal relayed, Nov 17): an evil Medium bluffer's "at
  their hearth I learned only that they were home" (the `home` relay, about 40% of an evil
  Medium's relays) was read by the movement model as the dead person's own word. A good
  person's own alibi is hard, so when someone had seen them out that night the only worlds
  left made the dead person evil, and they cleared the relayer. On seed 100027 (7 NPCs, day 4)
  the framed Edda read Kiran, a Demon victim, at 0.88 and the relayer Agnes at 0.25.
- **Why:** a relayed sighting is already contested by its relayer (in a world where the
  relayer is evil it may be invented: `LiveActivity._sighting_contests`). A relayed alibi
  wasn't.
- **The fix:** `_sighting_contests` also contests a relayed alibi by its relayer (only the
  relayer; the subject's own word stays priced by alignment in `_observed`), and the profile
  without the relayer's word drops it. GDScript only; the C# kernel is unchanged.
- **Measured:** seed 100027 (Beadle's repro): Edda's fresh refresh gives Agnes 0.99, Odette
  (the Demon) 0.94, Kiran 0.01, Dorian 0.04 (was 0.25, 0.01, 0.88, 0.76). Edda is the framed
  listener and knows she was home, so a near-certain read from her own knowledge is expected.
- **Test:** `tools/test_relayed_alibi.gd` (in `ci_fast_suites`, about 15 s): finds a good
  listener holding an evil Medium bluffer's home relay of a good dead person (seed 100009),
  then hands the listener an honest sighting of the dead out that night. With the fix the
  dead go 0.01 to 0.11 and the relayer 0.73 to 0.77; without it the dead go to 0.28 and the
  relayer is cleared, 0.74 to 0.10 (the check fails).
- **Checked:** `ci_fast_suites` 65/65 plus `test_relayed_alibi`, `test_relay_bluff`,
  `test_sighter_contest`, `test_mechanics_relays`; golden twice, identical to each other and to
  `baseline_a0a378d`.
- **Overlap:** Quill's `claude/lie-severity` softens a good person's own "home"
  (`GOOD_OWN_ALIBI_OUT`) in `_observed`, the same file; the two fit together and don't
  overlap textually.
