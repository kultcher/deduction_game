# Living ink: Edda visual checkpoint

Prepared 2026-11-05 on `codex/portrait-line-boil-lab`, based on the rebased
`claude/paper-cutout-shader` experiment and main `e09dbbd`.

Updated after the first review: the hatching-only treatment was too subtle even at
maximum settings. The lab now opens on **Stronger: contours + fill**, with the prior
hatching-only treatment retained as a preset.

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

The stronger candidate uses six held redraws per second, eight source pixels of form
deformation, two source pixels of extra ink deformation and 60% added ink. A broad
field redraws hair and clothing contours together with their colour fills and alpha,
so a stationary duplicate outline is not left behind. The face remains anchored.
The cropped canvas edges are anchored too. This is a procedural redraw approximation;
it can look rubbery at high strengths and needs artistic judgment during reading.

The **Subtle: hatching only** preset restores 1.2 pixels of ink deformation and a fixed
silhouette. Form motion can reach 20 source pixels, and ink motion 12. These strengths
scale down with the portrait. There is no whole-portrait translation, patch dropout,
automatic expression flare or default pressure variation. Selecting the legacy
comparison while reading returns to the comparison layout.

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
  out base or generative replacement face is used. The stronger preset deforms the
  source coordinates outside the protected face, moving structural lines and fill
  together. No source image is modified.
- The green channel of the existing registered neutral ink contains the hatching.
  The red structural-line channel is deliberately excluded from this candidate.
- A feathered UV ellipse protects the face. A separate interior mask keeps added ink
  within the sampled cutout. The subtle preset retains original per-pixel alpha;
  the stronger preset uses the alpha of the coherently displaced source sample.
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
original art until visual approval. Its session-only B shortcut toggles the registered
player's hatching-only defaults during an Edda conversation; Shift+B tests a pulse.
The stronger preset is currently configured by the standalone lab. Those shortcuts do
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
must remain unchanged in the subtle preset, the protected facial interior must match
original RGB in both presets, and the stronger preset must actually change silhouette
alpha. With form motion and added ink both zero, the original must be reproduced
within one 8-bit colour step. Headless dummy-renderer tests do not establish this.

Record deterministic review frames with:

```text
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/portrait_ink_capture.gd -- <output-directory> 150 compare
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/portrait_ink_capture.gd -- <output-directory> 150 reading
```

Frames use 30 fps. An optional final `small` argument selects 1280x720 instead of
1600x1000. A further `subtle` argument selects the older hatching-only preset.
Captures also include still conversation, protection-mask and legacy views.
Local rendered output and clips live under ignored `logs/portrait-ink-stronger/`
for this revision; the initial clips remain in `logs/portrait-ink/`.

## Review question and next work

Judge the stronger candidate while reading, with the original and held version as
references. Does it have enough presence without the hair and clothing looking
rubbery? The original hatching-only approach remains available for comparison.

After that artistic decision: tune/approve the neutral composite, prepare registered
ink for Edda's other expressions, test a contrasting character, then expand the asset
manifest. Each expression needs its own aligned ink and protection regions. The
old automatic line-removal and procedural hatching pipeline is retained as historical
prototype tooling, not the production art pipeline.
