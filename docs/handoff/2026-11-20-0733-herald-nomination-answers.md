# Herald: summarised answers when a case is laid before a nomination

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff. When it merges, Vicar can close the BACKLOG item "Summarised answers at a nomination".

## What changed and why

The BACKLOG item, decided by Michael on Nov 19 and released by Seneschal's Nov 20 order, says a case presented at a nomination should get summarised answers, the same as at the meeting. #373 built them only for the meeting's floor.

- **Before:** on `case <n>` at a nomination, each listener weighed the case in silence (`_evaluate_deduction(..., speak = false)`). The player saw only their own narration and then the vote prompt.
- **Now:** each listener answers aloud, and those who answered alike are bundled (`game/response_bundles.gd`). One speaks in full and the rest show as portraits with a word of agreement; the log keeps every answer.
- **The code:** the meeting's loop is now `GamePresentation.hear_town(g, listeners, ded, scale, venue, progress)`, used by both places.
  - The meeting calls it for every living person.
  - The nomination calls it for everyone but the nominee, at the nomination's weight, as before.
  - No new forward in game.gd; game_meeting.gd preloads game_presentation.gd.
- **Zero drift:** golden is identical. Speaking draws no random number and changes no belief, so the vote is unchanged.

## Measured

- **`test_nomination_case`:** 3 new checks, now 20. Every listener but the nominee is heard once. The portraits shown agreeing are exactly the bundled log lines. Some answers were bundled (the fixture).
- **Locally, before merging main:** all 150 CI fast suites pass, and golden is identical at `--tol 0` on all five seeds.
- **After merging main:** test_nomination_case, test_response_bundles, test_meeting_flow and test_presentation_contracts pass.

## Proposed for the backlog
None.
