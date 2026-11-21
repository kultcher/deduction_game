# Grim reveal: the reel and the visuals (Limner's part of the pitch)

**Status:** a pitch for Herald's joint plan, sent to Michael through Seneschal. Nothing is
built. These are sketches on `mock/grim-reveal-reel`, a branch that never merges.
- **Written by:** Claude-Limner, Nov 21.
- **Answers:** `docs/design/grim_reveal.md`, open question 3 (the reel's style), plus the
  visual side of sections 4 to 6.

The sketches are rough mockups in the game's paper palette, made with `sketch.py`:

| File | What it shows |
|---|---|
| `reel_A_volvelle.jpg`, `reel_B_slot.jpg`, `reel_C_cards.jpg` | The three reel styles, mid-spin, on the same overlay |
| `landed_evil.jpg` | Odette after a fakeout: the reel shows Poisoner, with the evil seal and her key moment |
| `landed_burden.jpg` | Edda: Gravedigger and the good seal, then the burden tag "…and Delusional" |
| `reduced_motion.jpg` | The same beat with no spin |
| `reveal_volvelle.mp4` | About 7 s: Odette's fakeout (lands on Seer, holds, lurches to Poisoner), then Edda (spins to Gravedigger, then the tag drops) |

## 1. The reel: three options, one recommendation

| Option | What it is | For | Against |
|---|---|---|---|
| **A. Volvelle (recommended)** | A paper wheel turning behind a cut-out window in a paper plate, with a pointer and a rivet. Old astrological manuscripts used these. | Period-true and grimoire-like. It's literally papercraft, so it matches the cut-paper direction. One moving part. It shows the script's roles going round, which teaches the script. | A wheel reads slower than a strip, so the window and label have to carry it. |
| B. Slot | A paper strip drawn through a slot in a card. | The most readable. The classic "slot machine" tension. | Feels like gambling more than a grimoire, and is less in keeping with the paper look. |
| C. Card turn | The script's role cards, face down and fanned, with one turned over. | Tarot mood. Fakeouts are natural: turn one card, then the real one. | It's a pick, not a spin, so it has less build-up. The deck also gives away the count. |

**Recommendation: A, the volvelle.** It's the one only this game would have: a hand-cut
paper instrument from the grimoire's own world.

- **The disc:** this script's role icons, in script order, good roles then evil.
- **The plate:** a window one notch wide, with a pointer above.
- **The role's name** sets under the plate when the wheel stops, in ink, or blood red for
  evil.

## 2. Motion

- **The spin:** about 1.5 s, easing out over 2 to 3 turns. Each later NPC is a little
  quicker, down to about 0.8 s, as the design note asks.
- **Stop-motion stepping** (as in the paper-puppet test): the wheel moves 12 times a second,
  not smoothly, so it reads as handled paper. One clock is shared with the puppet if both
  ship.
- **The landing:** a small "click" overshoot of 2 to 3 degrees, then settle. The name sets
  in. The alignment seal stamps down after about 0.2 s: it scales from 1.3× to 1×, with a
  short shadow pop.
- **The burden:** a paper tag on a thread drops in as a second beat, about 0.5 s after the
  seal: "…and Delusional", swinging once and settling.
- **The fakeout "lurch":** the wheel lands on the false role, the name sets, and it holds
  for about 0.6 s. Then the paper catches (a 3-degree shiver) and the disc lurches on to
  the true role in about 0.3 s.
  - Roles sit in script order, so the lurch usually crosses several notches. That reads as
    the lie giving way, rather than a one-notch nudge. In the sketch: Seer, then Poisoner.
  - The false name is struck through in ink as it goes.
- **Skip and fast clicks:** a click while it's spinning snaps straight to the landing. Skip
  jumps to the final screen.

## 3. Portraits through the reveal

- **The board:** the whole town as a row of small cut-paper tiles along the bottom of the
  overlay.
  - **Dead NPCs** are greyed (desaturated and darkened, by a cheap shader on the tile) until
    their turn.
  - **The NPC being revealed** lifts: their tile rises and its shadow grows.
  - **Each revealed NPC** keeps a small wax badge with their role icon, gold for good and red
    for evil. The row fills in as the true town.
- **The current NPC:** large on the left of the overlay, as in conversations. A dead NPC
  returns to full colour for their turn: a short fade from grey as the reel starts.
- **On landing:**
  - **Evil:** the portrait gets a faint red edge light, and the evil seal stamps on.
  - **Good:** a warm gold edge light and the good seal.
  - There's no portrait swap or recolour; the art stays the art.
- **The player's guess:** "You guessed: Minion" in italic under the name, during the spin.
  It ties in the score.
- **Puppet portraits:** if paper puppets ship, the overlay takes a portrait texture exactly
  as the conversation view does, so a puppet drops in unchanged. It could react: a blink,
  then a fitting expression on landing.

## 4. The overlay

- **Behind:** a paper sheet with deckled edges over the town, which is blurred and dimmed
  (the same treatment conversations use).
- **Entrance:** the sheet slides up about 40 px, with its shadow settling, about 0.3 s.
- **Between NPCs:** the portrait slides out left as the next one slides in. It's quick
  (about 0.25 s), and a click skips it.
- **Final screen:** the sheet widens into the full grimoire: every NPC with their role,
  alignment and burden, the verdict sheet against the truth, then the score. Herald owns
  the layout.

## 5. Reduced motion

No spin and no lurch. The role card sets down in place with a short fade. The seal and the
burden tag simply appear, each on its beat, so the pacing survives without the motion.

- **A fakeout** shows the false card, then the true card replacing it, with the false
  name struck through. The tell survives; the motion doesn't.
- **Slides** become fades, and the board's lift becomes a highlight.
- Everything is driven by one "motion" setting that the reel and overlay read.

## 6. Art it needs

**Nothing new is required for a first version.**
- **Role icons:** `assets/ui/roles/` already has 36 in a consistent ink-and-gold stamp
  style. The reel uses them as they are.
- **Portraits:** the existing ones.

To make it look finished, in order of value:
1. **The volvelle disc and plate,** drawn as cut paper, like Michael's Krita pieces: two
   images. The sketch draws them procedurally, which works but is plain.
2. **Wax seals:** good and evil, two images, or one tinted.
3. **Burden tags:** one paper tag; the text is drawn by the game.
4. **Optional:** a red "evil" variant of each evil role icon for the wheel. A tint shader
   does this for free.

With paper puppets, nothing changes for the reveal: they slot into the portrait position.

## 7. Cost and size

- **Cost:** one rotating sprite with about 10 to 15 icon sprites, one plate, a seal and a
  tag. That's negligible next to the conversation view. The grey board is a cheap shader
  on about 10 small tiles.
- **Size, Limner's part:** one mid-sized PR.
  - A `RevealReel` scene: the wheel, the landing, the lurch, the seal and tag beats, and
    reduced motion.
  - The portrait treatments: the grey shader, the lift, the edge light.
  - A capture tool for review clips.
  - A headless test of its timing and its reduced-motion path.
- **Herald's part:** the overlay, the order and pacing, wiring to the event-graph walk, the
  final screen and the wording.
- **Gold:** neither part touches the sim, so golden stays identical.

## 8. Open for Michael

1. The reel's style: A, B or C. Limner recommends A.
2. Whether the wheel steps (stop-motion) or turns smoothly. Limner leans to stepping, to
   match the paper puppets.
3. The fakeout lurch: cross several notches (as sketched), or arrange the wheel so it's
   always a one-notch slip.
