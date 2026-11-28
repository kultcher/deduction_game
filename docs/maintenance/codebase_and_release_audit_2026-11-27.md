# Demonologist — Comprehensive Code Review & Release-Readiness Audit

*Date: 2026-11-27 · Scope: Read-only audit of `sim/`, `game/`, `workshop/`, `ui/`, `project.godot`, `Demonologist.csproj`, and `assets/` (~88k LOC production code, ~62k LOC `tools/`).*

---

## Executive Summary

The core simulation and deduction engine are well-tested and clean in key areas (zero `res://` writes, minimal `print()` noise, strong test coverage). The highest-risk issues fall into three buckets:

1. **Exported-build blockers (P0):** Inline role/burden icons will vanish in exported PCKs (`FileAccess.file_exists` on imported PNGs), missing export/icon/splash/version config, unignored dev/test/scratch directories (`tools/`, `Claude outputs/`, `docs/`) + ~378 MB of lossless PNGs, zero UI for audio or display/window settings, and a release-mode crash path if the C# assembly fails to load (`assert()` stripped in release).
2. **Multi-resolution & input bugs (P0–P1):** Six popup call sites pass OS screen pixels instead of logical viewport coordinates (breaking right-click menus and pickers on 720p, 1440p/4K, HiDPI, and windowed mode); `1920×1080` + `aspect="expand"` stretches 21:9 ultrawide layouts and shrinks 720p/Steam Deck fonts to 7–10 physical pixels; `KEY_ESCAPE` in `ui/case_view.gd` kills Workshop canvas cancellation; and `UITheme` leaks Lanczos-resized textures on every map zoom frame.
3. **Architectural & correctness debt (P1–P2):** Unretired GDScript/C# solver mirrors with hand-copied tuning constants and wire protocols; five static caches missed by `WorkshopCaches.clear_all()` (including a cross-case stale-result bug in `_names_evil_cache`); default-on `DevLog` deep-copy tracing + unconditional 3-file log dumps on every case ending; and fragmented modal state flags in `ui/main.gd`.

---

## Part 1: Release Readiness & Packaging

### P0 — Release Blockers (Will Break Exported Builds or Prevent Shipping)

1. **Inline role & burden icons silently vanish in exported PCKs**
   - `ui/text_terms.gd:31,42` calls `FileAccess.file_exists(path)` on `res://assets/ui/roles/%s.png`. Exported PCKs strip raw `.png` files and keep `.png.import` + `.godot/imported/*.ctex`, so `file_exists()` returns `false` and every inline icon becomes `""`.
   - **Fix:** Use `ResourceLoader.exists(path, "Texture2D")` (matching `ui/inline_icons.gd:12`).

2. **Missing export presets, app metadata, and release-mode C# failure handling**
   - No `export_presets.cfg` exists. `project.godot:15-20` lacks `config/icon`, `boot_splash/image`, and `config/version`.
   - `Demonologist.csproj:1-10` is bare `net8.0`; desktop players will need the bundled `data_Demonologist_<arch>` folder (or self-contained `.NET 8` runtime publishing).
   - If the C# `SolverBridge` fails to load, `workshop/solver_backend.gd:31-46` shows a dev-only message (`"dotnet build Demonologist.csproj -c Debug"`) and calls `assert(false, ...)`. Because `assert()` is stripped in release exports, execution continues with `_cs_bridge == null` and crashes with a null-dereference at `workshop/solver_backend.gd:102` instead of exiting cleanly.

3. **Dev/test/scratch bloat leaks into exported PCKs**
   - Unignored directories at repo root: `tools/` (319 test/harness scripts; `tools/golden/` is `.gdignore`d), `Claude outputs/` (**68 MB**, 46 files), `docs/` (**3.5 MB**, 518 files), `tests/` (2 files), plus orphaned `out.png.import:13` (references nonexistent `res://out.png`) and root markdown files (`CLAUDE.md`, `BACKLOG*.md`, `DESIGN.md`, etc.).
   - **Fix:** Add `.gdignore` or `export_presets.cfg` `exclude_filter` rules and remove `out.png.import`.

