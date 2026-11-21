# Herald: the daily evil-team guess window (grim reveal stage 1, PR 1 of 3)

**Revised for Michael's corrections (Nov 21, `grim_reveal.md` "Corrections"):**
- there's no fade line;
- the window's locked guesses are the verdict, and there's no end-of-game seal;
- profile picks prefill empty circles, greyed, with a note, and the window never writes back to the profile;
- **the Demon-guess limit (Michael, Nov 21):**
  - the first pick is free, then two changes a case;
  - a change asks first: "Change your Demon selection? You can only do this two times per case. (n change(s) remaining).";
  - clearing a locked Demon counts as a change;
  - with none left, the Demon picker is disabled, with "No changes left this case";
  - Minion picks and types are free;
- **all the window's wording is approved** (Michael: "we can tweak it later if needed").

Sections below that describe writing to the private theory are superseded by this.

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff
- **Zero drift:** UI only

## What changed and why

Michael's answer on the grim-reveal pitch (Nov 21, via Seneschal) replaces the single
end-of-game verdict sheet with a guess the player makes every day.

- **When it opens:** pressing **Close the meeting** now fades the screen to a window first.
  Confirm or Skip, then the meeting closes as before.
  - **Don't ask again this case** turns it off until the next case.
  - The window is also under **More ▾ → Your suspicions** at any time.
- **What it shows:** a Demon circle on top and one Minion circle per Minion in play below it,
  in Michael's triangle. So a 7-NPC town (one Minion) shows two circles and a 10-NPC town
  shows three.
  - Clicking a circle opens a picker with every NPC's portrait.
  - The Demon picker crosses out the people the Demon killed. Minion pickers leave them open.
  - Each circle has a type menu with the script's Demons or Minions. On single-Demon scripts
    the Demon's type is prefilled.
- **Where the guesses go:** into the same private theory the profile panel edits.
  - A circle with a type guesses that type; one without guesses plain "evil".
  - Anyone the player drops from the circles has their evil guess set back to "?".
  - The meeting's close already freezes a dated "before_execution" copy of that theory
    (`GameScreens.capture_prediction`), so each confirmed day is a snapshot with no new
    storage.
- **Bookkeeping only:** no confidence marks (Michael, Q4) and no mechanical effect.

## Small calls made on Michael's behalf (Seneschal's, agreed)

1. **The circle count** follows the script's evil count.
2. **At the end of the game,** the same window, prefilled, will be the sealed verdict sheet.
   That's stage 1's PR 3.
3. **The guesses are stored** as the existing private-theory revisions and pre-execution
   snapshots.
4. **No burden guess** until Burdens ships.

## Wording: drafts awaiting Michael

All of it is in constants at the top of `ui/daily_guess.gd`, so approval is a one-line change
each:
- **the fade line:** "Before the verdict is read, mark who you believe serves the dark.";
- **the title:** "Your suspicions";
- **the circles:** "DEMON" and "MINION", with "Choose…" when empty;
- **the pickers:** "Who is the Demon?" and "Who is a Minion?", "No one", and the tooltip
  "Killed by the Demon; it cannot be them.";
- **the type menu:** "What kind?";
- **the buttons:** Confirm, Skip, "Don't ask again this case";
- **the menu entry:** "Your suspicions".

## Measured

- New `tools/test_daily_guess` (fast list): 34 checks pass, 6 of them for the two Codex findings (a repeated Minion type; an untyped Demon reopening in its circle). It checks the circle count at both
  town sizes, the type menus, the prefill from the theory, apply and clear, the Demon
  picker's crossed-out victims, one person per circle, and that Confirm writes while Skip and
  Don't ask again don't.
- test_ui, test_ui_controls, test_text_ui, test_town_ui, test_control_flow and
  test_withdraw_ui pass.
- **Golden:** not captured. Only `ui/` changed, which the capture never loads, and
  `set_guess` is unchanged. CI checks it.

## Next

- **PR 2 (Limner):** the `RevealCard` scene, the card reel, about 3 s.
- **PR 3 (Herald):** the reveal overlay and final screen.
  - **One wrinkle there:** `set_guess` refuses once the game is over, so the end-of-game seal
    has to open before the outcome is applied, or seal through its own path.

## Proposed for the backlog

None.
