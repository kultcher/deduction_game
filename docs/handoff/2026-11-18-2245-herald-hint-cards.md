# 2026-11-18, Claude-Herald: hint-family card forms, two families' voice lines, and the "weakens" warning (`claude/herald-hint-cards`)

- **Base:** main after #263 and #275. **Status:** PR open, zero drift. **Next actor:** Bailiff.
- **Source:** Michael's hint-family names (Nov 18, through Seneschal), built in Quill's #263. Michael's approved wording "This weakens your previous case", whose detection is Quill's #275.

## What changed

- **Card forms.** Each hint family in `C.HINT_PACKAGES` gains a `card` field, the board's short form:
  - official business
  - the town's affairs
  - night sight
  - the dead
  - shelter
  - reading people
  - the gallows
  - true callings
  - searching
  - light against dark
  - cheating death

  `CardModel.short_text` reads it. A hint card says "Lian hints: the gallows", and tavern gossip says "Rumour: Lian, the gallows". The six new families previously fell back to the full sentence.
- **Voice lines (`sim/dialogue_voices.gd`).** All 15 voices change for two families:
  - Shelter now includes the Demon's servants (for the Sexton): "…shelter against the Demon and those who serve it", in each voice's own phrasing.
  - Reading people no longer depends on being close ("if I'm close enough", "up close", "at close range"). Each voice now speaks of reading people "for what they truly are", following Michael's approved base line.
  - The new families still use their base line, as Michael asked.
- **The warning.** When the player files a revision that the Test juror finds weaker than the case it replaces, the Workshop's status line now starts with "This weakens your previous case." The revision still files.
- **New suite:** `tools/test_hint_cards.gd`, 33 checks: every family has a card form, and both hint wordings use it. It's quick but not a judge, solver or role test, so I didn't add it to the fast list.

## Small calls made on Michael's behalf

- **Rewording in voice.** The shelter and reading-people lines were rewritten in each voice's existing style, not set to the base line word for word. Two voices also lost modern or game words while I was in those lines: "label" and "role" became "name" and "gift", and "slot" and "category level" were reworded.
- **The warning's placement.** It goes at the start of the filing status line, as plain text without the two chances. The numbers would read as data.

## Measured

- **Suites passed:** `test_dialogue_voices`, `test_dialogue`, `test_hint_cards` (new), `test_carried_answers`, `test_workshop_live_canvas`, `test_text_ui` and `test_roles_registry`.
- **Golden:** identical to `baseline_e287b3d` at `--tol 0` on all 5 seeds. The passive player never hears these lines.
