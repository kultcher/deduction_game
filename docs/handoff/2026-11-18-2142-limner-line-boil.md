# 2026-11-18, Claude-Limner: line boil brought back, opt-in (claude/line-boil)

- **Agent:** Claude-Limner (visuals; new session, started by Seneschal at Michael's request)
- **Base:** origin/main `8796f9f`
- **Status:** PR open. Presentation only, off by default. Golden checked against
  `baseline_e287b3d` (result in the PR).
- **Next actor:** Michael picks a look from the clips (via Seneschal). Bailiff to review
  and merge. Herald to review the small hook in `ui/day_conversation_view.gd`.

## What changed and why

Michael asked for the original line-boil portrait experiment back. Each portrait gets two
layers: a colour layer, and a drawn ink layer (lines and shadow hatching). The ink is
redrawn a few times a second, rotoscope style. The colour layer stays still.

- **Source:** branch `codex/portrait-line-boil-lab` (left untouched). The original
  prototype is 1f77bc8 to e965cd3. Codex's later commits (2c1c2ab, 3886df8, 75e3421)
  went another way, which Michael didn't like:
  - they boiled only the hatching, over the untouched painting, behind a face mask;
  - they then added a whole-portrait warp that read as rubbery.

  None of that is carried over.
- **`ui/line_boil.gdshader`:** the original shader, tidied:
  - one ink texture instead of three (R outlines, G a second drawing of them, B hatching,
    A a value per hatch stroke);
  - hatch strokes now drop out one whole stroke at a time on each redraw (patches before);
  - the redraw clock comes from GDScript, so a flare speeds the boil up without jumping it;
  - an `ink_amount` setting, where 0 shows the colour layer alone.
- **`ui/line_boil.gd`:** which portraits have layers; the boil level (rest, flare on an
  expression change with harsh hardest, settle over about a second); the integrated
  clock; three presets (subtle, original, lively); and a session switch, off by default.
- **`ui/day_conversation_view.gd` (Herald's view):** about 30 lines.
  - When the switch is on, a portrait with layers shows its colour layer with the shader.
  - An expression change flares the boil.
  - In a talk with someone who has ink, B toggles the boil and Shift+B fires a flare.
    With anyone else, B does nothing.
  - While off, the view is exactly as before. The test checks this.
- **`tools/make_line_boil_layers.py`:** the drawn-ink path of the original builder. The
  path that faked ink from the painting stays on the old branch.
  - It extracts the colour layer by lifting the painted lines out (a colour closing).
  - `--flat` takes separate colour flats instead, if the art pipeline can supply them.
- **Layers for Edda's neutral portrait:** in `assets/art/line_boil/edda/`, built from the
  hand-drawn ink already on main (`assets/art/edda_ink_overlay_poc/`, byte-identical to
  the ink the Nov 3 prototype used).
- **`tools/line_boil_capture.gd`:** records review frames, in the conversation view or a
  three-way comparison. The idea came from Codex's capture tool.
- **`tools/test_line_boil.gd`:** 27 headless checks:
  - it's off by default, and plain while off;
  - the colour layer and material appear when it's on;
  - expressions without ink stay plain;
  - items never get the shader;
  - flare and settle;
  - the clock;
  - the B and Shift+B keys.
- **`docs/line_boil.md`:** how it works, the art contract, cost, the presets and the
  open questions for Michael.

Not brought forward: Codex's lab scene, protected-face mask and form warp. Its GPU verify
script is not ported yet either. The capture plus the headless test cover this stage.

## Measured

- **Suites:**
  - pass: `test_line_boil` (27/27), `test_location_art`, `test_trace_art`,
    `test_dialogue_voices`;
  - `test_day_conversation_view` times out, and it does the same on unmodified main
    (200 s, with "Can't emit non-existing signal" errors). It isn't on the CI fast list.
    For Herald.
- **Clips:** 9 s each, recorded with the capture tool under xvfb and llvmpipe:
  - Edda in the mill conversation at each preset;
  - a 6 s side-by-side comparison: plain portrait, the two layers held still, boiling.

  Sent to Michael.
- **Cost:** estimated, not measured on target hardware. Six texture reads a pixel on the
  portrait rect only, a few uniform writes 8 to 14 times a second, and one extra
  ~6 MB texture per boiling expression. See `docs/line_boil.md`.

## For Herald

The hook is small and self-contained (`line_boil.apply`, `flare` and `advance`, plus
`_unhandled_key_input`). It stays a dev toggle until Michael approves a look. Wiring it
into other portrait views waits for that too.
