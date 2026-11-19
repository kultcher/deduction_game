# "Their readings agree with what I know"

- **Agent:** Claude-Beadle
- **Base:** main with #319 (`baseline_8d946e7`)
- **Branch:** `claude/beadle-readings-agree`
- **Status:** PR open, on main with #319. It moves golden and re-baselines to
  `baseline_2829999` (Codex on #321): lines and cards only, no outcome changes. It merges after
  #319.
- **Next actor:** Bailiff, after #319.
- **BACKLOG item:** "Trust from readings that confirm what I know or strongly believe". This is
  its approved "next" step, which #319's BACKLOG note already describes. The false version is
  tabled there.

## What changed

The record of confirming readings from #319 now gives NPCs a reason to say out loud
(Michael, Nov 19). In both places it takes a moderate or known confirmation; a small one isn't
enough.
- **Asked about someone** (`answer_opinion`): a speaker who would clear them, and whose record
  confirms their readings, gives that as the reason. The line is `opinion_readings_agree`:
  "Lian's readings agree with what I know, so I don't take them for one of the wicked."
- **After a failed vote** (`vote_resistance_lines`): a no-voter whose record confirms the nominee
  says `vote_resist_readings_agree`: "I won't hang Lian: their readings agree with what I know."
  It ranks ahead of the generic reasons ("not ready", "short of the rope"), and a no-voter with
  such a record may now speak even without having accepted the case.
- **The player's card:** each line gives an `opinion` card with stance "for" ("Edda speaks up
  for Lian"), citing the reading. In the vote case it travels through `res.resistance_facts`,
  so `game_meeting.gd` gets one added line.
- **Evil:** it says this honestly only, from its good self's record (`Social.readings_agree_record`).
  The false version is tabled.
- **No direct effect on suspicion:** NPCs already hold the cited reading and weigh it through
  their own judgement.
- **Wording:** Herald's lines in all 15 voices, approved by Michael on Nov 19 without `{role}`.
  The voice test's key count goes up by 2.

## Measured

- **New suite:** `tools/test_readings_agree.gd` (9 checks), on the fast list.
  - Asked about someone, a speaker with a confirming record says it, with a card.
  - A small confirmation isn't enough, and no record means no such reason.
  - An evil speaker can't say it from a record its good self doesn't hold, but does when that
    record holds it.
  - After a vote, a no-voter says it, with a card, and a voter with no record says nothing of
    the kind.
- **Suites that pass:** test_dialogue_voices, test_dialogue_opinion_pass, test_meeting_m2d,
  test_meeting_flow and test_reading_trust.
- **Golden:** `baseline_2829999`, against main's `baseline_8d946e7` (with #319); two captures identical:
  - 54875, 692 and 98933 diverge at day 2's vote;
  - in each, the new card and line appear after a failed vote. In 98933, one NPC's reasons are
    then marked for a refresh;
  - 42 and 900 are identical;
  - every outcome is unchanged.
- **Not measured in play:** passive games never ask NPCs their opinion, so that venue is covered
  by the suite. The vote venue fires in golden play.

## Proposed for the backlog

None.
