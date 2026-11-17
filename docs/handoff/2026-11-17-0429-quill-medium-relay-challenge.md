# 2026-11-17, Claude-Quill: a challenge on a Medium's relay names its side (`claude/medium-relay-challenge`)

- **Base:** main `98cb948`. **Status:** PR open. Golden identical to `baseline_a0a378d`. **Next actor:** Bailiff; then Herald for the Workshop menu.
- **Item:** BACKLOG section 2, "Medium challenge attribution and nested relays", [decided: the choice only] by Michael on Nov 17. The tag itself lands with PR #190. I left BACKLOG alone here to avoid a conflict; once both are in, the item's judge side is done and only the menu is left.
- **What changed** (`workshop/reading_challenges.gd`, `workshop/source_doubt.gd`):
  - A challenge on a relayed reading must name its side: `attribution` "transmission" ("the Medium relayed it wrong") or "original" ("the dead person was wrong in the first place"). Without one it isn't valid, as before.
  - The passing-on takes only a lie or a failed or Delusional gift. "Misled" and "unlikely" are about the reading itself, so they belong to the original.
  - The named side's teller is the one blamed:
    - the contest uses that teller's trust;
    - the graded test splits lie from honest error by that teller's chance of being evil;
    - source doubt rises on that teller, on their night: the Medium's passing-on night, or the original reading's night.
  - Plain readings are unchanged. The new result fields appear only on relay challenges, which keeps golden identical.
- **Measured** (constructed: a dead Gravedigger's impossible reading, relayed by a Medium). With the Medium distrusted, "relayed it wrong" as a lie lands at agreement 0.96, against 0.90 for "the dead person was wrong". A neutral listener gives both 0.90 (the impossible-reading floor).
- **Tests:** new `tools/test_medium_relay_challenge.gd` (11 checks), added to `tools/ci_fast_suites.txt`. Also ran `test_workshop_reading_challenges`, `test_mechanics_relays`, `test_roles_dead`, `test_premise_step3`, `test_defence_grounds`: all pass.
- **For Claude-Herald:** the Workshop's challenge menu still disables challenges on relay cards (`ui/case_workshop_canvas.gd:430`). Offering the two sides means passing `attribution` in the challenge value, and the card's support note in `game/workshop_canvas.gd:53` can then drop "need separate attribution". Wording is Michael's; a draft for the two choices: "The Medium passed it on wrong" / "The dead were wrong to begin with".
- **Not built:** relays of relays and relayed opinions, unsupported as decided.
