# Caught out and pressed again (2 of 2): the podium

- **Agent:** Claude-Beadle
- **Base:** main at `3f219018` (`baseline_1bf8a4b`), with #560 merged
- **Branch:** `claude/beadle-pressed-again-podium`
- **Status:** PR open. Golden unmoved (all five seeds identical at `--tol 0`).
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Caught out and pressed again: what's left" [decided], closed here and moved to
  BACKLOG_COMPLETED.md. Plan by Michael (Nov 20): "the same ladder runs at the podium: private
  first, then the podium". Constants approved Nov 27, merged in #560.

## What changed

- **`MindPodium.press_night` takes `pressed`:** true when the player presses a nominee with a card
  about that night (`press_card`), the podium's version of the private card press. The NPC's own
  defence and the meeting's other callers are unchanged.
- **The press count is shared** (`MindPress.press_count` / `note_press`): a podium press counts
  for the private ladder, and private presses count here.
- **Good, out that night, pressed again:** each earlier press adds `PRESSED_AGAIN_OPENNESS` × the
  count to the parts of the podium's own decisions (confessing a known burden's walk, owning a
  walking gift's outing).
  - A walker that had owned the night but kept its gift's errand ("I was out, the why is my own")
    now rolls to give the gift when pressed again (`_gives_way`, with the reveal's cost), instead of
    always repeating the plain account.
- **Truly home, pressed again before the town:** the same lines, and it trusts the Demonologist
  less, by the question-fatigue amount, as in private.
- **Evil that owned the night with nothing to tell, pressed again:** it may back into a spare
  walking gift (`MindPress.back_into_walking_gift`, split out of #560's private path with the same
  guards and roll) and claims it before the town.

## For Michael: the podium's push is stronger than in private

The same 0.15 per press is added to a decision's parts at the podium, which go through the
decision curve (slope 4), but to openness in private, which crosses fixed tiers. So it pushes
harder before the town:
- an Unrequited holder's walk, confessed at the podium: 28 of 60 with no earlier press (0.47), 53
  of 60 after three (0.88);
- in private, closed NPCs gave the reason within six presses, 20 of 20 (#560).

If that's too strong before the town, a separate, smaller podium value would be a new constant,
Michael's call.

## Small calls made on Michael's behalf

- **Only the player's card press counts at the podium,** not "press night" without a card or an
  NPC's own defence, matching the private ladder ("pressed with a case placing them out").
  `game/game_meeting.gd` (Herald's) is unchanged.

## Measured

- **New:** `tools/test_pressed_again_podium.gd`, 5 checks, on the slow CI list (about 50 seconds):
  - a podium card press counts for the private ladder;
  - truly home: no extra cost at the first press, trust drops on the next;
  - the Unrequited walk confessed 0.47 → 0.88 with three earlier presses (60 deals from 7100);
  - evil backed into a walking gift in 9 of 19 deals (from 7200), always claimed publicly and
    always a walking gift.
- **Also pass:** test_pressed_again, test_codex_fixes, test_confessed_night, test_meeting_flow,
  test_meeting_m2b, test_night_sighting_rebuttal, test_npc_fixes_shifts_dead_haunt,
  test_readings_agree.
- **Golden:** identical to `baseline_1bf8a4b`. The golden bot doesn't press a nominee twice about
  one night.
- **Not tested directly:** `_gives_way` (a walker's kept errand given at the podium). It reuses the
  podium's existing gift-outing decision and lines.

## Proposed for the backlog

None.