4. **No audio controls in UI (and no SFX)**
   - `ui/soundtrack.gd:83-99` implements `set_volume_db()` / `set_enabled()` and persists to `user://settings.cfg`, but **zero UI code calls `Soundtrack`**. Players cannot mute or adjust music in-game.
   - No `default_bus_layout.tres` exists (bus `"Music"` is created dynamically at `ui/soundtrack.gd:108-115`), and there are no SFX anywhere in the repo.

5. **Hardcoded fullscreen & missing Settings menu**
   - `project.godot:30` locks `window/size/mode=3` (Fullscreen) with no UI to switch Windowed / Borderless / Fullscreen, pick resolution, or adjust UI scale.
   - `reduced_motion` (`ui/main.gd:311-314`) is never persisted to `user://settings.cfg` and resets to `false` on every launch.
   - `show_script_at_start` (`ui/main.gd:91`) is hardcoded `true` with no toggle or persistence.

---

### P1 — High-Priority Release Gaps

6. **No mid-case Save/Load and no Quit Confirmation**
   - There is no mid-case save/autosave/resume.
   - The Case Notes window (`ui/main_layout.gd:300-308`) displays `"Your notes on the case (saved as you type)"`, but only writes to in-memory `g.case_notes` — lost on quit.
   - `More ▾ → Exit Game` (`ui/main.gd:315-316`) quits immediately with no confirmation, and `NOTIFICATION_WM_CLOSE_REQUEST` is unhandled.

7. **Developer / playtest tools exposed in production UI**
   - Top bar exposes `Debug` checkbox (`ui/main_layout.gd:87-95`) — which unlocks NPC private thoughts, `Rolls` feed, mid-case `grimoire`, Workshop `Debug ▾`, and `PlaytestMarks` — plus a redundant `Case` seed `SpinBox` (`ui/main_layout.gd:54-62`).
   - `More ▾ → Write dev log` (`ui/main_layout.gd:77`) and the bottom raw CLI `LineEdit` + `Send` bar (`ui/main_layout.gd:259-266`) remain visible to players and expose dev commands (`log`, `fallbacks`, `grimoire`).
   - *(Note: `Case Workshop`, `Trace Solver`, and `Whereabouts` are intentional player features and should stay.)*

8. **Default-on dev logging & unconditional file dumps on every case ending**
   - `game/game.gd:118` enables `detailed_logging = true` and `game/game.gd:388` enables `state_digests = true` by default — deep-copying 41 NPC fields per snapshot into an unbounded `_trace["events"]` array (`sim/devlog.gd:49-134`).
   - On every case ending, `game/game_screens.gd:368-374` writes 3 files to `user://logs` with no rotation and prints `"Dev log written: <OS path>"` directly into the player's narrative log.

9. **Missing Title Screen, How-to-Play, Credits, and Version**
   - Game launches directly into `main.tscn` covered by `NewCaseScreen` (`ui/main_layout.gd:368-372`) — no title screen / main menu.
   - `Help` (`ui/main_layout.gd:50`) prints a CLI command cheat sheet into the log (`game/game_screens.gd:32-63`) rather than a player-facing rules guide.
   - No Credits, third-party licenses (Godot / .NET / art / music), or visible version number (`sim/build_info.gd` reads `.git/HEAD`, which is empty in exports).

---

### P2 — Asset Bloat & Cross-Platform Hygiene

10. **~378 MB of lossless PNGs + unreferenced POC art**
    - Active `assets/` contains 512 lossless PNGs (`compress/mode=0`, `size_limit=0`) totaling **378.55 MB**, including:
      - `cast_expressions/` (**165.7 MB**), `portraits_vn_cast/` (**29.3 MB**), `portraits_vn_poc/` (**7.1 MB**), `portrait_expression_poc/` (**10.5 MB**). `ui/vn_portraits.gd:8-24` `preload()`s all 15 old PNGs at startup even when `portraits_paper/*.webp` overrides them, and `cast_expressions/<id>/neutral-v1.png` duplicates `portraits_vn_cast/<id>-vn-v1.png`.
      - Unreferenced POC folders still in `assets/art/` without `.gdignore`: `trace_items_poc/` (**39.6 MB**) and `edda_ink_overlay_poc/` (**1.65 MB**).
    - Switching to Lossy WebP / VRAM compression with sensible size limits and pruning unused/duplicate POC folders will shrink the build dramatically and cut RAM/VRAM usage.

