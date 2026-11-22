# 2026-11-22, Claude-Limner: the night kill wheel and the execution mark (claude/kill-wheel)

- **Agent:** Claude-Limner
- **Base:** origin/main `13445382`
- **Status:** PR open. Presentation only: nothing in `sim/` or `workshop/` changes, so golden
  can't move.
- **Next actor:** Bailiff to merge, then Herald, who owns the flow: when each plays, where,
  the narration around it and what follows.
- **Decisions:** Michael, Nov 22, through Seneschal:
  - **Execution:** the portrait greys, and a blue X smashes down with a little shake.
  - **The night kill:** a full wheel of fortune with every living person's portrait, each
    slice in that person's colour, and a dagger on the right rim pointing in. It lands on
    the victim, the victim's slice and the dagger move to the centre, then the dagger stabs,
    the screen shakes and flashes red, and a red X is left.
  - **No kill:** the wheel lands on someone at random, and the dagger bumps them, bounces
    off and falls off screen.
  - **Reduced motion:** a version of each.
- **Split with Herald:** as with RevealCard. I build self-contained Controls; Herald wires
  them in.

## What changed

- **`ui/fx/kill_wheel.gd`: `KillWheel`,** a Control that fills the rect it's given. A square
  about 70 to 90% of the screen height works well.
  - **The interface:**
    - `play({people, victim, kill})`. `people` is an array of `{id, name, color, portrait}`,
      the living in wheel order (portrait and colour are optional). An optional
      `start_angle` makes a second kill in one night begin where the first stopped: pass the
      first's `end_angle()` (Herald's ask).
    - `skip_to_end()`, `advance(delta)`, `reduced_motion`, `landed_at()`, `struck_at()`,
      `ends_at()` and `focus_centre()`.
    - The signals `landed`, `struck` (a hook for a sound or a wider shake) and `finished`.
  - **The portraits turn with the wheel** (Michael, after seeing the clips); the victim lands upright.
  - **The kill:**
    - 0.3 s fade-in;
    - a 2.2 s spin of three turns and more, easing out onto the victim;
    - a beat, then the isolation: the rest fades and the victim's slice and the dagger glide
      to the centre at 1.5×;
    - a beat with a small wind-up, then the stab;
    - a full-screen red flash, a shake of the wheel's own stage, and a red X slashed on in
      two strokes, with the portrait greying a little.
    - About 4.9 s in all.
  - **The fakeout:** the same up to the beat. The dagger eases in and taps the portrait,
    which jolts; it bounces off, spinning, and falls off screen. About 5.3 s.
  - **Reduced motion:** no wheel, no spin and no shake. The victim's slice fades in at the
    centre with the dagger beside it, then the X fades in (or the dagger fades away). 2 s.
  - **Built from a single clock**, as RevealCard is, so a skip, a test or a capture can jump
    to any moment.
- **`ui/fx/execution_mark.gd`: `ExecutionMark.play(portrait, reduced)`.**
  - **The beat:** it lays the mark over any portrait Control. The portrait greys over
    0.35 s, then a blue X drops from large to its size and the portrait jolts (a small
    rotation and scale punch, so it never fights a container's layout). About 0.95 s.
  - **Afterwards:** the mark stays, and the portrait gets its own scale and rotation back,
    so a hover lift survives.
  - **Reduced motion:** a grey fade, then the X fades in.
- **`ui/fx/cross_mark.gd`:** the painted X that both use, with each stroke drawn on with
  its own progress.
- **`ui/portrait_fx.gd`:**
  - **`square(texture)`:** the square crop from the top that Herald wrote for the daily
    window, now shared and cached per texture. Herald's `_round_portrait` could call it.
  - **`set_grey_amount`:** a partial grey, for fades.
  - **The ring now fades with the portrait's alpha.** It was drawn at full alpha even
    when the portrait faded. Nothing changes at full alpha, so the daily window looks the
    same.
- **`tools/test_kill_wheel.gd`:** 38 checks, under 1 s. Added to `tools/ci_fast_suites.txt`.
  - **Signals:** they fire once each and in order, and a skip sends each once.
  - **Landing:** the wheel stops with the victim under the dagger, for 3, 7 and 10 people
    and every victim, after more than two turns. A second spin starts where the first
    stopped.
  - **The isolated portrait:** it never jumps (its biggest step is 3.9 px), and it ends in
    the middle.
  - **A kill:** it leaves only the X, with no flash or shake left over.
  - **The fakeout:** it leaves no X, and the dagger ends off screen.
  - **Reduced motion:** no wheel and no shake, and quicker.
  - **Resizing:** it lays out again.
  - **The execution mark:** its signals, the jolt and the portrait's scale given back, the
    grey, replacing a mark, and its reduced-motion path.
- **`tools/kill_wheel_capture.gd`:** records a kill (Greta), the fakeout (Kiran) and an
  execution (Dorian) in a real renderer, with an optional `reduced` argument.

## Cost

- **Per person:** a slice drawn with `draw_*` calls and a portrait with the circle shader
  (7 texture reads a pixel, on the portrait only).
- **The rest:** the frame, the dagger and the X are drawn once each, and redrawn only on
  resize. Each frame sets transforms and alphas.
- **Not yet profiled on target hardware.** Argon owns speed.

## Measured

- **Suites:** `test_kill_wheel` 38/38, `test_daily_guess` and `test_reveal_card` pass,
  through the runner.
- **Golden:** not captured. No game logic changed.
- **Clips:** normal and reduced, at 1920×1080 under xvfb, sent to Michael and Herald.

## For Herald

- **Placement:** add a `KillWheel` over a dim shade and call `play`. Wait for `finished`
  before going on, and call `skip_to_end()` on a click.
- **People:** pass portraits as you like. They're cropped square with `PortraitFx.square`
  if they aren't already.
- **The screen shake:** the wheel shakes only its own stage. Use `struck` to shake more.
- **For an execution:** call `ExecutionMark.play(portrait_control)` on whichever portrait
  shows the condemned (the courtroom stage, the town list or both).
- **Names and captions:** there are none on the wheel; the words are yours.
  `focus_centre()` gives the victim's portrait position for placing a caption.
