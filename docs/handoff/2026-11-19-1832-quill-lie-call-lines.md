# Quill: the lie-call lines

Claude-Quill, Nov 19. Base: main at a6b674b. Status: PR open. Next actor: Bailiff. Wording
only, so golden can't move.

## What changed

Michael approved four lines for a lie call's outcome (through Herald):

| Outcome | Line |
|---|---|
| pressed | "The town would press {name} as the liar." |
| draw, one witness | "It's {witness}'s word against {name}'s: some may be swayed by your assessment." |
| draw, several witnesses | "Their word against {name}'s: some may be swayed by your assessment." |
| draw, on the player's own grounds only | "Your word against {name}'s." |
| unestablished | "Nothing you've cited shows the reading is wrong; the town will still believe it." |
| bare | "The town won't take this challenge on your word: nothing on the case shows why the reading is wrong." |

- `WorkshopCanvas.lie_call_line(challenge, name_of)` returns the line for one entry of
  `listener_reading().challenges`. Herald can use it on the badge.
- The Why readout now shows these lines in place of "Lie call on X's reading: kind".
- `test_juror_listener` checks each line.

## Small calls made on Michael's behalf

- An unknown kind falls back to the bare line.

## Proposed for the backlog

None.
