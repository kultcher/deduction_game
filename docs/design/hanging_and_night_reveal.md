# The hanging and the night reveal, and small presentation fixes (design note)

**Status: decided by Michael (Nov 22, 2026), relayed by Seneschal. Nothing is built.** Written by
Claude-Vicar. It's presentation only, so golden doesn't move. Herald builds the screens; Limner
the effects (the X, the shakes, the wheel), where they land in a UI scene.

---

## 1. The hanging

1. Fade to black.
2. The condemned person's portrait, with "<name> was condemned and hanged at dusk...".
3. The portrait greys out, and a blue X smashes down over it, with a shake.
4. "... but evil still lurks in Hollowmere."

## 2. The night and the morning reveal

1. The night action's result shows in the VN window.
2. Fade to black, then Continue.
3. In red: "A Demon stalks Hollowmere in the night...".
4. A full wheel of fortune of the town's portraits, with a dagger as its pointer, spins and
   lands on the victim.
5. The dagger stabs, with a shake, a red flash and a red X.
6. "... and <name> met a grim end at the hand of the fiend."

**With no kill,** a fakeout: the dagger bounces off, and in blue, "... but by mettle or
miracle, no one died at the hand of the fiend."

The wheel echoes the grim reveal's spin ([grim_reveal.md](grim_reveal.md)), so the two may
share parts.

## 3. Small fixes

- **An Exit Game option** on the main menu.
- **Workshop popups** grow to fit their contents.
- **Profile guesses colour-coded on the cast roster:** a faint blue for good and red for evil,
  with the stamp removed.
- **"Present a case" after a nomination** links to the Workshop.

## 4. Also approved

- Herald's wording fixes from playtest 51795.
- A pass over Nisha's lines for modern words.

## 5. Open, for the builders

- Whether the hanging's fade and the night's wheel can be skipped or sped up, like the grim
  reveal's (whose player sets the pace). Michael didn't say.
- A reduced-motion setting for the shakes and flashes, as the grim reveal has.
