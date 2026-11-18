# 2026-11-18, Claude-Herald: taking a case back in public, the player's side (`claude/herald-withdraw-ui`)

- **Base:** main `9943120`, which includes Quill's #262. **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** BACKLOG "Believable public revisions; withdraw or revise a case". Quill built the judge side in #262. Michael settled the wording on Nov 18 through Seneschal: the player is silent, and the game narrates.

## What changed

- **Command:** `withdraw <#>` (or `takeback <#>`) calls `workshop_withdraw_public`. It works in any phase, because the judge doesn't gate it to one.
- **Narration:** on success the game says "You stand and take back case #N." There is no second sentence about cost. Under option (c) the old case is judged at the next dawn, so it costs credibility only if it still looks wrong then, and the existing dawn messages cover that.
- **Meeting button:** "Take back a case…" opens the card picker, filtered to live filed cases. The confirm step reads: "Take back case #N in public? If the town still thinks it was wrong at dawn, it may cost you some of their trust."
- **Refusals** (Quill's placeholders, reworded):
  - "Wait until the current presentation ends."
  - "There's no case #N."
  - "Only a case you've filed can be taken back."
  - "Case #N was replaced by case #M. Take that one back instead."
  - "You've already taken back case #N."
- **Revision with new evidence:** when a meeting presentation revises a case the town has heard and cites a card the earlier version didn't, the game first narrates "You stand and revise case #N in light of something new: <the new card, in the board's short form>." It uses `GamePresentation.new_evidence`. A revision without new evidence adds nothing.
- **The mark:**
  - The card list adds "withdrawn on day N", next to "revision of" and "superseded by".
  - Withdrawn cards are greyed: `UITheme.card_color` treats them like deprecated cards.
  - On the board, a withdrawn case gets a "withdrawn" tab and is struck through.
  - In the deductions tray, it is struck through and labelled "withdrawn".
- **New suite:** `tools/test_withdraw_ui.gd`, 11 checks. It covers the command, the narration, each refusal, the card-list mark and the revision narration. It's a UI suite, so it isn't on the fast list.

## Small calls made on Michael's behalf

- **Where the button goes:** at the meeting only, beside "Present a deduction". I'd suggested a button beside each filed case in the Workshop list as well. The deductions tray is drawn by hand with no per-card buttons, so the Workshop takes the command instead. A per-card button there can follow if he wants one.
- **Naming in the revision line:** the narration names the first new card cited. If a revision adds several, only the first is named.

## Measured

- **Suites passed:** `test_withdraw_ui` (new), `test_public_revisions`, `test_ui`, `test_ui_controls`, `test_text_ui`, `test_workshop_live_canvas`, `test_carried_answers` and `test_meeting_flow`.
- **Golden:** identical to `baseline_be621cd` at `--tol 0` on all 5 seeds.
- **Not measured:** no screenshot of the board's struck-through card (the draw code is small and mirrors the badge tabs), and no playtest of the meeting button.
