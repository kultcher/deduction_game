# 2026-11-17, Claude-Lantern: Insight sets the core's joining bar (`claude/insight-core-bar`)

- **Base:** main `c676018`. **Status:** PR open. **Golden moves:** re-baselined to
  `baseline_e639966` in this PR (golden-moving queue: merge one at a time). **Next
  actor:** Bailiff reviews and merges.
- **What Michael decided** (Nov 17, BACKLOG "Insight sets how readily a card joins an
  NPC's core", Option A; range 0.8 → 0.1, my recommendation): a sharp NPC links more cards
  to its own readings and nights, a dull one only the glaring ones; nobody connects public
  cards that don't touch their own knowledge.
- **The change:** `Connections.join_bar(listener)`, a straight line from
  `Workshop.CONNECTIONS_CORE_JOIN_DULL` (0.8) at Insight 0 to `_SHARP` (0.1) at Insight 1,
  replaces the single `CONNECTIONS_CORE_JOIN` (0.4). `Jury` passes the listener's Insight
  to the connections refresh. The judge never reads Insight, so it is left out of
  `judge_key` and `_judge_key_fast` (no cache split between listeners).
- **Docs:** DESIGN carries Michael's approved line ("Insight also sets how readily an NPC
  connects what it hears to what it knows firsthand..."), replacing "never what it
  believes"; DESIGN's core bullet, TUNING_NARRATIVE and `docs/belief_model.md` ("Insight
  sets the core's bar") give the new bar and the measurement; `tuning_catalogue.md`
  regenerated. The trait table's Insight row is unchanged (its rewrite is purge phase 8).
- **Measured before the build** (mock branch; 10-NPC towns, seeds 1-10, 10 passive and 10
  bot games a setting): at 0.8 → 0.1 a dull NPC (Insight under 0.4) links 0.25 cards to its
  own knowledge, on about 1 day in 4; a sharp one (0.7 and over) 1.0, on 2 days in 5. At
  0.4 for everyone both linked 0.55. NPCs don't solve earlier at any setting. Full table in
  `docs/belief_model.md`.
- **Golden:** every seed diverges from its first refresh where a core differs. 98933's
  outcome changes: Nisha (good, Insight 0.88) nominates the Demon Odette on day 2 and good
  wins; before, Merrin (good) was hanged on day 3 and the game was open at day 4. The
  other four hang the same people on the same days (details in `docs/golden_baseline.md`).
- **Checked:** `ci_fast_suites` 64/64; `test_connections_core` has a new check that a sharp
  listener links more to its own reading than a dull one on the same tests; golden twice,
  identical to each other.
- **Left:** the BACKLOG item lives on #192's branch (not yet on main); once #192 merges I
  move it to COMPLETED here or in the next PR.
