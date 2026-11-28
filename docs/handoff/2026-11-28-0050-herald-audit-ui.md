# Herald: the release audit's UI fixes (items 1–5)

- **Agent:** Claude-Herald
- **Base:** main, merged in after #561 and #565. UI only, zero drift.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

These are the fix-as-you-go UI items from `docs/maintenance/codebase_and_release_audit_2026-11-27.md`. Michael OK'd them on Nov 27, via Seneschal.

1. **Inline icons survive export.** `ui/text_terms.gd` checked for role and burden icons with `FileAccess.file_exists`, which is false in an exported PCK, where only the imported resource remains. Every inline icon would have vanished. It now uses `ResourceLoader.exists(path, "Texture2D")`, as `inline_icons.gd` already did.
2. **Popups open where the pointer is.** Six call sites passed OS screen pixels to embedded popups, which take viewport units. They only agree at 1080p, 100% scale, fullscreen. A shared `ColumnMenus.popup_point(ctrl, local)` uses the same rule as `main_pickers.gd`'s anchor. It's used by `daily_guess.gd`, `board_view.gd`, `card_list.gd`, `deduction_tray.gd`, `profile_panel.gd` and `trait_bars.gd`.
3. **Esc steps back one level.**
   - **The Case board:** it took Esc in `_input`, before the Workshop canvas could cancel with it. It now handles Esc in `_unhandled_key_input`.
   - **The canvas:** it cancels a link, a group or a box selection and keeps the key. With nothing to cancel, the key goes on to the board.
   - **The board:** a fullscreen Workshop shrinks first, then the board closes.
   - **The command line:** `main.gd` no longer pulls focus to it under the pacing sequence, the New Case screen or the grim reveal.
4. **A new case starts clean.**
   - **What `_new_case()` clears:** any pacing, reveal or guess-window overlay left from the last case. It also resets the deferred reveal, the guess window's flags, the meeting's held events, the meeting's map peek and the approach.
   - **The guess window:** `_run` waits, and `_presenting` reports true, while it's up.
5. **The texture caches stay bounded.** This one was agreed with Limner.
   - **The leak:** `UITheme.nine()` and the `tex()` cache it fills kept every size map zoom asked for, so the caches grew without limit.
   - **Rounding:** heights and margins are now rounded to whole pixels, before both the key and the resize, so equal keys make equal art. Limner's suggestion.
   - **Caps:** both caches are capped and evict the oldest entry first. The limits are 96 boxes and 256 textures.
   - **Not here:** sharper plaques at 1440p and 4K are a separate art job, and Limner is proposing it.

## Measured

- **New suite:** `test_audit_ui`, 18 checks, in the fast list.
- **Updated:** `test_ui` calls the board's new Esc handler.
- **Passing locally:** test_ui, test_ui_controls, test_daily_guess, test_grim_reveal, test_control_flow, test_term_defs, test_pacing, test_board, test_board_fixes_marks_crowd, test_text_terms, test_workshop_canvas, test_workshop_live_canvas, test_map_lighting, test_town_ui, test_map_return, test_location_art, test_place_icons, test_map_graveyard and test_call_on. After the merge with main: test_day_plaque.
- **Not checked by eye:** the popup positions at other resolutions; the math is unit-checked. Michael's new rule is to check new UI at 1280×800 too. This PR adds no new UI, but its popups are what that rule protects.
