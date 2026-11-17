# 2026-11-17, Claude-Lantern: connections purge phase 2, the tests leave the earlier model (`claude/purge-phase2-tests`, tests and docs)

- **Base:** main `3ebe627`, with #174 merged in (stacked on it: merge #174 first).
  **Status:** PR open. **Next actor:** Bailiff merges. Then the poisoned-reading fix (after
  #181), the double-claim pairing, then phase 3.
- **What changed and why:** the seven suites pinned to the earlier model now run on
  connections. Checks of mechanics connections replaced now check what connections does
  instead:
  - `test_premise_step1`: Insight no longer scales how a case moves the people it only
    mentions (it was 40% to 80%); they move by what the cards say, the same at any Insight.
  - `test_premise_step2`: a one-card "suspicious" case moves beliefs as far as the same card
    argued as evil (it was half), and presses its subject up to the private cap. A second,
    weaker filing presses less than the first.
  - `test_recency`: a card fading from attention no longer changes belief; bounded and
    full-attention listeners agree.
  - `test_workshop_live_cognition`: the same cards aimed at someone else move no one, and on
    a new day the people a case named drop a little (the fade), with no second award.
  - `test_execution_aftermath`: the freed-soul fixture no longer reaches the old 0.25 cap
    under connections (two Seer readings leave a Red Herring to explain them: the suspect at
    0.34 to be evil). The check now tests the restore directly.
- **Still pinned, and why:**
  - **Two `test_beliefs` checks**, until their fixes land:
    - The poisoned own reading. It's a CaseEval bug in both models: a Seer reading's Red
      Herring placement ignores the listener's trust in it. The fix waits for #181.
    - The double claim. Michael approved a pairing, Nov 16.
  - **`test_workshop_live_cognition`'s persistence Confidence section.** Michael: delete it
    with the purge (backlog item added).
  - **`test_workshop_why`**, until phase 3 deletes the earlier Why report.
- **Moved to phase 3: the fixture search.** `tools/fixture_seeds.gd` still searches on the
  earlier model. On connections the search finds different games, and four checks fail
  there:
  - `test_self_sighting` and `test_relay_bluff`: an invented relay of the listener counts
    against its relayer at 0.64 against a 0.8 bar (seed 100048, Odette on Fenwick);
  - `test_relay_bluff`: a genuine Medium's relay reads as good in only 1 of 3 games;
  - `test_relay_bluff`: "nor in another game, later on" reads 0.10 (seed 100027, Edda on
    Agnes).
  The search is also slower: `test_relay_bluff` 222 → 742 s, `test_self_sighting` 62 →
  347 s. Phase 3 has to switch it anyway.
- **Phase 3 is blocked** until both `test_beliefs` checks are settled.
- **Also in this PR:**
  - `BACKLOG.md` section 6: persistence Confidence as [tentative] (Michael, Nov 17).
  - `docs/connections_purge_plan.md`: phase 2 as built, and what phase 3 now carries.
- **Measured:** the seven suites and the four fixture-search suites, run alone on this box;
  then the full CI fast list (61/61) on this branch with the search on the earlier model.
  No golden capture: no game code changed.
- **Reviewed #181** (Argon's speed patch): the skip in `jury.gd` and the cache keys are
  sound. The role-card filter drops six card kinds the role check's routing reads: sighting,
  evening, trace, coverage, alibi and dropped. The full list is on the PR.
- **Proposed for the backlog:** none.