11. **No bundled fonts (cross-platform layout risk)**
    - `ui/theme.gd:145-146` and `ui/main_layout.gd:24-25` rely exclusively on `SystemFont` (`Georgia`, `Consolas`, `DejaVu Sans Mono`). On Linux/Steam Deck or systems missing those fonts, metric differences can clip fixed-size plaques and labels.

---

## Part 2: Resolution, Aspect Ratio & DPI Scaling

Current display config (`project.godot:28-32`): `1920×1080`, `mode=3` (Fullscreen), `stretch/mode="canvas_items"`, `stretch/aspect="expand"`.

| Issue | Severity | Where | Effect |
|---|---|---|---|
| **Embedded popup coordinate bug** | **Critical** | `ui/daily_guess.gd:391`, `ui/board_view.gd:889`, `ui/card_list.gd:35`, `ui/deduction_tray.gd:119`, `ui/profile_panel.gd:224-227`, `ui/trait_bars.gd:38-41` | Passes OS screen-pixel coords to embedded `Popup.popup()` instead of logical viewport coords (unlike `ui/main_pickers.gd:47`). Invisible at 1080p 100% fullscreen, but **misplaces or clips right-click menus and pickers** on 720p, 1440p/4K, HiDPI (125–200%), and windowed mode. |
| **21:9 ultrawide distortion** | **High** | `ui/main_layout.gd:117-270`, `ui/meeting_view.gd:246-247`, `ui/day_conversation_view.gd:106-126`, `ui/courtroom_stage.gd:119-202`, `ui/new_case_screen.gd:179-182` | Under `aspect="expand"`, fixed-width sidebars dump ~660px into the center stage: `MeetingView` becomes a ~3.3:1 squashed oval, VN speech bubbles stretch to ~935px wide, and `NewCaseScreen`'s `marks_panel` stretches to ~1840px wide (while crushing on narrow widths). |
| **720p / Steam Deck (1280×800) tiny text** | **High** | `ui/trace_solver_panel.gd:95-98` (11px), `ui/cast_list.gd:94` (13px), `ui/trait_bars.gd:83` (13px), `ui/main_roles.gd:177-192` (13–14px) | Scales to 0.667× at 720p/800p → **7.3–9.3 physical pixels**, below readable thresholds on 7" screens or 1366×768 laptops. |
| **Unclamped windows & stale resize geometry** | **High** | `ui/main_layout.gd:310`, `ui/main_roles.gd:46`, `ui/main.gd:808-809`, `ui/pacing/pacing_overlay.gd:321-325`, `ui/fx/kill_wheel.gd:211-212`, `ui/reveal/reveal_overlay.gd:229-268` | `roles_win` (`1160×960`) uses `popup_centered()` instead of `popup_centered_clamped()`; multiple toasts stack at `y -= 160`; `WheelHolder` and `kill_wheel` flash size never update on window resize; `TruthGrid` lacks `SIZE_EXPAND_FILL`. |
| **Texture-resize cache leak & HiDPI softness** | **Medium-High** | `ui/theme.gd:51-98`, `ui/map_view.gd:407`, `ui/map_lighting.gd:35` | `UITheme.nine()` caches CPU-resized textures keyed by float height forever — `map_view.gd` calls it during every frame of `zoom_to()`, leaking dozens of textures per zoom. Pre-downscaling plaques to 34px blurs them on 1440p/4K. `BackBufferCopy` runs even during static Afternoon (a shader no-op). |

---

## Part 3: UI Architecture, Input & Focus Fragility

1. **Fragmented modal state machine in `ui/main.gd`**
   - Nine independent flags/checks govern modal blocking (`conversation_finished`, `_phase_held`, `pacing_open`, `daily_guess_open`, `conversation_show_map`, `meeting_show_map`, `approach_stage`, `inspect_pages`, plus overlay visibility).
   - **Active bugs from this split:**
     - `_run()` (`ui/main.gd:383`) and `_presenting()` (`ui/main.gd:461-464`) omit `daily_guess_open`.
     - `_new_case()` (`ui/main.gd:244-283`) fails to reset `_deferred_meeting_events`, `meeting_show_map`, `approach_stage`, `_approach_key`, `_reveal_after_pacing`, `daily_guess_open`, `daily_guess_off_for`, `reveal_seen_for`, or free active modal overlays.
     - `ui/main_actions.gd:97-114` temporarily mutates `m.actions = m.conversation_view.controls` and swaps it back — fragile under any early return.

