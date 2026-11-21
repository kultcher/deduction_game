# Line boil: redrawn-ink portraits

Owner: Claude-Limner (visuals). Status: **opt-in test, off by default**. It is waiting on
Michael's look-and-feel call before it goes any wider than Edda's neutral portrait.

## What it is

A conversation portrait drawn as two layers:

- **The colour layer** is the painted portrait with its own linework lifted out.
- **The ink layer** is the hand-drawn lines and shadow hatching, registered to the portrait.

The ink is "redrawn" a few times a second, rotoscope style. Each redraw bends the lines
by a pixel or two, lets the pen press harder or lighter in places, alternates between
two drawings of the outlines and leaves out a different few hatch strokes. The colour
stays put. One `boil` level scales all of it. It rests low, flares when the speaker's
expression changes (harsh hardest), and settles back over about a second.

This is the Nov 3 prototype (branch `codex/portrait-line-boil-lab`, commits 1f77bc8 to
e965cd3), brought forward. The later commits on that branch went another way: hatching
only, over the untouched painting, behind a face mask, then a whole-portrait warp. They
are not used. That branch stays as a reference.

## Trying it

In a daytime talk with Edda, **B** turns it on or off for the session and **Shift+B**
fires a flare. Only her neutral portrait has ink so far. Her other expressions show their
plain portraits, so a flare is easiest to judge with Shift+B. With anyone else, B does
nothing.

## The pieces

| File | What it does |
|---|---|
| `ui/line_boil.gdshader` | The shader on the portrait rect. |
| `ui/line_boil.gd` | Which portraits have layers, the boil level (rest, flare, settle), the redraw clock, the presets and the on/off switch. |
| `ui/day_conversation_view.gd` | The hook: a small one, in Herald's view. |
| `tools/make_line_boil_layers.py` | Builds the two layers from a portrait and its drawn ink. |
| `tools/line_boil_capture.gd` | Records review clips (the conversation view, or a side-by-side comparison). |
| `tools/test_line_boil.gd` | Headless checks of the wiring, the clock and the off-by-default guarantee. |
| `assets/art/line_boil/<id>/<expr>-base.png`, `-ink.png` | The built layers (committed, so the game doesn't need Python). |

## The art contract

Per portrait and expression:

- **Drawn ink:** a transparent sheet the size of the portrait, with the ink in its alpha.
  Heavy strokes (wider than about 4 source pixels) become outlines and the finer ones
  hatching. Put it at `assets/art/cast_ink/<id>/<expr>-v1.png`, or name its path in
  the builder's `INK` table. Edda's is `assets/art/edda_ink_overlay_poc/edda-ink-overlay-v1.png`.
- **Colour layer:** the builder extracts it by lifting the painted lines out (a colour
  "closing" under the ink's footprint and the painting's other dark lines). It's good,
  not perfect. A little of the outer silhouette's line stays in the colour layer, and
  closed regions can look slightly flatter. If the art can come as separate **flats**
  (colour with no lines) and **inks**, `--flat` uses the flats directly. That is the
  better source and the recommended pipeline.
- Then run `python3 tools/make_line_boil_layers.py` (it needs `opencv-python-headless`)
  and `godot --headless --path . --import`.

A portrait with no drawn ink just shows its plain art. Nothing fakes ink.

The ink layer packs everything into one texture. R holds the outlines, G a second
drawing of them, B the hatching, and A a random value per hatch stroke (never 0, so
the importer's alpha-border fix can't touch the other channels).

## Cost

- **GPU:** six texture reads a pixel (the colour layer, the ink layer, three noise reads
  for bend, weight and an offset) and no loops. On a portrait about 1M pixels at 1080p
  that's negligible on a discrete GPU and small on an integrated one. Only the portrait
  rect pays. Nothing renders off-screen.
- **CPU:** a few uniform writes when the redraw step changes (8 to 14 times a second)
  or while a flare is settling. Nothing at all while it's off.
- **Memory:** one ink texture (1024×1536 RGBA, about 6 MB uncompressed) per boiling
  expression. Its colour layer replaces the plain portrait rather than adding to it.
  A 512² noise texture is shared by all. Not yet measured on target hardware. Argon owns
  speed, so a VRAM-compressed import is the obvious lever if the whole cast gets ink.

## Presets (Michael's call)

| Preset | At rest | Flare | Redraws a second | How far lines wander |
|---|---|---|---|---|
| subtle | barely moving | short | 6 to 10 | up to 2 px |
| **original** (default) | the Nov 3 test as it last stood | about a second | 8 to 14 | up to 3 px |
| lively | always visibly alive | longer | 10 to 16 | up to 4 px |

Set with `LineBoil.preset_name`. The capture tool takes a preset name.

## Open questions for Michael

1. Look: which preset, or somewhere between?
2. Should it run all the time or only flare? (For example, rest at 0 and boil only after
   an expression change.)
3. Art source: will future portraits come as flats plus inks, or should the extraction
   stay?
4. Scope: when the look is settled, which portraits get drawn ink next (Edda's other
   expressions, then a contrasting character)?
