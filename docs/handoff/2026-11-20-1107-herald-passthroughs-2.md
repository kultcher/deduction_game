# Herald: point game/ and ui/ at game.gd's modules (passthroughs, PR 2 of 3)

- **Agent:** Claude-Herald
- **Base:** main
- **Status:** PR open
- **Next actor:** Bailiff

## What changed and why

This is the second of three PRs removing game.gd's one-line forwards (Michael, Nov 19; Seneschal's go, Nov 20, once #394 merged). PR 1 (#385) deleted the 25 that nothing called. Zero drift.

- **Repointed:** every caller in game/, sim/ and ui/ of 82 forwards now calls the module that does the work. For example, `g._facts(x)` becomes `GameBoard._facts(g, x)`, and inside game.gd `_ending()` becomes `GameScreens._ending(self)`. That's 153 call sites in 12 files, with 23 module preloads added where a file didn't have one.
- **Deleted:** the 20 forwards that now have no caller anywhere, tests included: `_disclosure`, `workshop_canvas_retire`, `_present`, `_day_command`, `_end_phase`, `_night_command`, `_maybe_approach`, `_greeting_context`, `_talk_command`, `_remember_spoken_relationship`, `known_haunt_names`, `_show_nomination`, `_nomination_command`, `_secrets_used`, `_ward_context_card`, `_intro`, `_look`, `_ending`, `_exchanges`, and `_last_words` (its one caller, a callable, was repointed by hand).
- **Left for PR 3:** the other 62. Only tests and tools still call them, and PR 3 repoints those and deletes them.
- **Kept on purpose:** the 23 forwards with public names that ui/ calls, the game's interface for the UI and CLI: `already_public`, `can_see`, `can_see_ui`, `debug_card_text`, `debug_npc_text`, `delete_deduction`, `filter_cards`, `hide_card`, `meeting_streaming`, `offer_text`, `on_deck_case`, `profile_data`, `protection_label`, `set_debug_overlay`, `set_guess`, `set_secret_guess`, `testimony_step`, `theory_status`, `unseen_at_ui`, `vote_requirement_text`, `workshop_ghost_preview`, `workshop_preview`, `workshop_retract`. PR 3 adds a header in game.gd naming them.
- **Built by script:** `repoint.py`, against main just before opening. It rewrites only code, never strings or comments. One callable reference was repointed by hand: `g.w.end_meeting(g._last_words)` became `g.w.end_meeting(func(n): _last_words(g, n))` in game_meeting.gd.
- **Preload cycles:** some game modules now preload each other (game_board and game_meeting, for example). Godot accepts these: every changed file parses with `--check-only`, and the import is clean.

## Measured

- **Golden:** identical at `--tol 0` on all five seeds.
- **CI fast list:** 152/152 pass locally, after merging main (with #397's new baseline_58cb94a).
- **After merging #416:** the script finds no new callers. test_workshop_live_canvas, test_workshop_live_ui, test_premise_step1, test_badge_text, test_points_elsewhere, test_presentation_contracts and test_control_flow pass.
- **The 87 suites on neither CI list** (the kind that let #395's test_social_credibility failure through): 85/87 pass on the branch's first base. The two failures, test_social_credibility and test_own_gift_doubt, failed on that base too, and #419 and #397 have since fixed them. Both pass after merging main.

## Proposed for the backlog
None.
