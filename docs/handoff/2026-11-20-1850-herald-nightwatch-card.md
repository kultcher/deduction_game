# Herald: the Night Watch card says "I saw A and B out", and the Vigil tooltip drops "passing through"

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This closes the Night Watch half of the UI item "Movement wording: 'pass by' and 'road'". The voiced lines were #446. Michael approved this wording on Nov 20, via Seneschal. The town moves block to block, so nobody "passes by".

- **The Night Watch card** reads "I watched Mill Row: I saw Agnes and Bart out." With one name it reads "I saw Agnes out." The empty case is unchanged ("nobody stirred").
  - Before, it read "I watched Mill Row: I saw Agnes and Bart pass by".
  - Changed in `sim/roles/nightwatch.gd`, on the true card and both fabricated ones.
  - Changed in `sim/evil.gd`, where evil rewrites a card to name the scapegoat. Forged cards keep the same text as true ones.
- **The logged lie reason** for the scapegoat fabrication now says "watched the block of evil's scapegoat", not "the street of".
- **The Vigil tooltip** (`ui/term_defs.gd`) reads: "Vigil: you spend the night watching one block. You only see if its residents leave home. You do not see people arrive on this block from elsewhere."
  - The last two sentences are Michael's wording, exactly.
  - The text used to end "…; not those only passing through. An empty vigil means no one on that block left their home by normal means."
- **Comments and docs:** the `sim/tuning.gd` comment and DESIGN's matching quote now say "I saw X out", and `tuning_catalogue.md` is regenerated. BACKLOG's item is updated.
- **Tests:** sample card text in five suites (fixtures only, nothing checks the words) now matches.

## Small calls made on Michael's behalf
- **Kept the tooltip's first sentence,** "you spend the night watching one block", ahead of his two. "Its residents" needs the block named first.
- **Dropped "An empty vigil means no one on that block left their home by normal means".** His wording replaces the end of the tooltip. Say if he wants that sentence back.
- **Three or more names stay comma-joined,** as the world's name list already does ("I saw Agnes, Bart, Cora out"). Two names read "Agnes and Bart".

## Measured
- **Golden: moves, text only. Re-baselined to `baseline_d85bba3`.** Four seeds diverge at a Night Watch card's text, and 98933 also at the fabrication's logged reason. 900 is identical. With the same substitution applied to the old baseline, all five seeds are identical, and outcomes are unchanged. Two captures were identical.
- **Suites:** 13/13 pass: test_vigil_nightwatch, test_nightwatch_whole_list, test_nightwatch_bluff_teammates, test_term_defs, test_evil_owned_lie, test_evil_play, test_fabrication_check, test_social, test_conversation_nights, test_dialogue_voices, test_workshop_regressions, test_dialogue and test_text_terms.

## Proposed for the backlog
None.
