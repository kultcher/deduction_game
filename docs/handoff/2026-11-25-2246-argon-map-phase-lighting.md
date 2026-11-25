# 2026-11-25, Argon: map phase lighting, pacing hold, top-center clock, hover boxes, and smooth zoom

- **Agent:** Argon
- **Base:** `main` at `3b71bc0e` (`argon/map-phase-lighting`)
- **Status:** PR open against `main`, awaiting green CI and Codex review for merge.
- **Next actor:** Argon (covering merge while Bailiff is paused).

## What changed and why

Presentation-only improvements to the town map and phase transitions (no simulation, belief-model, or golden changes):

1. **Painterly phase-of-day map lighting & curved wave transitions (`ui/map_lighting.gdshader`, `ui/map_lighting.gd`, `ui/map_view.gd`, `ui/main.gd`):**
   - Split `MapView` into a world layer (base map, lots, gallows, buildings, graveyard, cottages, NPC standees) graded by a 3-zone split-tone `canvas_item` shader via `BackBufferCopy` (`COPY_MODE_VIEWPORT`), and `MapUIOverlay` above the shader so plaques, signs, nameplates, badges, markers, and tooltips stay crisp across all phases.
   - Four phase grades: **Morning** (golden hour with cool slate-plum shadows), **Afternoon** (neutral daylight matching the painted map), **Evening** (cool blue-hour twilight), **Night** (moonlit nocturne with Purkinje shift).
   - Curved right-to-left sweeping wave transitions anchored to map UV space with subtle painterly stipple grain (`DAWN_DURATION = 5.55s` indigo → pale violet → pale rose → gold; `DUSK_DURATION = 4.95s` neutral → sunset edge → lavender → blue; `STEP_DURATION = 3.60s`). Snaps immediately on `set_game()` and when `reduced_motion` is enabled.
   - Transitions wait behind cutscenes (`pacing_open`), meetings, and non-approach conversations so the player sees the wave when returning to the map, while NPC approaches let the transition complete off-screen.
2. **Hold new phase until after `PacingOverlay` cutscenes (`ui/main.gd`, `tools/test_control_flow.gd`):**
   - While `pacing_open` is true (execution or night-kill cutscenes queued/playing), `_refresh_all()` holds the old phase's map, clock, actions, and `cast_list`, skips `Actions.sync_approach()`, and blocks map clicks/commands until the cutscene finishes (still allowing condemned last words on the courtroom stage to play first). Fixes morning approaches and morning actions (e.g. Town Hall) triggering before the night cutscene finishes.
   - Updated `tools/test_control_flow.gd` to set `scene.pacing_enabled = false` (matching `test_ui.gd`) for its synchronous multi-night loop.
3. **Top-center 2-line Day & Phase panel and centered header buttons (`ui/main_layout.gd`, `ui/main.gd`):**
   - Removed `day_icon` and `day_label` from the top title bar and placed `DayPhasePanel` (`mouse_filter = IGNORE`, parchment plaque) at the top center of `map_stage` showing centered 2-line text (`Day N\nMorning` / `Afternoon` / `Evening` / `Night`).
   - Added a left expanding spacer in the header bar so the navigation buttons sit centered between `DEMONOLOGIST` and the right-hand controls.
4. **Crisp cyan hover boxes, block-only overview, and smooth `0.48s` zoom (`ui/map_view.gd`, `ui/main.gd`, `ui/main_actions.gd`, `tools/test_town_ui.gd`):**
   - Added rounded cyan outer-border + subtle 2px inner-rim hover highlights (`HOVER_BORDER`, `HOVER_INNER`, `HOVER_OUTER_GLOW`) for blocks in whole-town view and for buildings, cottages/scenes, and NPCs once zoomed in.
   - Suppressed direct NPC and building action-marker hits from whole-town view (`zoom_block == ""`) so players pick a block first, then buildings/NPCs once zoomed in; updated `tools/test_town_ui.gd` to match.
   - Added smooth `0.48s` (`TRANS_CUBIC`, `EASE_OUT`) camera zoom and fading dim frame in `MapView.zoom_to()` (snapping immediately under `reduced_motion`).
5. **Tests (`tools/test_map_lighting.gd`, `tools/ci_fast_suites.txt`):**
   - Added `test_map_lighting` covering shader load, overlay ordering, phase mapping, animated transitions, cutscene deferral, and `reduced_motion` snap, and registered it in `tools/ci_fast_suites.txt`.

## What was measured

- Verified locally (`0` failures): `test_map_lighting`, `test_town_ui`, `test_ui`, `test_ui_controls`, `test_control_flow`, `test_pacing`, `test_approach_vn`, `test_meeting_stage`, `test_day_conversation_view`, `test_playtest_ui_nov22`, `test_burdens_ui`, `test_map_graveyard`, `test_location_art`, `test_place_icons`, `test_buildings_tavern_town_hall`, `test_map_return`.

## Proposed for the backlog

None.