2. **Broken `KEY_ESCAPE` precedence & focus stealing**
   - `ui/case_view.gd:514-517` intercepts `KEY_ESCAPE` in `_input()` and marks it handled, so `ui/workshop_canvas_view.gd:626` (`_gui_input()`) **never receives Escape** — making `"Esc cancels"` dead code and closing the entire Case Board instead (also leaving fullscreen `ui/workshop_drawer.gd:107-111` stuck at `top_level = true, z_index = 50`).
   - `ui/main.gd:284-286` focuses the command `LineEdit` on `KEY_ESCAPE` even when `pacing_open`, `new_case_screen`, or `GrimReveal` is open.

3. **Uncoordinated z-order, mouse-only progression, and accessibility gaps**
   - `headlines` sits on `CanvasLayer(layer = 30)` (`ui/main_layout.gd:358-360`), floating above `CaseView`, `NewCaseScreen`, `DailyGuess`, and `GrimReveal` (only `PacingOverlay` manually hides it).
   - VN/Courtroom/Reveal views only advance on left mouse click (no Space/Enter), `ui/theme.gd:190-226` strips all `"focus"` styleboxes (blinding keyboard/Tab navigation), and `ui/board_panel.gd:39-46` wraps inner scrollable controls in an outer `ScrollContainer` (nested scroll-wheel traps).
   - `ui/day_conversation_view.gd:74-153` and `ui/courtroom_stage.gd:79-167` duplicate inline blur shaders, speech-bubble styles, portrait crossfades, and typewriter loops.

---

## Part 4: Sim, Game & Workshop Architecture

### Redundancies & Mirror Drift

1. **Unretired GDScript/C# solver mirrors & hardcoded tuning constants**
   - Despite `workshop/solver_backend.gd:1-3` declaring GDScript kernels retired, active mirrors remain in `workshop/live_activity_profiles.gd:42-94`, `workshop/case_eval.gd:148-175`, `workshop/case_eval_classes.gd:659`, `workshop/solver.gd:931-940`, and `workshop/role_constraints.gd:543`, plus ~150 lines of dead `ModeGdscript`/`ModeVerify` scaffolding in `workshop/cs/SolverBridge.cs:9-32`.
   - `workshop/cs/LiveActivity.cs:43-49` hardcodes manual mirrors of tuning constants from `sim/tuning.gd:1178-1202` — any tuning tweak in GDScript silently drifts from C#.

2. **Hand-mirrored integer/bitfield wire protocols (no shared schema)**
   - Burden/modifier integer codes are defined independently in 4 files (`workshop/solver_backend.gd:61-74`, `workshop/solver.gd:107-120`, `workshop/role_constraints.gd:62`, `workshop/cs/SolverContext.cs:22-28`).
   - Flat `int32` strides and bitmasks (24-int stride / 20 flags in `RoleConstraints`, 20-int stride / 17 flags in `LiveActivity`) are hand-synced across GDScript and C#.

### Fragile Coupling & Awkward Architecture

3. **Scattered hardcoded role checks defeat `RoleRegistry`**
   - Hardcoded role-name switches span 10+ files across `sim/`, `workshop/`, `workshop/cs/`, and `game/` (e.g., 26 matches in `workshop/solver.gd`, 13 fixed role constants in `workshop/cs/RoleConstraints.cs`, 8 movement role codes in `workshop/cs/LiveActivity.cs`).

4. **Deep static-inheritance chains, ~40 runtime `load()`s, and layer inversions**
   - Five major namespaces use 4–5 level linear `extends` chains (`mind`, `live_activity`, `case_eval`, `social`, `world`) solely to split large files while preserving `ClassName.fn()` call sites, combined with ~40 runtime `load("res://...")` calls to sidestep circular preloads (including `sim/evil.gd:1456` loading itself).
   - **Layer inversions:** `workshop/connections.gd:1800-1801` loads `res://game/profile_judge.gd`, and `sim/` reaches into `workshop/` in 11 places. Extracted `game_*` modules reach into `Game`'s private `_` fields/methods 326+ times.
   - **God-objects:** `workshop/cs/LiveActivity.cs` (2,626 lines), `workshop/solver.gd` (2,114 lines), `sim/evil.gd` (1,460 lines), and `game/workshop_canvas.gd` (1,402 lines).

