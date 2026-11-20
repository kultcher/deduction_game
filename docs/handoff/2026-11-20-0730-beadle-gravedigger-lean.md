# The Gravedigger in a reluctant town: a hidden lean

- **Agent:** Claude-Beadle
- **Base:** main at `07416df` (`baseline_58cb94a`, after #397)
- **Branch:** `claude/beadle-gravedigger-lean`
- **Status:** PR open. Golden moves; it's re-baselined in this PR (one seed's day-3 hanging
  changes). Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "The Gravedigger in a reluctant town" [decided] (Michael, Nov 17). From the
  overnight queue, the decision-free items.

## What changed

- **The lean:** a good, unbroken Gravedigger with nothing to read yet (no one hanged this case)
  leans a little towards nominating and voting to hang. It's a hidden motive, as Michael
  decided:
  - **Nomination:** it adds to its score for each candidate. The decision log records it as
    `role_lean`.
  - **Vote:** it's a vote part, `gravedigger_nothing_to_read`.
  - **Speech:** none. It has no lines, and the "why I voted no" lines never fire for it, since
    it only pushes toward yes.
- **A general hook:** `RoleDef.nomination_lean(w, n)` (0 by default), called from
  `MindMeeting._good_nomination_impl`. The vote side uses the existing
  `score_vote_reluctance` hook.
- **No lean for:** evil, a broken gift, or once anyone has been hanged.

## Questions for Michael

1. **New constant:** `Tuning.Roles.GRAVEDIGGER.nothing_to_read_lean` = **0.08** (proposed,
   modest). For scale, a good NPC nominates when its suspicion of someone tops a bar of about
   0.5.
2. **"Nothing to read"** is taken as no hanging yet this case (a small call). Should it also
   come back after a day with no hanging, once someone has been hanged? I left it out, as
   "reluctant town" reads as no hangings at all.

## Measured

- **New:** `tools/test_gravedigger_lean.gd` (8 checks), on the fast list.
- **Also pass:** test_roles_registry, test_meeting_flow, test_would_vote,
  test_nomination_and_evil_tuning, test_meeting_m2d, test_symmetric_vote and
  test_tuning_hoist.
- **Golden:** re-baselined to `baseline_82f6be4` on main with #397. Two captures were identical.
  - **Divergence from `baseline_58cb94a`:** 54875, 692 and 900 at the first vote carrying the
    Gravedigger's part, and 98933 at a day-1 nomination. 42 is identical.
  - **Outcomes:** 54875's day 3 hangs Agnes instead of Hollis. The other four seeds keep their
    hangings, and none has a winner by day 4.
  - See "Current baseline" in `docs/golden_baseline.md`.

## Proposed for the backlog

None.
