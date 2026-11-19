# 2026-11-19, Claude-Lantern: several doubted readings weighed symmetrically in the role check (`claude/a3-doubted-symmetric`; moves golden)

- **Base:** main `77bad4d`. **Status:** PR open. **Next:** Bailiff. It's golden-moving, so it merges on its own. My judgement-boost PR follows it in the queue.
- **Why:** Steward DEEP A3, decided by Michael on Nov 19 (via Seneschal): build the symmetric
  fix.
  - **The old behaviour:** when one judged set held several readings the listener doubts (a
    poisoned or Delusional night), `CaseEval._doubted_role_fits` mixed each one in turn
    against the others read in full. The result depended on card order, and the earlier
    readings were under-doubted.
- **What changed:**
  - **The weighing:** all the doubted readings genuine, with chance prod(1 - d), or exactly
    one broken (against the others in full), with chance d_i x prod_{j != i}(1 - d_j).
    Renormalised over those cases.
  - **Cost:** the same as before, one extra role check per doubted reading.
  - **One doubted reading:** exact, and unchanged bit for bit.
  - **Two or more broken at once:** those worlds are left out, and the rest share their
    weight.
- **BACKLOG:** added "Higher-Insight NPCs weigh more broken-reading combinations" [tentative],
  owner Lantern, as Michael asked. It's the exact fix for sharper NPCs.
- **Measured:**
  - **How often it applies:** in 2 ten-NPC games (autoplay seed 1, before the fix), 43% of
    the role checks holding any doubted reading held two or more, up to four.
  - **On the test's hand-built case** (a Clerk's and a Seer's reading, doubted at 0.4 and
    0.3), the judged chance is 0.063 in either card order. Before, it was 0.057 or 0.080
    depending on the order.
  - **Golden:** every seed moves in belief values from the first night. On three seeds every
    NPC's suspicion at every step is identical. On 42 and 900, a tenth of the suspicion
    values move, by at most 0.004 and 0.009. All five outcomes are unchanged. Re-baselined
    to `baseline_7a10762`; two captures were identical.
  - **Suites:** `test_role_check_doubt` (19 checks, with 2 new; the order check fails on the
    old code), `test_poison_self_doubt`, `test_delusional_reading`, `test_honest_mistake`,
    `test_connections_cache`, `test_connections_core` and `test_workshop_regressions` pass.
- **Proposed for the backlog:** none. The exact-fix item above was Michael's.
