# 2026-11-21, Claude-Limner: the end-of-game card reveal, one person's beat (claude/reveal-card)

- **Agent:** Claude-Limner
- **Base:** origin/main `b0a73579`
- **Status:** PR open. Presentation only: nothing in `sim/` or `workshop/` changes, so golden
  can't move.
- **Next actor:** Bailiff to merge. Then Herald, for PR 3, the reveal overlay, which uses
  this.
- **Decisions:** Michael, Nov 21, through Seneschal and directly:
  - the card-based reveal, version 1;
  - the torn-card fakeout;
  - about 3 seconds for each person's whole sequence;
  - the whole screen is free.
- **Split with Herald:** PR 1 is Herald's daily guess window, PR 2 is this, PR 3 is Herald's
  overlay.
- **Sketches:** `mock/grim-reveal-reel`, `docs/design/grim_reveal_reel/`.

## What changed

- **`ui/reveal/reveal_card.gd`:** `RevealCard`, a Control that fills the rect it's given,
  laid out for 16:9.
  - **The deal:** eight of this script's other roles. Each card slides off the top of a
    face-down deck, flips, arcs out to alternating sides and slides back in under the deck.
    The deal quickens as it goes.
  - **The true card:** flips in place and pushes out towards the player. Then the alignment
    wax seal stamps down (gold for good, red for evil). A burden tag drops
    in on a thread as a second beat. Herald passes the tag's full text.
  - **A fakeout:** the false role flips and starts to push out. It tears in half along a
    ragged line, and the halves fall away, showing the true card face up beneath. The
    false name is struck through as it goes.
  - **The portrait:** a dead NPC's portrait fades from grey to colour as the reveal
    starts. On landing, a soft rim glows red or gold.
  - **Reduced motion:** no deal. The card fades in; a fakeout shows the false role struck
    through before the true one. The seal and the tag appear on their beats.
  - **The interface agreed with Herald:**
    - `play(step)` takes `portrait`, `name`, `roles` (script order), `role`, `evil`,
      `burden`, `fakeout_role`, `guess`, and optionally `guess_correct`, `dead`,
      `role_text` and `align_text`;
    - `skip_to_end()`, `reduced_motion`, `advance(delta)`;
    - the signals `landed` (the true card has settled), `finished` (the seal and tag are
      done) and `card_dealt` (once a dealt card, a hook for a sound).
  - **Built from a single clock:** every frame's state is a pure function of one clock, so
    a skip, a test or a capture can jump to any moment.
- **Timing, measured headless:** a straight reveal takes 2.9 s, landing at 2.3 s. With a
  burden tag it's 3.2 s. A fakeout takes 3.8 s, and reduced motion about 1.9 s.
- **Looks:**
  - cards are drawn at runtime from the role icons in `assets/ui/roles/`, tinted by team as
    on the script sheet (`MainRoles.team_icon_material`);
  - the card back is dark red with a gold star in a ring;
  - nothing needs new art. Drawn card, seal or tag art can replace the procedural ones
    later.
- **`tools/test_reveal_card.gd`:** 32 checks, about 1 s. Added to `tools/ci_fast_suites.txt`.
  It covers:
  - the timing;
  - the signal order, and that each signal fires once;
  - that skipping emits both signals once;
  - that the deal never shows the true or fakeout role;
  - the fakeout's tear and strike;
  - reduced motion;
  - that the screen is clear at the end;
  - resizing.
- **`tools/reveal_card_capture.gd`:** records Odette (fakeout) and Edda (burden) in a real
  renderer, with an optional `reduced` argument.

## Cost

The work is about 20 small Controls: cards made of StyleBoxFlat panels with built-in soft
shadows, a role icon each, and two Polygon2D clip masks for the tear. The portrait gets one
shader: grey and rim, 7 texture reads a pixel, on the portrait rect only. There's nothing
per-frame beyond setting transforms. It hasn't been profiled on target hardware; Argon owns
speed.

## Measured

- **Suites:** `test_reveal_card` 32/32 and `test_day_conversation_view` pass, both through
  the runner.
- **Golden:** not captured. No game logic changed: the diff touches only `ui/reveal/`, two
  new tools and the fast-suite list. CI runs golden.
- **Clips:** recorded under xvfb at 1920×1080, normal and reduced motion, and sent to
  Michael.

## For Herald (PR 3)

- **Placement:** add a `RevealCard`, size it (about 90% of the width by 74% of the height
  is the recommended footprint), and call `play(step)` for each person.
- **Signals:** wait for `landed` to show your key-moment lines, and for `finished` to enable
  Next. Call `skip_to_end()` on a click mid-play.
- **The tick or cross:** set `guess_correct` to have it drawn beside the guess. Leave it out
  to place your own.
- **Wording:** "Good" and "Evil" under the role name are placeholders. Pass `align_text` and
  `role_text` to override them.
