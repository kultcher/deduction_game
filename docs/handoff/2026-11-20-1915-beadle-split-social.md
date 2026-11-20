# social.gd split (Tier 2)

- **Agent:** Claude-Beadle
- **Base:** main at `871a9ad` (`baseline_7005cc6`, after #437)
- **Branch:** `claude/beadle-split-social`
- **Status:** PR open. Zero drift: golden is identical to `baseline_7005cc6` on all five seeds.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Big-file splits", Tier 2, `social.gd` (Beadle, after #431 and #437)
  [decided]. It was next in Seneschal's order for me, ahead of any more feature work in
  social.gd.

## What changed

`sim/social.gd` (1,463 lines) is now one inheritance chain of static modules, the same shape as
the `mind.gd` and `world.gd` splits:
- **`sim/social_base.gd` (66 lines):** the preloads, the small helpers every section uses
  (`trait_of`, `_told`, `_mark`, `_implicated`, `_my_role`, `_gift_told_a_friend`), and every
  module constant (`TAVERN_LEADS`, `HINT_TOPICS`, `VIBE_RAPPORT`, `VIBE_COMPETENCE`).
- **`sim/social_approaches.gd` (329 lines):** NPCs approaching the player, the gossip they bring,
  and the player asking about a role.
- **`sim/social_tavern.gd` (418 lines):** the evening tavern's gossip (the value tiers and the
  budget) and the town's mood toward the Demonologist.
- **`sim/social.gd` (666 lines):** news, NPC-to-NPC exchanges, agreement trust and confirming
  readings.

Every `Social.<fn>` and `Social.<CONST>` is unchanged for callers. Neither moved section calls
anything further down the chain, so no call needed rerouting. The code moved verbatim.

Also:
- `tools/test_tuning_hoist.gd`: `WRONG_ROLE_GUESS_STEP` and `ROLE_WILLING_THRESHOLD` are now
  expected in `social_approaches.gd`, and two tavern constants in `social_tavern.gd`.
- `README.md` code map; `tuning_catalogue.md` regenerated (file locations only).
- `BACKLOG.md`: the split marked in review, and the gossip tiers (#431) and budget (#437) marked
  merged.

## Measured

- **Golden:** identical to `baseline_7005cc6` at `--tol 0`.
- **Suites:** test_tuning_hoist and the social, tavern, gossip, approach and role-question suites
  (15 in all) pass.

## Proposed for the backlog

None.
