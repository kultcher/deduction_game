# The Test juror hears as an average listener (juror fix (a))

**Claude-Quill**, Nov 19. Branch `claude/juror-listener`, on main after #326 (Lantern's
`Connections.judge_for_profile`). Status: open PR. Next actor: Lantern (review of the
listener side), then Bailiff. After that, Quill: set the cut points once Michael approves
them, then the Lamplighter fix (b).

## What changed and why

Michael's decision (Nov 19, option (i)): the badge judges a case as an average listener
hears it, using the full listener path with the chain weight included, and no full-weight
figure is kept anywhere.

- **`WorkshopCanvas.test_juror`:**
  - Its strength (`lr`) and category now come from `listener_reading`. That is Lantern's
    `judge_for_profile` with `baseline: "without_cards"`: the listener's chance of the
    premise, moved from a town that hasn't heard the case's cards, as an odds ratio.
  - Clearing premises (`PREMISE_CLEARS`) read the move the other way.
  - A "conflict" premise reads whoever it moves most, upward.
  - The judge's own reading still supplies the words around the badge: the clashing cards,
    what the case rests on, and the guards. An impossible case keeps its diagnosis.
  - `result.listener` carries the chances before and after, `presses` (the teller of each
    accepted lie call) and `challenges` (each lie call's outcome: pressed, draw or bare,
    with its witnesses), for Herald's lines.
- **Everything built on the juror** follows it: the revision warning, "Connections", idle
  assumptions and the "this weakened it" note.
- **Challenges:** "Judged as if your challenge holds" is gone, because a challenge is now
  weighed as the listener weighs it. A lie call presses its teller only when its agreement
  reaches `JURY_CHALLENGE_LYING_MIN_AGR`, as the refresh applies it.
- **The guard reason line** keeps its direction but drops its points (Herald).
- **The tooltip** is Michael's approved line (Herald): "As an average townsperson would take
  it, hearing these cards from you: not how any one person will react."
- **The town note's "adds"** now comes from `judge_for_profile`, with its default marginal
  baseline. Its kinds and threshold are unchanged.
- **`WorkshopCanvas.shape_reading`:** the judge's full-weight reading of the case. It is never
  shown to the player; tests of the judge's mechanisms read it (test_warden_quiet_route,
  test_triage_nov16).
- **The case slate** rows now carry the listener's chance before and after, and the top
  suspect and margin. The baseline is refreshed.
- **Docs:** DESIGN.md (Strength while building) and the slate README.
- **Tests:**
  - New: `tools/test_juror_listener.gd`, added to the fast list.
  - Reworked: test_juror_claims, for the listener's semantics.

No NPC reads the juror, so golden is identical.

## Measured

There are 209 slate cases on main. The town's movement is unchanged; only the badge moved.
The juror's order now matches the town's almost throughout. On the current cut points
(1.5/3/10), most cases fall to "no support" or Weak. The proposed new cut points, and the
fourth tier's measure (the premise's chance at or above 90%), are with Seneschal for Michael:

| Badge | Proposed cut | Slate cases (true) | Town, mean |
|---|---|---|---|
| none | under ×1.25 | 40 | +2.6 |
| Weak | ×1.25 | 30 | +14.2 |
| Moderate | ×2 | 30 | +20.3 |
| Strong | ×5 | 0 | — |
| Damning / Conclusive | chance ≥ 90% | 10 | +59.1 |

The suites pass, 135 of 135: the fast list plus the juror, town note and revision suites.

## Small calls made on Michael's behalf

- **The badge's baseline** is a town without the case's cards, so it says how strong the case
  is. The town note keeps "what presenting it adds".
- **Clearing premises** read the inverse move, and **conflict** reads whoever it moves most.
- **The old `hear_claims=false` test knob is dropped:** the listener always hears public claims.

## Proposed for the backlog

- **A slate case for the Strong tier**, for example two strong readings, since nothing on the
  slate lands there. Suggested owner Quill, tag [open].
