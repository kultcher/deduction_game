# Good NPCs say their gift may have been turned

- **Agent:** Claude-Beadle
- **Base:** main with #320 (`baseline_6569929`)
- **Branch:** `claude/beadle-gift-doubt-good`
- **Status:** draft PR, held by Michael (Nov 18-19) until it's rewired on Lantern's clash
  signal (#320). Now rewired. Zero drift: golden is identical to `baseline_6569929` on all
  five seeds.
- **Next actor:** Michael (un-draft, or change the trigger), then Bailiff.
- **BACKLOG item:** "Saying 'my gift may have been turned'", part (a) (Michael, Nov 17-18).
  Marked built.

## What changed

A good NPC whose gift is public, and who is the role it claims, says it when it doubts a night
of its own readings (`SourceDoubt.doubts_own_gift`, #320).
- **The doubt:** the judge's chance that night's reading was wrong, from its clash with
  everything else the NPC holds, starting from the poison and Delusional prior. It fires at
  `Tuning.Workshop.SELF_DOUBT_TRIGGER` (0.30, Michael, Nov 19).
- **Rewired (Nov 19):** the first version used the prior alone at a new 25% constant,
  `Meeting.GIFT_DOUBT_SAY`. Michael held it ("a generalized doubt is not a useful signal"), and
  that constant is gone.
- **Where it's said:** at its next meeting turn speaking to the town, with the approved
  per-voice `doubt_own_gift` line, once a game.
- **The route:** the same one the boxed-in evil bluffer uses (`MindMeeting._say_gift_doubt`),
  so the player can't tell the two apart by wording.
- **How listeners take it:** unchanged from #245, as honest doubt about all that teller's
  readings.
- **The log:** a `gift_doubt_planned` entry with the night and the doubt ("32% doubt about its
  reading for night 4"), and the existing `self_doubt` think entry when it's said.
- **Code:** `MindMeeting._good_gift_doubt`.

## Measured

- **New suite:** `tools/test_gift_doubt_good.gd` (9 checks), on the fast list.
  - It fires just above the trigger, with the line, the night and the public record.
  - It's said once a game.
  - Nothing happens below the trigger, or for a private claimant.
  - A doubt about all its readings (night -1, the Delusional one) counts.
  - Evil never takes this route.
- **Suites that pass:** test_gift_doubt, test_meeting_flow, test_evil_play and test_meeting_m2c.
- **Suites that pass (rewired):** test_gift_doubt_good, test_own_gift_doubt,
  test_poison_self_doubt, test_meeting_flow and test_evil_play.
- **How often, in play (rewired):** 15 passive 10-NPC games, seeds 3000-3014.
  - **Said 12 times in 8 of the 15 games,** mostly at the day-2 or day-3 meeting.
  - **8 of the 12 doubted a reading that really was wrong** (poisoned, Delusional or otherwise
    false); 4 doubted a true one. Doubt ran from 31% to 100% (a Dowser count of 6 evil).
  - **Before the rewiring,** the same 15 seeds had it said twice, both on day 5.
- **Speed:** 3 passive games of 12 days in total took 334 s against 321 s on main, about 4%
  slower, with the judge read once per refresh for each good public claimant.
- **Golden:** identical to `baseline_6569929` (no golden game reaches the doubt).

## For Michael

It now fires early and mostly when the reading really was wrong: 8 times in 12, in about half
the games. Lantern's own measure, about 1 game in 4, counted only the day-4 meeting; this counts
every meeting. If that's too often, raising `SELF_DOUBT_TRIGGER` is the lever (Lantern's
constant; changing it moves his measure too).

## Proposed for the backlog

None.
