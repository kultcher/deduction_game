# Burdens UI screenshots (Limner, Nov 21)

These are screenshots of Herald's Burdens UI on `mock/burdens-slot` at `f7c971db`, for
Michael's morning review. Seneschal asked for them. This is a mock branch: it never merges.

## How they were taken

- **Setup:** the real `ui/main.tscn` with a 10-person case, number 1, whose script lists
  Delusional, Marked, Unrequited and Ill-Omened. The window was 1920×1080, rendered in a
  real renderer (opengl3 under xvfb). The tooltips are real hovers, made with mouse events.
- **What was staged** (playing to these moments would take a full game):
  - the burden claims;
  - the Ill-Omened hanging: the clock was moved to the second day's evening, an
    `omen_hanged` event was logged, and the game's own `_omen_marker` was called;
  - the game's end. In this case Kiran is the one burden holder and is really Unrequited.
    For the reveal shot his burden was changed to Delusional.
- **The script:** `capture_script.gd.txt`. Run it from a checkout of the branch.

## Screens and verdicts

| File | Shows | Verdict |
|---|---|---|
| `1_script_sheet` | The sheet: the "Burdens" heading, "Hidden:" on Delusional, the new Unrequited and Ill-Omened icons, a double Unrequited claim (both to the town) and an Ill-Omened claim told to the player | Clean. Nothing clipped; the icons sit in their violet tint with the others. |
| `2a_script_text`, `2b_burden_tooltip` | The text `script` command in the log; the "Burden" tooltip on its "Burdens" line | Works. Near the bottom of the log, the tooltip's last line runs off the screen. |
| `2c_delusional_tooltip` | A burden's own tooltip in prose | Clean. |
| `3a_omen_log`, `3b_omen_tooltip` | The marker's narration, and "omen" showing Ill-Omened's rules text | Clean. |
| `3c_case_board`, `3e_board_card_hover` | The `omen` card in the Process view, and hovering it | Shows, but the card cuts to "The omen claimed by Dorian may …". Its hover is the plain card tooltip, with no omen rules text. The card sits only in that evening's column. |
| `4a_reveal_landed`, `4b_reveal_tag` | The card reveal, then the "…and Delusional" tag | Works. Two problems: the first key-moment line is hidden behind the bottom edge of the reveal sheet, and the tag's right end overlaps the card's left edge slightly (the second is mine). |
| `4c_reveal_final` | The final grid: "Veteran, Good · Delusional" | Clean. |

## Wording leftovers noticed in passing (not broken)

- **Rumormonger:** its rules text still says "carries a particular secret".
- **Profile:** the guess row is still labelled "Secret:".
- **New Case screen:** the summary says "4 secrets".
- **The text `script` command:** its line "Burdens (one in play, …)" hard-codes "one" and
  has no "Hidden:" tag.
- **The sheet's heading:** it is a plain label, so "Burdens" has no tooltip on the sheet
  itself. The term's tooltip appears only in prose.