### Correctness & Performance Hazards

5. **Stale cross-case cache leaks (`WorkshopCaches.clear_all()` misses 5 static caches)**
   - `workshop/caches.gd:26-84` omits `RoleConstraints._names_evil_cache`, `RoleConstraints._burden_share_cache`, `CaseEval._own_delusion_weight_cache`, `SharedLedger.last_reason_ctx` / `last_adjusted`, and `SolverBridge._lastOwnWeights` (`workshop/cs/SolverBridge.cs:38-47`).
   - **Active bug:** `_names_evil_cache` (`workshop/role_constraints.gd:759-788`) keys only on `[universe_key, card.id, who]` without card content — across two cases in one session with matching cast/modifiers, colliding card IDs silently return stale booleans from the previous case.

6. **Synchronous UI-thread solver fan-out & hot-path overhead**
   - `game/workshop_canvas.gd:1204-1250` (`connections`) runs `test_juror` synchronously up to 21 times on the main thread, deep-copying and re-snapshotting each iteration.
   - `workshop/world_domain.gd:10` and `workshop/solver.gd:29` run deep array-of-dicts equality (`view.people != _cached_people`) on every `person_index` lookup.
   - `workshop/world_domain.gd:138-156` marshals 8 arguments across the C# boundary for a trivial boolean `gift_time` check.

---

## Suggested Phased Roadmap

1. **Phase 1 — Quick Correctness & Export Blockers (1–2 days)**
   - Fix `ui/text_terms.gd` `FileAccess.file_exists` → `ResourceLoader.exists`.
   - Fix the 6 embedded popup coordinate call sites + `KEY_ESCAPE` in `ui/case_view.gd` / `ui/main.gd`.
   - Fix `WorkshopCaches.clear_all()` missed caches + `_names_evil_cache` key bug + `_new_case()` state reset.
   - Gate `detailed_logging` / `state_digests` / end-of-case log dumps behind a debug flag; gate `Debug` / `Write dev log` / raw CLI behind a dev-build toggle (`OS.is_debug_build()` or launch flag).
   - Add `.gdignore` / export exclude filters, delete `out.png.import`, and add a clean fatal-error exit if `SolverBridge` fails to load.

2. **Phase 2 — Multi-Resolution, Settings & Packaging (3–5 days)**
   - Add an in-game **Settings** panel (Display mode: Fullscreen/Borderless/Windowed, Resolution, UI Scale, Music volume/mute wired to `Soundtrack`, Reduced Motion persisted to `user://settings.cfg`).
   - Audit & clamp layouts at 1280×720, 1280×800, 1920×1080, 2560×1440, and 2560×1080 (cap center-stage aspect for `MeetingView`/VN, raise 11–13px fonts, clamp popups, fix `UITheme` zoom texture leak, bundle open-licensed serif/mono fonts).
   - Compress/prune `assets/` (target cutting the 378 MB lossless PNG footprint by 70–85%), add `export_presets.cfg`, app icon, boot splash, and test a real exported Windows (and Linux/Steam Deck if targeted) build.

3. **Phase 3 — Player-Facing Ship Polish (1–2 weeks)**
   - Title screen / main menu, quit confirmation (`NOTIFICATION_WM_CLOSE_REQUEST`), mid-case autosave/resume (including real persistence for Case Notes), player-facing How-to-Play screen, Credits/Licenses/Version, and basic UI/feedback SFX.

4. **Phase 4 — Opportunistic Architecture Cleanup (Ongoing)**
   - Retire remaining GDScript solver mirrors & pass tuning constants from `sim/tuning.gd` into C# at init so there's a single source of truth.
   - Consolidate modal state in `ui/main.gd` into a single active-modal/overlay stack and unify the duplicated VN/courtroom dialogue stage.
