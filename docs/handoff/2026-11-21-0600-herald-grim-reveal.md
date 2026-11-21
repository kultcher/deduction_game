# Herald: the grim reveal overlay and final screen (stage 1, PR 3 of 3)

- **Agent:** Claude-Herald
- **Base:** main, plus #497 (Limner's `RevealCard`) and #496 (the daily guess window).
  **Merge after both;** this branch contains them.
- **Status:** PR open
- **Next actor:** Bailiff
- **Zero drift:** UI only

## What changed and why

This is stage 1 of the grim reveal (`docs/design/grim_reveal.md`; the Herald and Limner
pitch, Michael's answers Nov 21). It uses the note's plain timeline order, so nothing waits
on Lantern's event graph.

- **When the case closes,** the reveal opens by itself once, and a **"The grim reveal"**
  button replays it.
- **The verdict** it plays against is the last guesses locked in a daily window (#496;
  Michael, Nov 21 "Corrections"). There's no end-of-game seal, which would give away who was
  just hanged or that the game had ended. After an overnight ending, the last locked guesses
  stand.
- **The plan** (`ui/reveal/reveal_plan.gd`) reads the finished game and changes nothing.
  - **Order:** deaths and hangings in the order they happened, the living in cast order, the
    Demon last. In a final-three game the last hanging goes last.
  - **Up to two key moments** for each person, the most telling first: a poisoning that made a
    reading false, Delusional, a false gift claim or "no gift", a made-up reading, Marked,
    lies, a true claim, a quiet poisoning, then how they died.
  - **Fakeouts:**
    - an evil person who claimed a gift lands first on that gift;
    - a good person the town hanged lands first on a Minion type.
    - The chance is about one in two for the first and one in three for the second, and
      three in four for a final-three game's last person.
    - At most two a reveal, never the first person, never two in a row.
    - They're rolled on the reveal's own generator, seeded from the case, never the world's.
  - **Each person's guess** shows as "You guessed: X" with ✓ or ✗ on the card. A role guess is
    right on the exact role; "good" or "evil" on the alignment.
- **The overlay** (`ui/reveal/reveal_overlay.gd`):
  - a lead line;
  - Limner's `RevealCard`, at 90% × 74% of the screen;
  - the key-moment lines, shown once the card finishes;
  - the town's portrait row;
  - Skip, and Next (Next or a click lands a playing card at once).
- **The final screen:**
  - every person's truth (role, alignment, burden) beside the verdict, each marked ✓ or ✗,
    with one key moment;
  - "Your verdict: N of M evil named rightly". That's right or wrong only; points wait for
    scoring (Michael, Q2);
  - the grimoire, "Every lie" and "Who told whom what" as tabs;
  - Watch again, and Close.
- **Reduced motion:** a check item under More ▾, passed to the card.

## Wording: drafts awaiting Michael

All of it is in constants at the top of `reveal_plan.gd` and `reveal_overlay.gd`:
- **the lead lines:** "Here is how the town truly stood, one soul at a time." and "It came down
  to the last three.";
- **about 15 key-moment templates**, e.g.:
  - "Poisoned on the second night. That reading was false."
  - "Claimed to be the Medium. A lie."
  - "Delusional: every reading was a fancy, and they never knew."
- **the guess line:** "You guessed: %s";
- **the alignment text:** Good and Evil;
- **the buttons and tab names.**

## Measured

- **New `tools/test_grim_reveal`** (fast list): 42 checks pass, about 35 s. It plays passive 7-NPC
  games to their end, finds one that ended at a meeting and one that ended overnight, and
  checks:
  - the order, including the final-three rule;
  - the fakeout rules and their determinism;
  - the key-moment count, and that everyone who died has one;
  - right and wrong guesses;
  - that the verdict is the daily window's last lock, and that it stands after an overnight
    ending;
  - the overlay's flow: Next to the final screen, the truth grid, the tabs, Watch again, Skip
    and reduced motion.
- **The plan read on seeds 1–3:** the lines and fakeouts were sensible. One fix came out of
  it: a poisoned Martyr no longer gets "that reading was false".
- **The other suites:** test_daily_guess, test_reveal_card, test_ui, test_ui_controls,
  test_text_ui and test_town_ui pass.
- **Golden:** not captured, since only `ui/` changed.

## Next

- **Stage 2:** swap `RevealPlan.reveal_order` and the key-moment choice for Lantern's reveal
  plan. The step shape stays the same.
- **Stage 3:** scoring, once Michael decides the draft.
- **Michael's answers still pending:** the wording, and the guess-change limit (#496). The
  limit's second rule, that a guess counts only if locked before that person's hanging day,
  would also change how the reveal marks guesses.

## Proposed for the backlog

None.
