# 2026-11-21, Claude-Limner: paper-puppet portraits, parked on mock/paper-puppet

- **Agent:** Claude-Limner
- **Base:** `mock/paper-puppet` was branched from main `678838f` (Nov 19). `mock/`, so it
  never merges.
- **Status:** parked by Michael while other work comes first. It's a test only: no game
  code reads it.
- **Next actor:** none until Michael picks it up again.

## What it is

Michael wants "motion and life" in still conversation scenes. The papercraft look turned
this into a **paper-puppet** portrait. The art is cut into paper pieces, and each piece:

- casts its own soft shadow;
- sways on its own pivot, either smoothly or in stop-motion steps (10 a second, each
  piece nudged slightly every step);
- blinks by swapping in closed-eye pieces;
- while talking, cycles through mouth shapes.

The earlier line-boil effect (redrawn ink, PR #282) is a **draft, on hold**. Michael has
explored paper puppets since.

## Where things are (all on `mock/paper-puppet`)

| Path | What |
|---|---|
| `ui/paper_puppet.gd` | The puppet. `@tool`: it builds shadows from any Sprite2D pieces in its scene and animates them. See the header for how to edit a rig. |
| `ui/paper_puppet/edda_v2.tscn` | **The current one.** Michael's Krita layers: a body with the face cleared, then eyes, nose, brows, mouths, and five hair pieces. |
| `ui/paper_puppet/edda_hair_test.tscn` | The earlier hair-only test from his first Krita cut. |
| `ui/paper_puppet/edda_puppet.tscn` | The first rig, from GPT's unaligned piece sheets. It's the jankiest; kept for reference. |
| `assets/art/paper_puppet_poc/` | Art for all three, one folder each. Every v2 piece is full-canvas (1024×1536), registered to GPT's full Edda. |
| `tools/paper_puppet_capture.gd` | Records frames in the real conversation view, then `ffmpeg` makes a clip. |
| `tools/paper_puppet_v2_prep.py`, `tools/paper_puppet_v2_scene.gd` | One-off builders for v2. They line up the mouth and closed-eye sheets on the placed pieces, lift the ear, and build the dark under-hair and the scene. |

**Run it:** open a scene and press F6. T toggles talking, S switches between stepped and
smooth, and R shows the reference overlay.

**Record:**
`xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/paper_puppet_capture.gd -- <out> stepped 9 res://ui/paper_puppet/edda_v2.tscn`

## Editing a rig

Each piece is a Sprite2D:

- **Position** is its pivot. The editor's pivot tool (V) moves the pivot without moving
  the art.
- **Z Index** sets the stacking across groups.
- **Metadata:**
  - `depth`: shadow offset and softness (0 = no shadow).
  - `sway` and `phase`: how far it sways, and where in the sway it starts.
  - `shut`: the closed-eye texture, on the eyes piece.
  - `frames`: the mouth shapes, the first at rest.

## Porting to main later

It's all new files (63) with no edits to existing ones, so it can't conflict. Take
`ui/paper_puppet*`, `assets/art/paper_puppet_poc/` and the tools onto a branch from main.

The puppet renders into a SubViewport. Its texture drops into the conversation view's
portrait slot in place of the still image. The capture tool does exactly this without
touching the view, so wiring it in for real is a small change to
`ui/day_conversation_view.gd`. **Tell Herald first.**

Two things could go stale:

- The capture tool reaches into the view's internals (`portrait`, `_process`).
- A Godot upgrade could break `@tool`, internal child nodes or SubViewport behaviour.

## Known jank in v2

- The left-side hair layer has a large dark block at its top left.
- A thin line runs from the top swoop's loop to the frame edge.
- The head and face don't move: the body is one layer, so head turns and nods would need
  the head cut from the neck and torso.
- Only one character, and only one expression.

## Cost

Each piece is one textured sprite plus a shadow. Each shadow is blurred with nine texture
reads a pixel; there are about 15 pieces. The CPU work is a few dozen transform updates a
frame. It hasn't been measured on target hardware, and Argon owns speed. Baking the
shadow blur into the textures is the obvious saving.

## Proposed for the backlog

None. Whether this becomes a feature is Michael's call.
