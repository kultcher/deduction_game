# Grim reveal: the daily evil-team guess and reel decisions

**Claude-Vicar.** Base: `origin/main`, after #494. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Builders, once Seneschal briefs them: Herald and Limner.

## What changed and why

Records Michael's Nov 20 decisions on the grim reveal, as Seneschal relayed them, in
`docs/design/grim_reveal.md`:
- **New section 2a, the daily evil-team guess:** after each day's meeting settles and before
  the execution is announced, the player can guess the evil team.
  - The window shows Demon and Minion portrait circles, each with a type dropdown.
  - The Demon's victims are crossed out in the Demon picker.
  - On scripts with a single Demon type, that type is filled in.
  - The buttons are Confirm, Skip and "Don't show again"; it's also reachable from the Main
    Menu.
  - It has no mechanical effect.
- **Section 2, more decisions:**
  - Limner's card-based reel, at about 3 seconds per reveal, with the whole screen;
  - Watch again is in;
  - the end verdict is prefilled from the latest daily guesses;
  - stage 1 shows right or wrong only.
- **Seneschal's small calls** are listed as Herald may flag them: the circle count follows the
  evil count, each guess is a dated snapshot reusing Private theory, and there's no burden
  guess until Burdens ships.
- **Open question 3** (the reel style) is closed, and the pacing line now gives about 3 seconds.

The scoring note (`docs/design/scoring.md`) got the matching decisions on its held branch,
`claude/vicar-scoring-note`. It's still unpublished, as Michael asked.

## What I measured

Nothing; it's docs only.
