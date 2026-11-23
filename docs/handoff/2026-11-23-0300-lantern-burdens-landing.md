# 2026-11-23, Claude-Lantern: the Burdens landing (`claude/burdens`)

- **Base:** `claude/burdens`, cut from `mock/burdens-slot` at `e049f6fd`: main merged in (0 behind main), with #546.
- **Status:** PR open against main.
- **Next actor:**
  - Beadle, Quill and Herald sign off their areas.
  - Bailiff then runs the full local suite and merges as a merge commit, not a squash (Michael, Nov 21).
- **The landing process (Michael, Nov 21):** `mock/burdens-slot` lands via `claude/burdens`, under a golden freeze while it's open.

## What changed

The whole Burdens prototype (burdens.md §10), landing in one PR with one golden re-baseline:
- **The burdens:** four of them (Delusional, Marked, Unrequited, Ill-Omened) replace the Lovers, the Sleepwalker and the secret errand.
- **The NPC side:** tiered disclosure, reactive bluffs, and the hanging cost.
- **Evidence:** the burden premise and the juror's derived doubt.
- **The belief model:**
  - the slot world domain and own-burden knowledge;
  - the deal's placement rules and impossible pairs;
  - the shared Delusion doubt;
  - teller grouping, and burden context on reading items;
  - the Seer's Scion succession as a mixture;
  - the player's word at its credibility (option b′);
  - Demon candidates.
- **The UI:** burden icons, the reveal, and the approved wording.
- **Argon's #546:** the vectorised Marked-count pass, which doesn't change what NPCs believe.

The commit on this branch itself only drops prototype labels from comments and regenerates `tuning_catalogue.md`.

## Golden

`baseline_6504029`. It moves on every seed from the deal; per-seed outcomes are in `docs/golden_baseline.md`. Two captures were identical at `--tol 0`.

## What I measured

- **Suites:** every `tools/test_*.gd` passes on `e049f6fd`: all 268, the fast list (237) and the other 31.
- **The paired sweep against main** is in the PR body.

## Held until after the landing (Michael, Nov 23), each its own PR on main

- **The Marked "middle option":** a reduced weight for the player's word once X has claimed.
- **Quill's note:** an ungrounded Mistaken call counts as the player's word at their credibility.
- **Argon's lazy-Delusion change:** `delusion_exposed = false` in play.

## Proposed for the backlog

None.
