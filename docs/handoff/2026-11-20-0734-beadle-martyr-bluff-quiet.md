# The evil Martyr bluff stays quiet against its chosen

- **Agent:** Claude-Beadle
- **Base:** main at `8d60e8e` (`baseline_8d60e8e`, after #455), merged in Nov 21; first written on `ad33789`
- **Branch:** `claude/beadle-martyr-bluff-quiet`
- **Status:** draft PR. Golden moves (one seed's vote parts; no outcome changes) and is
  re-baselined here to `baseline_1d59c5a`. The A/B is in, so it's ready. Golden-moving PRs merge
  one at a time.
- **Next actor:** Bailiff (golden queue, review and merge).
- **BACKLOG item:** "Evil Martyr bluff can frame a good scapegoat" [decided] (Michael, Nov 20).
  From the overnight queue.

## What was already built

The choice itself was built on Nov 18 (#264, `Martyr.generate_bluff_reading`):
- **Who:** an evil Martyr bluff "gives its life over" for the hottest good NPC (`Evil.hottest_good`).
- **The frame:** when that NPC hangs, the bluff says they must have been evil, since its gift
  didn't take them (`on_bluff_chosen_executed`).
- **The fallback:** a teammate, used only when no good NPC is left to pick. That's an edge case.

## What changed: the "not loud" half

The hottest good NPC is often evil's scapegoat. So the bluff could lead the cry against the very
person it claims to protect, which is a plain tell. It now never does, wherever it would speak:
- **It never accuses its chosen at the meeting.** `MindMeeting._public_accusation`, evil branch,
  logs "leaves the case to others".
- **It never nominates them.** `MindMeeting._evil_nomination` now wraps its choice and drops a
  nomination of the chosen.
- **It never speaks against them** when they're nominated (`MindSupport.choose`).
- **Teammates are unaffected,** so they may still push the scapegoat.
- `Evil.martyr_bluff_chosen(n)` reads the made-up choice from its fake reading.

## Its vote on its chosen (Michael, Nov 21: yes, copy the reluctance)

- **Before:** it voted as evil does, so yes on the scapegoat, an eager yes a real Martyr wouldn't give.
- **Now:** its good self takes a real Martyr's `martyr_reluctance` on its made-up chosen
  (`Martyr._chosen` reads it for the shadow), and on that nominee the bluff votes as its good self
  does, with no evil override (`MindVote`, logged "votes on X, its 'chosen', as a real Martyr
  would"). A strong enough case or panic still carries a real Martyr, and so the bluff, to yes.

## Small calls made on Michael's behalf

- **No override on its chosen.** Copying only the good self's part would have been hollow: the
  evil side wants the scapegoat hanged and would outvote it nearly every time. The frame comes
  after the hanging anyway, so the bluff has no need to vote for it.
- **Except for the Demon's own survival** (Codex on #412): a Demon on the block whose chosen is
  counter-nominated still votes yes to save itself, as any bluff does there. Survival comes
  before cover, and that yes is a tell the player can catch.

## Measured

- **New:** `tools/test_martyr_bluff_quiet.gd` (12 checks), on the fast list.
  - It never accuses, nominates or speaks against its chosen.
  - A control: with no chosen, the same evil NPC accuses the scapegoat 7 times in 8.
  - Its good self is exactly as reluctant as a real Martyr would be, on its chosen only; in a real
    vote where the evil side wants the hanging, it votes no with its good self 6 times in 6.
- **Also pass:** test_evil_play, test_meeting_flow, test_meeting_m2a, test_meeting_m2c,
  test_too_clean_bluffs, test_relay_bluff, test_roles_registry and test_evil_owned_lie.
- **Also pass (Nov 21):** test_symmetric_vote, test_would_vote, test_meeting_flow and
  test_roles_registry.
- **Golden:** re-baselined to `baseline_1d59c5a` on main after #455. Two captures were
  identical. Only 692 diverges, at record 228 (day 3): Hollis, a Martyr bluff, now carries the
  reluctance on its chosen and its no vote gets firmer. The hangings (Constance, Lian) are the same,
  and no seed has a winner. 42, 54875, 900 and 98933 are identical.
- **A/B (Nov 21):** 40 passive games, seeds 5000-5039, against main at `0b44cae`. Eight games on
  each side have an evil Martyr bluff.

  | | main | this PR |
  |---|---|---|
  | The bluff nominates its chosen | 2 | 0 |
  | The bluff accuses its chosen | 2 | 0 |
  | The bluff votes to hang its chosen | 3 | 0 |
  | The bluff votes against hanging its chosen | 3 | 3 |
  | Times it holds back (logged "Martyr bluff: ...") | 0 | 11 |
  | Its chosen hanged, then framed as evil | 1 | 1 |
  | Hangings, evil / good | 58 / 38 | 62 / 37 |
  | Wins, good / evil | 20 / 20 | 22 / 18 |

  In game terms: an evil Martyr bluff no longer leads the push against the person it says it gave
  its life for. On main it nominated or accused them four times and voted to hang them three
  times, all tells a real Martyr wouldn't give. Now it leaves that to others, and the frame after
  the hanging still happens. Wins move by two games in 40, within noise for a bluff seen in a
  fifth of games.

## Proposed for the backlog

None.
