# Remove the dead "persuaded to spare" preference (spare_pref)

- **Agent:** Claude-Beadle
- **Base:** main at `de0fa80` (`baseline_58cb94a`, with #404)
- **Branch:** `claude/beadle-spare-pref-dead`
- **Status:** PR open. Play is unchanged. Golden is re-baselined only because every NPC record
  loses the always-empty `spare_pref` key; see Measured.
- **Next actor:** Bailiff (review and merge).
- **Item:** the cleanup follow-up after Herald's #395 (the social presentation route), which left
  `spare_pref` with no writer. Michael's overnight order, item 2.

## What's removed

- **The vote term:** `persuaded_to_spare` (`MindVote._vote_impl`), and its entry in the
  vote-resistance key list (`MindVote._resistance_key`).
- **The constant:** `Tuning.Meeting.VOTE_SPARE_PREF_SLOPE`. The catalogue is regenerated.
- **The decision trace input:** `spare_preference`.
- **The field itself:** `NPC.spare_pref`, its reset in `Mind._refresh_ledger_preferences`, its
  place in mind.gd's shadow-copy list, and devlog's trace fields.
- **The only test that existed for it:** test_meeting_m2d's "a voter persuaded to spare them says
  they aren't ready" check. The next check covers the same "not ready" line through a role's own
  reluctance. The two `voter.spare_pref.clear()` calls in test_meeting_flow go too.
- **A stale mention** in docs/meeting_flow_plan.md.

`protect_pref` stays: a "good" conclusion still writes it (Herald).

## Measured

- **Golden:** two captures were identical.
  - **Against `baseline_58cb94a`:** every seed differs only in the missing `spare_pref` key on
    each NPC (real and shadow).
  - **With that key ignored** (`golden_diff.py --ignore engine,spare_pref`): identical on all
    five seeds.
  - So no decision changed. Re-baselined to the new capture.
- **Suites:** 10 of 10 pass: test_meeting_m2d, test_meeting_flow, test_symmetric_vote,
  test_would_vote, test_lie_severity_votes, test_tuning_hoist,
  test_dialogue_fixes_accusations_votes, test_readings_agree, test_state_digest and
  test_decision_inspector.

## Proposed for the backlog

None.
