# Beadle's share of Steward's silent-skip sweep (Nov 19)

- **Agent:** Claude-Beadle
- **Base:** main at 4cf1d73
- **Branch:** `claude/beadle-silent-skips`
- **Status:** PR open. Tests only, no game code, so golden can't move.
- **Next actor:** Bailiff (review and merge).
- **Source:** `docs/maintenance/2026-11-19.md` (#328) E1b, the 11 items marked Beadle, routed by
  Seneschal.

## What changed

Each check that could pass on nothing now fails if its precondition doesn't hold, or counts that
it ran. Three of them weren't running at all.

| Suite | Site | Now |
|---|---|---|
| `test_meeting_m2b` | `_test_evil_walker`, seeds 8301 and 8305 | Asserts both cases reach a meeting with the Demon nominable (2 of 2) |
| `test_meeting_m2b` | seed 8441, a claimed nominee | Fails if no one has claimed |
| `test_meeting_m2b` | `_test_press_role` | Requires the hint outcome too, as its comment says (it occurs) |
| `test_meeting_m2a` | seed 8110, a first-cited card | Fails if no such card |
| `test_roles_shelter` | `_run_warden_night0` | Counts the deals with a Warden and requires one or more |
| `test_nightwatch_bluff_teammates` | `_played_games` | Requires one or more evil Night Watch fabrications to have been checked |
| `test_peer_role_gossip` | the hint in `_test_hint_only_at_moderate_bond` | Requires a hint to be picked |
| `test_peer_role_gossip` | `_test_protect_lock_withholds_claim` | **Wasn't testing a Warden:** seed 7104 deals none, so `_good_pair` fell back to a Sexton. It now finds a deal with a good Warden (from 7104 on) and asserts it |
| `test_npc_openness` | `_no_self_agreement` | **Never ran:** the NPC had already accused at the meeting, so `_public_accusation` always returned nothing. It now asserts what protects it: having accused, it doesn't accuse the same person again |
| `test_conversation_gifts` | the two `answer_night` loops | Assert each reached its check |
| `test_bluff_blend` | the shadow guard, the Minion count and the Confessor `ran` | Assert the shadow exists, there was at least one Minion, and the Confessor ran |
| `test_meeting_gossip` | `team.size() >= 2` | Fails without two evil |

## Measured

- **All 9 touched suites pass.**
- **Before the fixes:** the Warden and self-agreement checks failed with the new assertions, which
  shows they had been passing on nothing. Every other new assertion held at once.
- **Golden:** not captured. Only `tools/test_*.gd` changed.

## Proposed for the backlog

None.
