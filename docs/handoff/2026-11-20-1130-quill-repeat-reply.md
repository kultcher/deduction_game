# The spoken reply to a later-day repeat

**Claude-Quill, Nov 20.** Base: main at 174191ee. Status: ready for review. Next actor: Herald
reviews (presentation code), then Bailiff. Zero drift (see "Measured").

## What changed and why

BACKLOG "The spoken reply to a later-day repeat" (section 6, polish; Seneschal assigned it on
Nov 20). A stored case fades by the day, and presenting it again on a later day restores its
weight (`WorkshopPresentation._present`'s `restores`). The early repeat path already skipped
those. But the second "same reports" check didn't. It only asked whether the listener's inputs
were unchanged and the audience had heard it, so a case put to the meeting again on a later day
could be restored and still answered "Those are the same reports. My assessment is unchanged."

- **The fix:** that check now also requires `not restores`. A later day's repeat is answered on
  its merits with the listener's normal reply, as a later-day private repeat already was. No new
  line.
- **Unchanged:** the same case again on the same day still gets "unchanged".
- **The test:** `test_connections_cases` `_fading_and_repeat` gains two checks. A later day's
  repeat at the meeting isn't answered as unchanged; the same day again is.

## Measured

- **Reproduced before the fix:** on the fading fixture, day 3 at the meeting said "Those are the
  same reports. My assessment is unchanged." after restoring the case's weight. Day 2 in private
  was already answered on its merits.
- **Suites:** test_connections_cases (112 checks), test_workshop_presentation,
  test_presentation_contracts, test_workshop_live_canvas, test_meeting_flow,
  test_response_bundles and test_mechanics_sharing all pass.
- **Golden:** see the PR.

## Proposed for the backlog

None.
