# Living ink: Edda visual checkpoint

Prepared 2026-11-05 on `codex/portrait-line-boil-lab`, based on the rebased
`claude/paper-cutout-shader` experiment and main `e09dbbd`.

This is a **neutral-Edda visual checkpoint**, not an approved cast-wide art treatment.
No original artwork is overwritten. No simulation state or RNG is consulted.

## Open the lab

Open `ui/line_boil_lab.tscn` in Godot and run the current scene (F6). Alternatively,
run `ui/dialogue_lab.tscn` and choose **Open living-ink portrait lab**.

The initial comparison shows the original portrait, added interior ink held still,
and the identical added ink animated. Change **Compare three views** to
**Read a conversation** to judge it with the actual conversation view, text reveal,
formatted names/role icons, expression fades and dialogue buttons. The reading
selector offers animated ink, held ink and original art independently of text pacing.

Default candidate: six held redraws per second, 1.2 source pixels of coherent ink
deformation and 60% added ink. The face and silhouette are protected. There is no
colour-base jitter, patch dropout, automatic expression flare or pressure variation.
Source-pixel displacement scales with the portrait: it is smaller on screen.

Pause freezes the current drawing. Restart resets its deterministic clock. A manual
pulse tests a short increase in displacement without altering the redraw cadence.
The mask display highlights protected areas. Drawing variants and pressure variation
are optional experiments, off by default; the drawing variants are the older assets,
not newly approved redraws.

The **Legacy reconstructed portrait** comparison preserves the previous alternative:
cleaned colour base, animated structural lines and hatching. Both its static and
animated columns use that reconstruction. Its time/rate multiplication bug is fixed.
The new-treatment controls describe the protected-ink candidate; only redraw rate
affects the historical comparison. The caption identifies that comparison explicitly.

## Art and rendering contract

- The original `cast_expressions/edda/neutral-v1.png` is sampled directly. No painted-
  out base, generative replacement face, or colour deformation is used.
- The green channel of the existing registered neutral ink contains the hatching.
  The red structural-line channel is deliberately excluded from this candidate.
- A feathered UV ellipse protects the face. A separate interior mask protects the
  silhouette. Output alpha is always the original portrait's alpha.
- Nearby strokes deform together using a low-frequency field held for each redraw.
  Added ink can darken the art but never lighten it.
- Registrations are explicit in `ui/portrait_ink_assets.gd`. Only neutral Edda is
  registered. Her other four expressions use their own original portraits, without
  borrowing a neutral overlay or silently using the procedural prototype hatching.
- `ui/portrait_ink_player.gd` owns a monotonically accumulated drawing phase. Rate
  changes integrate from now onward; they never reinterpret elapsed application time.
  Outgoing and incoming portraits share the clock through a crossfade. Hidden views,
  item popups and paused/still states do not advance it.

The daytime conversation view uses the same player and renderer. It defaults to the
original art until visual approval. For a session-only in-game experiment, B toggles
the candidate during an Edda conversation; Shift+B tests a pulse. Those shortcuts do
not intercept typing into text fields or run in item popups. The standalone ink lab
uses its own controls and disables those shortcuts.

The paper border/shadow shader remains independent. Combining it with animated ink
would introduce a second visual decision, so it is not part of this checkpoint.

## Validation and reproduction

Focused suites:

```text
python tools/run_gd_tests.py --godot <Godot-4.7.2-mono-console> test_portrait_ink test_day_conversation_view test_trace_art test_dialogue_vn_preview
```

The ink suite exercises elapsed-time/rate changes, paused and hidden clocks,
original-art bypass, missing-expression fallback, expression phase continuity,
item popup cleanup, lab controls, reading modes and the 1280x720 toolbar layout.

Run `tools/verify_portrait_ink_render.gd` with a **real renderer** (OpenGL compatibility
was used for this checkpoint). It compares original and animated GPU images: alpha
must remain unchanged, the protected facial interior must match original RGB,
interior ink must actually change, and zero added ink must reproduce the original
within one 8-bit colour step. Headless dummy-renderer tests do not establish this.

Record deterministic review frames with:

```text
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/portrait_ink_capture.gd -- <output-directory> 150 compare
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/portrait_ink_capture.gd -- <output-directory> 150 reading
```

Frames use 30 fps. An optional final `small` argument selects 1280x720 instead of
1600x1000. Captures also include still conversation, protection-mask and legacy views.
Local rendered output and clips live under ignored `logs/portrait-ink/`.

## Review question and next work

Judge the animated candidate while reading, with the original and held version as
references. Is the calm interior-hatching motion enough to give the illustration a
little life, or should the next version allow selected hair/contour lines to move too?

After that artistic decision: tune/approve the neutral composite, prepare registered
ink for Edda's other expressions, test a contrasting character, then expand the asset
manifest. Each expression needs its own aligned ink and protection regions. The
old automatic line-removal and procedural hatching pipeline is retained as historical
prototype tooling, not the production art pipeline.
