# A reader's self-doubt points at the Poisoner

**Claude-Quill, Nov 20.** Base: main at 871a9ad0, with #445 (claude/poisoner-destination)
stacked in; it merges after #445. Status: ready for review. Next actor: Lantern (belief side)
and Beadle (when the line fires) review, then Bailiff. Golden moves: re-baselined to
`baseline_d553f53`.

BACKLOG "A reader's self-doubt points at the Poisoner" (Michael, Nov 20, [decided]).

## What changed and why
- **`ReadingChallenges.self_doubt_floors(view, case, listener, cards)`**: for each reader the
  listener heard say its gift may have been turned (the public `self_doubt` event, at the
  meeting), the people seen on that reader's block on any night of a reading of theirs the
  listener holds, by #445's destination rule. Not one night: the doubt comes from the readings
  as a whole. It follows what the reader said, not what's true (a Delusional or mistaken reader
  counts). Agreement is the listener's belief in the reader (1 - its suspicion of them), as for
  the doubt the same event already casts on those readings (`SourceDoubt._gift_self_doubt`).
  - Not for the listener's own words, nor where no Poisoner can be in play (as for the Mistaken
    call), nor for someone whose outing a claimed night gift or confided secret explains, nor
    for someone the listener knows is good (as `_outing_poison_chance` reads the night). A
    plain NPC refresh has no case reasons to excuse an outing, which the player's call has.
- **`Jury._consequences_eval`** applies it beside the Mistaken call's floor, at the same scale
  (`CHALLENGE_POISONER_SCALE x agreement / candidates`) and the same bar. **Floor-only**
  (Lantern): no report or source multiplier and nothing in the case's `reading_challenges`, so
  the reader's readings are discounted once (SourceDoubt), not twice.
- **`Jury.poisoner_floor` (Lantern, belief model):** a Poisoner nudge is a floor for anyone not
  cleared, but is added to a clear and never past the floor, so a weak "seen near the reader's
  door" can't undo a strong clear. Continuous at 0, no new number. It applies at all three
  Poisoner-floor sites, so **the player's accepted Mistaken call changes too**; the lie-call
  floors are untouched.
- **One Poisoner floor per person** (Codex): every Mistaken and self-doubt nudge on a person is
  gathered and the strongest applied once, after the lie floors, so their order doesn't matter
  and repeats don't stack. Quoted observations are no ground for a self-doubt's candidates
  (Codex), as `_outing_poison_chance` reads the night.

## Measured
- **Golden:** moves on seeds 42 and 54875 (see `docs/golden_baseline.md`); outcomes unchanged.
  Two captures identical. Before the clear rule, seed 54875 turned a cleared good Lamplighter
  (Isolde) suspected (requested -0.544 to +0.146); with it she stays cleared (-0.398).
- **New `tools/test_self_doubt_poisoner.gd`** (19 checks): the candidates (any night it read,
  the destination rule, not the reader, a held reading needed, no Poisoner in play, an explained
  outing, the known good), the agreement, the clear rule, and an in-play check (Lantern's pin):
  one listener, R's reading and its own sighting of X on R's block; with the nudge X goes
  0.223 to 0.238 and nobody else moves, the reading's pair included.
- **Suites:** test_self_doubt_poisoner, test_gift_doubt, test_gift_doubt_good,
  test_poison_self_doubt, test_delusional_self_doubt, test_player_failed_gift,
  test_premise_step3, test_review_fixes, test_poison_outing, test_honest_mistake,
  test_role_check_doubt, test_juror_listener, test_medium_relay_challenge,
  test_warden_challenge, test_connections_cases, test_juror_claims pass.
- **In game terms:** after a reader tells the town its gift may have been turned, the town
  looks a little harder at whoever was seen at that reader's door on its reading nights. A
  cleared person seen there is only a little less cleared, not suspected; that now holds for the
  player's Mistaken call too.
- **Not measured:** how often it changes a vote or a hanging across many games.

## Small calls made on Michael's behalf
- Agreement is the listener's belief in the reader (Lantern agreed).
- Nobody is pointed at where no Poisoner can be in play, as for the Mistaken call.
- An outing a claimed night gift or confided secret explains, or someone the listener knows
  is good, isn't a candidate.
- (Lantern, belief model) Poisoner floors add to a clear rather than override it, for the
  Mistaken call too.

## Not covered
- The doubt is only voiced at the meeting today, so "in private" doesn't arise; voicing it in
  private would be Beadle's.
