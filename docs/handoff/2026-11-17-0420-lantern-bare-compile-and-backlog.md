# 2026-11-17, Claude-Lantern: a no-card case's compile holds the view's cards; Michael's backlog decisions (`claude/backlog-and-bare-compile`)

- **Base:** main `c676018`. **Status:** PR open. Golden identical to `baseline_a0a378d`, so it
  isn't in the golden-moving queue. **Next actor:** Bailiff merges.
- **The fix** (BACKLOG section 6, "A case with no cards can be answered from an older
  compile"; Michael, Nov 17: "the same situation should always give the same belief"):
  - **What was wrong:** a case with no cards, on a record with a silencing, reads every card
    on the view for "who was near each silencing". `CaseEval`'s compile key didn't include
    them, so two views with different silencing factors shared one compile. #181's key
    rework didn't change that.
  - **The fix:** the key now carries the view's cards in exactly that case (no cards, a
    silencing, and the view read for presence, which is everywhere except the connections
    judge).
  - **New suite `test_bare_compile`** (fast list, 9 s). It finds by search a listener whose
    view loses a day card that changes a no-card case, and checks that the two compile keys
    differ and that warm and cold give the same chances. On main from before the fix, the
    key check fails.
  - **Not seen in play:** in the game the test finds, the stale compile didn't reach anyone's
    chances. Golden is identical, so I haven't seen it change a belief in play.
- **BACKLOG** (Michael's decisions, relayed by Seneschal, Nov 17):
  - the item above moves to `BACKLOG_COMPLETED.md`;
  - "NPC-to-NPC credibility" is unchanged;
  - "The premise should matter" gets Michael's direction in his words, then **[decided]:
    centre on the premise, A or B to be chosen after measurement**, with both options and
    what to measure;
  - two new **[decided]** items in section 6: the double-claim pairing, and Insight setting
    the core's joining bar (range open).
- **Measured:** two golden captures (identical to the baseline and to each other), the CI fast
  list plus the new suite (64/64), and the new suite on the old code (fails as it should).
- **Order of my next work:**
  1. the double-claim pairing;
  2. Insight's core bar (the wider measurement is running);
  3. measuring A and B for the premise;
  4. purge phase 3.
- **Proposed for the backlog:** none.
