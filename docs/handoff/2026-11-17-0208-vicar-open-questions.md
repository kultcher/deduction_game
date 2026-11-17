# 2026-11-17, Claude-Vicar: an index of the open design questions, and a secrets rework note (`claude/vicar-open-questions`, docs only)

- **Who:** Claude-Vicar, new lead for design discussion and DESIGN.md (roster PR #184). Writes no game code. Briefed by Claude-Seneschal on Michael's behalf.
- **Base:** main `6873616` (#176). **Status:** PR open, docs only. **Next actor:** Bailiff to merge; Michael to pick which question to talk through first.
- **What changed:** new `docs/design/open_questions.md`, an index of the open design questions: what's open, where the evidence is, who would build it. Sources: BACKLOG's `[open]` and `[tentative]` items, DESIGN's "Open questions" and "Decided and open directions" sections, the recent handoff entries, and the open PRs #174, #180 and #182 (which add the Breathstealer overhaul, the Muddler, spillover damping and persistence Confidence to BACKLOG, not yet merged).
- **Added the same day: `docs/design/secrets_rework.md`,** from Michael's talk with me on secrets. It records his direction so far (dated Nov 17; secrets stay riders on a gift, most become something the holder knows and doesn't volunteer, evil can bluff them, the Muddler tentatively cut) and lays out a two-kind structure with costs and two worked examples (a Saint, a Baron-like Minion). Nothing is decided beyond that direction; section 8 lists his open calls and section 9 the checks for Lantern, Quill, Argon and Tally. Open questions index item 1.2 now points there.
- **Then backlogged** (Michael via Seneschal, Nov 17: smaller items first). Added to BACKLOG section 4 as "The secrets rework" [open], Michael-accepted; the note's section 9 is now Seneschal's staged plan (feasibility reports, a `mock/` prototype with paired sweeps, then settling section 8). Decide it alongside the Breathstealer overhaul.
- **Gap found:** Seneschal's brief says Michael approved "Option A" for Insight's new role in belief and that it's being measured. Neither is in the repo yet, so the index says so and points at `docs/belief_model.md` and the purge plan.
- **For later (Vicar):** DESIGN.md's NPC-minds section still describes the earlier belief model as current (Lantern's final handoff). I'll bring it up to date once Michael settles Insight, so the Insight row is written once.
- **Measured:** nothing. Read from the docs and code on `6873616`.

## 2026-11-17, Claude-Lantern: a doubted reading speaks through the role check only as far as it's trusted (`claude/own-reading-doubt`)

- **Base:** main `cd3aeb4` (#181 merged). **Status:** PR open. Golden identical to
  `baseline_a0a378d` (main after #188; no doubted role-checked reading on the five seeds), so it isn't in the
  golden-moving queue. **Next actor:** Bailiff merges.
  **Then: Claude-Quill**, whose Delusional fix builds on this (see "Where it lives").
- **The bug** (found unpinning `test_beliefs`, purge phase 2): a reading the listener doubts
  honestly (its night was poisoned or misled) kept moving its people in full, under both
  belief models. Readings that act through the role check (a Seer's Red Herring placement,
  an Archivist's, Clerk's or Gravedigger's role reading) never saw the doubt there: the
  doubt lowered the reading's reliability, which the role check doesn't read. The earlier
  model only looked different because its headline reading, which the doubt did turn off,
  added a little on top.
- **The fix:** each doubted reading in a set is weighed as genuine with the listener's trust
  in it and as a bare claim of the gift otherwise. This is exact for one doubted reading in
  a set; with several, each mixes against the others read in full.
  - **The doubt** is `listener.reading_doubt`. `SourceDoubt.derive` now also returns an
    `honest` map, built only from honest errors: a poisoned Night Watch, a misled or
    unreliable argument. Reading challenges are left out, since under connections a
    challenge acts only inside its own case (`test_connections_cases` caught a failed-gift
    challenge reaching the reading's own value). `Shared.evaluate` passes it to `_doubt_adjusted`, which sets
    `reading_doubt` per card. Callers that don't pass it change nothing.
  - **Caught lies, "lied" arguments and "lying" challenges stay out, by night or in
    general.** My first version read all source doubt. A bogus Gravedigger reading (a
    hanging that never happened) then stopped convicting its claimant: `test_shared_model`
    caught it, and it moved golden. My second read every night-specific doubt, which Codex
    showed still let a "lying" challenge or a night's "lied" argument soften the reading.
  - **Trust in the teller is left out on purpose:** the role check already lets an evil
    teller lie in the worlds where they're evil, so including it would charge it twice.
  - **Carried through** `Jury._eval_listener`. Both connections judgement keys (`judge_key`
    and the fast key) include the judged cards' doubts.
- **Where it lives (for Quill):** `CaseEval._doubted_role_fits` is the one place that handles
  a doubted reading in the role check. It's called once from `_evaluate_impl`, right after
  `fits`. `CaseEval.doubted_role_check` switches it off for measuring. Quill's Delusional
  item (the role check's `sourceEvil` exemption charging a Delusional teller's false reading
  twice) is in `RoleConstraints.cs`. Delusional doubt sits on the source's general doubt, so
  it is deliberately not in `reading_doubt` today; if Quill's fix wants a Delusional
  teller's readings read as honest errors, this function and `reading_doubt` are where it
  goes.
- **What changes in play:** on `test_role_check_doubt`'s fixture (seed 5110; the
  listener's own reading, then a misled argument doubting that night at 0.8):

  | Reading | With the reading | After the doubt, before the fix | After the doubt, now |
  |---|---|---|---|
  | Seer "yes" on a pair | 0.10 → 0.15 | 0.15 | 0.107 |
  | Archivist "one of these two holds the Minion's gift" | 0.10 → 0.385 | 0.385 | 0.119 |
  | Gravedigger verdict | 0.10 → 0.00 | 0.00 | 0.093 |

  An undoubted reading reads exactly as before. A Clerk reading moved no one in my fixture,
  so it isn't tested here.
- **Golden:** identical to `baseline_a0a378d` on all five seeds (checked again after merging #188); two captures identical.
- **Measured:** the new suite `test_role_check_doubt` (14/14: the three readings, plus a
  "lied" argument that must not soften the reading; added to the fast list), the CI fast
  list on this branch, and two golden captures. Not measured: how often a doubted
  role-checked reading occurs in bot games.
- **Order of my next work:** phase 6b (attention-limited signals read every held card), then
  the double-claim pairing, then Option A (Insight sets the core's joining bar; its
  measurement goes to Michael first), then purge phase 3.
- **Proposed for the backlog:** none.
- **Moved here from `docs/handoff_log.md`** (Seneschal, Nov 17: entries are now one file each, set up in #196). The log on this branch is main's, unchanged.
