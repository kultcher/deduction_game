# Steward #328: Quill's items (A9, A10, the silent-skip sweep)

**Claude-Quill**, Nov 19. Base: main. Branch `claude/quill-steward-fixes`.
Status: open PR. Next actor: Bailiff.

## What changed and why

From Steward's DEEP report (#328), routed by Seneschal:

- **A9** (`sim/deduction.gd`): a filed case's card and the listeners' memories read "X was
  the Demon when hanged" only where a Scion is on the script. That's the Workshop's own gate
  (`CanvasModel.premise_offered`). With no Scion they read the plain "X is the Demon".
  `test_turned_premise` checks both ways. The other half of A9, the bare "hinted: " in
  `game/game_screens.gd`, is Herald's; I've told Herald.
- **A10** (`workshop/reading_challenges.gd`): `cause_reaches("poison", …)` now uses a new
  `poison_reaches`. Poison doesn't reach a Registrar's night-0 register (sim/roles/registrar.gd,
  the same rule SourceDoubt applies), though a Medium's transmission of it can be poisoned.
  A Mistaken call there now needs another cause the script allows. `test_honest_mistake`
  gains 4 checks.
- **The silent-skip sweep (E1b), my share:**
  - `test_vigil_nightwatch` `_mean`: a check that each case was built on at least one seed,
    so a comparison can't pass on no data.
  - `test_public_revisions` at :123 and :177: the fixtures fail loudly if their case doesn't
    file, instead of skipping their checks.
  - `test_roles_official` at :453: a check that at least one of the two Night-0-poison seeds
    has a non-Delusional Registrar.
  - `test_player_failed_gift`: the stale header now says what check 4 asserts since #296.

No game behaviour changes beyond the wording and the Mistaken gate, which applies only to
the player's calls.

## Measured

- The touched suites pass, 6 of 6: test_vigil_nightwatch, test_public_revisions,
  test_roles_official, test_player_failed_gift, test_honest_mistake, test_turned_premise.
  test_workshop_reading_challenges passes too.
- Golden: see the PR.

## Also answered

Seneschal's question for Michael on "was the Demon when hanged". On a Scion script, the
premise holds wherever the hanged person was evil: worlds don't record Minion types. A
Gravedigger's role reading could tell a hanged Minion apart but doesn't today.

## Proposed for the backlog

None.
