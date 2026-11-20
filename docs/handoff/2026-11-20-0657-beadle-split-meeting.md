# Split mind_meeting.gd (Tier 1)

- **Agent:** Claude-Beadle
- **Base:** main at `ad33789` (`baseline_7792e9a`)
- **Branch:** `claude/beadle-split-meeting`
- **Status:** PR open. Zero drift: golden is identical to `baseline_7792e9a` on all five seeds.
- **Next actor:** Bailiff (review and merge).
- **Item:** Michael's Nov 20 order, item 1, the cleanup: "File splits", Tier 1, the first of
  four. The others are mind_dialogue.gd, world.gd and mind.gd.

## What changed

No change to play. Code moves only.

| File | Lines | Holds |
|---|---|---|
| `sim/mind_meeting.gd` | 1,265 | testimony, volunteering sightings, public claims, citing reasons, relays, accusations, consensus, choosing nominations |
| `sim/mind_nomination.gd` (new) | 499 | the nominator's case (`case_against`, `nomination_case`, `recall_cited`, ...) |
| `sim/mind_defence.gd` (new) | 501 | the nominee's defence (`defend_self`, `defence_line`, ...) |
| `sim/mind_vote.gd` (new) | 340 | the vote (`vote`, `_vote_impl`, `would_vote`, `vote_resistance_lines`, `catches_home_lie`, ...) |
| `sim/mind_meeting_base.gd` (new) | 142 | what all four share |

- **The base:** the four modules extend it. It holds:
  - the preloads and the consensus constants;
  - lazy loaders for one another, `_meeting()`, `_nomination()`, `_defence()` and `_vote()`;
  - the delegates to `Mind`.

  So code that moved keeps calling those bare.
- **Calls across modules are prefixed,** such as `_nomination().case_against(...)` from the
  meeting.
- **Callers repointed, with no new forwarders:**
  - `sim/mind.gd`'s wrappers now call the new modules. Every `Mind.<fn>` stays, so game/ and
    ui/ are untouched (Herald checked).
  - `tools/case_slate.gd` and 20 suites now use `MindNomination`, `MindDefence` or `MindVote`.
- **Docs:**
  - `test_tuning_hoist` checks each moved constant in its new file.
  - The README code map and two comments are updated.
- **The split was done by a script,** so it can be re-run on a newer main. Order with Quill's
  Muddler removal doesn't matter: none of the Muddler code moves.

## Measured

- **Golden:** identical to `baseline_7792e9a` at `--tol 0`.
- **Suites:** 35 of 35 pass. That's every suite the PR touches, plus the meeting, defence, vote,
  claims and evil-play suites:
  - test_meeting_m2a, m2c, m2d, test_meeting_flow and test_meeting_reasons;
  - test_double_claim_response, test_gift_doubt and test_gift_doubt_good;
  - test_symmetric_vote, test_would_vote, test_lie_severity_votes and test_day_defence;
  - test_evil_play, test_dialogue_voices, test_caught_out_ladder, test_tuning_hoist and the
    rest.

## Proposed for the backlog

None.
