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

- **A Martyr's sacrifice** (Michael, Nov 22): "<Martyr> died at the gallows in <saved>'s
  place...", then the X, then "... but evil still lurks in Hollowmere."
- **No hanging that day** means no execution sequence.

## 2. The night and the morning reveal

1. The night action's result shows in the VN window.
2. Fade to black, then Continue.
3. In red: "A Demon stalks Hollowmere in the night...".
4. A full wheel of fortune of the town's portraits, with a dagger as its pointer, spins and
   lands on the victim.
5. The dagger stabs, with a shake, a red flash and a red X.
6. "... and <name> met a grim end at the hand of the fiend."

- **A second Demon kill** gets its own spin, introduced by "...and the fiend was not finished."
  (approved, Nov 22).
- **The wheel is for the Demon's kill only** (Nov 22).
- **A warded save:** the fakeout lands on the warded person, followed by "Your ward held"
  (Nov 22).

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
- A pass over Nisha's lines for modern words; her register set (#529) is approved (Nov 22).

## 5. Pacing and options (Nov 22)

- **Skipping** (Michael): a click ends the current beat, and Esc skips the whole sequence.
- **Reduced motion** (Seneschal's small call; Michael didn't say): no shake, flash or spin, and
  the beats are halved.
