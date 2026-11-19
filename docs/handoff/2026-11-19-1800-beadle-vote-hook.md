# A vote hook for the case slate: how a case moves votes

- **Agent:** Claude-Beadle
- **Base:** main at a6b674b (`baseline_ee15238`)
- **Branch:** `claude/beadle-vote-hook`
- **Status:** PR open. Zero drift: the hook isn't called in play.
- **Next actor:** Bailiff (review and merge). Then Quill, who owns the slate.
- **Ask:** Michael, through Seneschal (Nov 19): "how a case moves votes, since votes are the real
  metric". Quill adds a vote measure to the case slate, and Beadle supplies the hook.

## What changed

`MindMeeting.would_vote(w, nominee, nominator = "")` (`sim/mind_meeting.gd`): how the good
townsfolk would vote on `nominee` if it were nominated now.
- **What's left out:** the player's vote and statement. `""` is a neutral nominator.
- **How it votes:** each good, living voter other than the nominee runs the real vote
  (`_vote_impl`). That includes its reconsideration, so its beliefs refresh as they would at a
  real meeting.
- **Nothing else is left behind:** no random draw, no log entry, and the meeting state as it was.
- **Evil voters** are left out.
- **It returns** `{yes, no, voters, threshold, crosses}`:
  - `voters` and `threshold` are the real meeting's, with the player counted as a voter
    (`World.vote_threshold`);
  - `crosses` is whether the good yes votes alone reach the threshold.

## For Quill: using it in the slate

For each case, call `would_vote(g.w, s.id)` before the presentation and again after it, and
record the yes count before and after and `crosses`.
- **The 10-NPC deal:** the threshold is 6 of 11 (the player counts), and there are 6 or 7 good
  voters besides the nominee. So `crosses` with good votes alone needs nearly all of them.
- **Worth reporting too:** the yes count against the threshold.
- **Reconsideration:** it refreshes beliefs, so call it after `_evaluate_deduction`, not between
  presentations to different listeners.

## Measured

- **New suite:** `tools/test_would_vote.gd` (7 checks), on the fast list.
  - No random draw, no log entry, and the meeting state as it was.
  - It counts every good voter but the nominee, and no evil one.
  - It uses the real meeting's threshold.
  - Each voter's result matches the real vote.
  - With every good voter sure of the nominee, it crosses.
- **Golden:** identical to `baseline_ee15238` at `--tol 0` on all five seeds.

## Proposed for the backlog

None.
