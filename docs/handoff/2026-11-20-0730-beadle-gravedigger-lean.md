# The Gravedigger in a reluctant town: a hidden lean

- **Agent:** Claude-Beadle
- **Base:** main at `0b44cae` (`baseline_7005cc6`), merged in Nov 20; first written on `07416df`
- **Branch:** `claude/beadle-gravedigger-lean`
- **Status:** PR open. Golden moves; it's re-baselined in this PR (one seed's day-3 hanging
  changes). Golden-moving PRs merge one at a time.
- **Next actor:** Bailiff (review and merge; Michael approved the value and the rework, Nov 21).
- **BACKLOG item:** "The Gravedigger in a reluctant town" [decided] (Michael, Nov 17). From the
  overnight queue, the decision-free items.

## What changed

- **The lean:** a good Gravedigger always leans a little towards nominating and voting to
  hang, since its gift reads the hanged and is best with a hanging every day. It's a hidden
  motive, as Michael decided:
  - **Nomination:** it adds to its score for each candidate. The decision log records it as
    `role_lean`.
  - **Vote:** it's a vote part, `gravedigger_wants_hanging`.
  - **Speech:** none. It has no lines, and the "why I voted no" lines never fire for it, since
    it only pushes toward yes.
- **A general hook:** `RoleDef.nomination_lean(w, n)` (0 by default), called from
  `MindMeeting._good_nomination_impl`. The vote side uses the existing
  `score_vote_reluctance` hook.
- **No lean for:** evil, or any other role.

## Michael's answers (Nov 21, via Seneschal)

- **New constant** `Tuning.Roles.GRAVEDIGGER.hanging_lean` = **0.08**: approved. For scale, a
  good NPC nominates when its suspicion of someone tops a bar of about 0.5.
- **Permanent:** the lean is always on for a good Gravedigger, not only until the first hanging.
  Reworked in `b96d2f2`.

## Small calls made on Michael's behalf

- **Renamed** the constant from `nothing_to_read_lean` to `hanging_lean`, and the vote part from
  `gravedigger_nothing_to_read` to `gravedigger_wants_hanging`, since "nothing to read" no
  longer describes it.
- **A broken gift keeps the lean.** A poisoned or delusional Gravedigger can't know its gift is
  broken, so it still wants a hanging to read. The first version dropped the lean then.

## Measured

- **New:** `tools/test_gravedigger_lean.gd` (8 checks, including the lean staying after a
  hanging), on the fast list.
- **Also pass:** test_gravedigger_bluff, test_nomination_and_evil_tuning, test_symmetric_vote and
  test_tuning_hoist (and earlier test_roles_registry, test_meeting_flow, test_would_vote,
  test_meeting_m2d).
- **Golden:** re-baselined to `baseline_b96d2f2` on main at `0b44cae` (replacing
  `baseline_82f6be4` and `baseline_68297e3`). Two captures were identical.
  - **Divergence from `baseline_7005cc6`:** 54875, 692 and 900 at the first vote carrying the
    Gravedigger's part, and 98933 at a day-1 nomination. 42 is identical.
  - **Permanent against the until-the-first-hanging version:** 54875, 692 and 900 also differ
    at day-3 votes, where the lean now stays. Every hanging is the same.
  - **Outcomes:** in 54875, Agnes is now hanged as well as Edda. The other four seeds keep their
    hangings. No seed has a winner.
  - See "Current baseline" in `docs/golden_baseline.md`.

## Proposed for the backlog

None.
