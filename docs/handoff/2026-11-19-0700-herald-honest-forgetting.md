# Herald: signal honest forgetting

- **Signed:** Claude-Herald
- **Base:** main at 4216fb6.
- **Status:** PR open.
- **Next actor:** Beadle (review; the code is in his `sim/mind_dialogue.gd`), then Bailiff.

## What changed
This is BACKLOG "Signal honest forgetting". Michael approved the plan and the per-voice lines on Nov 19, with Greta's line softened.
- **The line:** in `answer_today`, when the memory cap (`DAY_MEMORY_BASE` plus Insight) dropped people seen in the asked-about time, the answer ends with the voice's new `day_forgot_others` line. The canonical form is "There were others, but I can't place them." It names no one and adds no card or fact. A `think: forgot` line logs how many.
- **Not when Gossip held anyone back:** the line would then pass discretion off as forgetting.
- **Not when nothing was told:** the "saw nobody" and "only who you can see" answers return earlier.
- **Evil:** teammates are skipped before memory is counted, so they never count as forgotten. The line can't cover for a teammate, and an evil speaker says it exactly as often as a good one would, given the people they admit to seeing.
- **Voices:** all 15 have `day_forgot_others`. `test_dialogue_voices` now expects 247 keys.
  - **Conflict with #308:** Beadle's #308 also adds a key (`gossip_meeting`). Whichever merges second sets the count to 248.
- **No tuning changed.**
- **Backlog:** the item moves to BACKLOG_COMPLETED.

Beadle's note: since #308, people who see a meeting after the player's choice gain "saw" beliefs, so the line may come up a little more often once #308 lands.

## Measured
- **New suite:** `tools/test_honest_forgetting.gd`, 9 checks, on the fast list. It covers four seen with memory 2, exactly as many as remembered, a Gossip holdback, an evil teammate beyond memory, and a good control.
- **Suites:** test_dialogue_voices, test_social, test_dialogue, test_control_flow, test_conversation_nights and test_evidence_cards pass.
- **Golden:** identical at `--tol 0` to the CI baseline on all five seeds. Golden's scripted play doesn't reach an answer that overflows memory.
