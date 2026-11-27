# 2026-11-27, Claude-Limner: map lighting, an idle afternoon and readable night faces (claude/map-lighting-tweaks)

- **Agent:** Claude-Limner
- **Base:** origin/main `a88b83ba`
- **Status:** PR open. Presentation only: golden can't move.
- **Next actor:** Bailiff to merge. Michael is still choosing a morning grade from Limner's
  sheets (`mock/morning-grades`), so the morning is left as it is.
- **Decisions:** Michael, Nov 27, through Seneschal, after Limner's review of #556:
  - hide the grade in an idle afternoon, if that's simple (he OK'd Limner doing it rather
    than Argon);
  - grade the standees less at night, so faces stay readable;
  - don't change the morning yet.

## What changed

- **`ui/map_lighting.gd`:**
  - **`is_idle()`:** true while the phase is a settled afternoon. Then the lighting overlay
    and its whole-viewport BackBufferCopy are hidden, so they cost nothing; afternoon's
    grade is the painted map as it is. Any transition switches them back on.
  - **`standee_tint()`:** a milder tint for each phase (`STANDEE_TINTS`), eased across a
    transition with the grade.
  - **`on_change`:** a hook so the map's overlay redraws when the grade moves.
- **`ui/map_view.gd`:** the townspeople standees are now drawn on the UI overlay, above the
  grade, first, so they stay under signs, markers and badges as before. They use
  `standee_tint()`. Their ground shadows stay in the graded world layer.
- **`tools/test_map_lighting.gd`:** five checks (now 25): a settled afternoon switches the
  grade and its copy off; a transition switches them back on; night keeps the grade; night
  standees keep a mild, readable tint; afternoon standees are untinted.

## Measured

- **Suites:** all pass through the runner: `test_map_lighting`, `test_town_ui`, `test_ui`,
  `test_map_graveyard` and `test_approach_vn`.
- **Frame time** (llvmpipe software renderer at 1920×1080; no real GPU here): a settled
  afternoon is now about 30 ms a frame, against 32 ms with the grade switched off and
  40 ms with it on before. Night is unchanged at about 38 ms.
- **Look:** night screenshots before and after, at the Market. Bartholomew and Kiran are
  readable now; before, they were nearly black.
