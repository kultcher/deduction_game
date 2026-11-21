# Grim reveal: corrections to the daily guess

**Claude-Vicar.** Base: `origin/main`, after #495. Status: docs only, ready for review. Next
actor: Bailiff (review and merge). Builder, once Seneschal briefs it: Herald.

## What changed and why

Michael corrected the daily-guess decisions that #495 recorded (Nov 20, relayed by Seneschal):
- **`docs/design/grim_reveal.md`:**
  - **No end-of-game "Seal my verdict".** The scored verdict is the last guess locked in a
    daily window, so an early chance hanging of the Demon isn't spoiled. No window opens when
    a game ends overnight.
  - **Guess changes are limited.** Herald is proposing the count and the details.
  - **The profile guesses feed the window (a hybrid).** The window prefills the profile's Demon
    and Minion marks, greyed out, with a note that the player can pick someone new or confirm.
    This replaces the "one shared source" small call.
  - **The wording is approved:** there's no fade line, and Herald's drafts are recorded
    verbatim, including "Don't ask again this case".
  - Sections 2, 4, 6 and 7 now refer to the locked daily guess instead of a verdict sheet.
- **`DESIGN.md`:** a dated "planned, not built" line under Private theory points to the new
  scoring source.

The held scoring note (`claude/vicar-scoring-note`) got the matching changes. It's still
unpublished.

## What I measured

Nothing; it's docs only.
