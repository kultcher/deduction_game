# Good NPCs say their gift may have been turned

- **Agent:** Claude-Beadle
- **Base:** main at 4248293
- **Branch:** `claude/beadle-gift-doubt-good`
- **Status:** PR open. It's zero drift: golden is identical to `baseline_21df80d` on all five
  seeds.
- **Next actor:** Bailiff (review and merge). Michael, if he wants the threshold moved.
- **BACKLOG item:** "Saying 'my gift may have been turned'", part (a) (Michael, Nov 17-18).
  Marked built.

## What changed

A good NPC whose gift is public, and who is the role it claims, says it when its own doubt about
a night's readings reaches `Tuning.Meeting.GIFT_DOUBT_SAY` (new, 0.25, Michael's value).
- **The doubt:** the poison self-doubt or the Delusional self-doubt, from its last refresh
  (`SourceDoubt.self_doubt`).
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
  - It fires at 26%, with the line, the night and the public record.
  - It's said once a game.
  - Nothing happens below 25%, or for a private claimant.
  - A doubt about all its readings (night -1, the Delusional one) counts.
  - Evil never takes this route.
- **Suites that pass:** test_gift_doubt, test_meeting_flow, test_evil_play and test_meeting_m2c.
- **How often, in play:** 15 passive 10-NPC games, seeds 4000-4014, each good reader's own doubt
  at each day's end.

  | Night of the reading | Its self-doubt |
  |---|---|
  | first, second | about 16-17.5% |
  | third | 19-21% |
  | fourth, fifth | 25-32.5% |

  - **At 25% or more:** 7 of 193 reader-days, all public claimants.
  - **Said:** by Agnes (the Gravedigger) and Edda (the Dowser), both on day 5.
  - **Over 40 games on seeds 4000-4039** it never fired, because few games reach the fourth
    night.
  - **For scale:** 15% would be reached on 140 of the 193 reader-days, from day 1.
- **Golden:** identical (no golden game reaches the doubt).

## For Michael

He thought 25% might be low. In play it bites only late in long games. The value is his; it's
unchanged here.

## Proposed for the backlog

None.
