# Herald: summarised answers to a case at the meeting

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff. Beadle may want to look at the evil-mask rule below.

## What changed and why

Michael approved this on Nov 19, through Seneschal. When a case is presented at the meeting, listeners who answered alike are now shown together, not one by one. A representative speaks in full (the main portrait and text). Along the bottom of the frame, a row of small portraits shows who agreed, each with a short line ("Aye.", "Hear, hear!"). Hovering a small portrait shows that person's own words. At most five portraits are shown; the rest read "+N more". The log keeps every answer in full. Private presentations are unchanged.

- **The rule** (`game/response_bundles.gd`): two answers match on stance (accept / partial / reject), on the kind of reply (its voice-pool key), and on the movement band on the case's target. The four bands are: rose 15 points or more, rose 5 to 15, within 5, fell.
- **Who speaks alone:**
  - the target, who always speaks last;
  - anyone with more than one line (caught out and explaining a night);
  - anyone who adds a card;
  - any answer with no reply kind, including an evil reply that names the scapegoat.
- **Evil listeners:** they bundle on what their mask shows, and their movement is read from their good shadow. A bundle never says more than the masked answers do.
- **The representative and the order:**
  - The representative is the member nearest the bundle's average agreement; ties go to higher trust, then seat.
  - Bundles go most agreeing first, then the solo speakers, then the target.
- **Plumbing:**
  - `sim/dialogue_presentations.gd`: replies carry `reply_key`.
  - `game/game.gd` `_line`: passes `agree` / `agree_more` / `bundled` through.
  - `game/game_presentation.gd` `_present_deduction`: collects every answer, then speaks them arranged.
  - `ui/courtroom_stage.gd`: bundled lines go to the log, not the stage, and the row is drawn under the speaker.
- **Voice lines:** `agree_short_a` / `agree_short_b` in all 15 voices, as approved. `test_dialogue_voices`' key count goes from 252 to 254.

## Measured
- **`test_response_bundles`** (new, 15 checks, on the fast list) covers the bands, the bundling, the representative, the order, the target last, a solo speaker's fact, five shown plus "+2 more", and the alternating agreement lines.
- **A real meeting** (seed 692, 10 NPCs): every listener's answer is in the log. 5 of 10 were folded into rows, and those shown agreeing are exactly the bundled log lines. The stage brings forward only the representative and draws the row, with the own words on hover.
- **Suites passing:** test_dialogue_voices, test_meeting_stage, test_meeting_flow, test_meeting_m2a, test_workshop_live_canvas, test_presentation_contracts, test_workshop_presentation, test_evil_play, test_meeting_stream, test_ui, test_dialogue_fixes_accusations_votes and test_lie_severity_votes.
- **Golden:** identical at `--tol 0` on all five seeds. Only the order and display of answers change.
- **Screenshot:** a five-portrait row with "+2 more", checked by eye.

## Not covered
- A case put on a nomination (`case <#>`) still has each voter answer one by one. Michael said meetings; this can follow if he wants it there too.

## Proposed for the backlog
None.
