# "Are you the <gift>?": a right guess reads like a wrong one, with a nervous tell

- **Agent:** Claude-Beadle
- **Base:** main at `86f0ed23` (`baseline_1bf8a4b`)
- **Branch:** `claude/beadle-guess-tell`
- **Status:** PR open. Golden unmoved (all five seeds identical at `--tol 0`).
- **Next actor:** Bailiff (review and merge).
- **Item:** playtest 52102, finding 6. Michael approved the proposal (Nov 27, via Seneschal).

## What changed (`Social.answer_is_role`)

- **A right guess short of owning up gets the same deflection as a wrong one:** the voice's
  guess line, with no hint replayed. Before, a right guess at the hint tier replayed the hint,
  which told a right guess from a wrong one.
- **A willing NPC still owns up to a right guess,** at the gift tier or above, as before,
  including the first-guess bonus (`CORRECT_ROLE_GUESS_BONUS_PROB`).
- **The tell:** either guess may show one of the press's four nervous cues ("looks away a moment
  too quickly" and the rest), at `PRESS_NERVES_HIDING` (0.6) for a right guess or
  `PRESS_NERVES_HONEST` (0.2) for a wrong one, × (1 − Composure) × `GUESS_NERVES_STRENGTH` (0.5,
  new, approved).
  - So a rattled NPC shows one on about 3 in 10 right guesses and 1 in 10 wrong ones; a composed
    one rarely does either way. A lean, never proof.
  - The roll is the NPC's own seeded draw, so a guess never moves the world's stream (an existing
    check: "wrong-guess wording introduces no random choice").
- **Wrong guesses** keep their trust cost and wording.

## Open with Michael

- **Whether a right guess gives a lasting nudge toward disclosing later.** Today it doesn't; it
  only affects that one answer. A proposal is with Seneschal: a half-strength press's pressure
  (existing values, no new constant). It isn't built.

## Measured

- **New:** `tools/test_guess_tell.gd`, 6 checks, on the slow CI list (about 70 seconds):
  - closed NPCs: a right guess read exactly as a wrong one in 30 of 30, with no hint or claim;
  - willing NPCs owned up to a right guess in 20 of 20;
  - at no Composure, a tell on 19 of 60 right guesses (0.32; approved rate 0.30) and 9 of 60
    wrong ones (0.15; approved rate 0.10); at full Composure, 0 of 60.
- **Also pass:** test_conversation_gifts, test_dialogue_voices, test_bot_m4.
- **Golden:** identical to `baseline_1bf8a4b`. The golden bot doesn't guess gifts.
- **No new lines:** the deflections and cues already exist.

## Proposed for the backlog

None.
