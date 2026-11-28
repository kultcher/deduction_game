# Herald: a nomination on a case is answered aloud, and spends the case

- **Agent:** Claude-Herald
- **Base:** main. Zero drift: golden is identical at `--tol 0` on all five seeds against `baseline_1bf8a4b`.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed

Seneschal's fix, from playtest 52102 and in line with Michael's Nov 19 call that the town answers aloud.

- **The town answers aloud.** `nominate X` on the case on deck, `nominate X #N`, and the UI's nominate-with-case button all go through `GameMeeting._player_nomination`. It weighed the case in silence: `_evaluate_deduction(..., false, ...)` for each listener. It now calls `GamePresentation.hear_town`, the same summarised, spoken answers `case <#>` gives. The weighing itself is the same call, with the same venue and multiplier.
- **The case is spent.** A nomination on a case is the player's one case on that nomination, so `statement_used` is set after `_show_nomination`, which resets it. As a result:
  - the "Your turn" prompt no longer offers `case <case#>` (52102, seq 613);
  - a typed `case` is refused ("You've already put a case on this nomination.");
  - the UI's "Present a case about them…" doesn't show;
  - the nomination's help text no longer lists `case` once it's used.
- **No change to:** a raw nomination, or an NPC's nomination.

## Measured

- **`test_meeting_m2a` gains three checks:** the town speaks, the case is spent, and `case <#>` is refused. All three fail on main and pass here.
- **Also passing:** test_meeting_m2b, test_meeting_m2c, test_meeting_m2d, test_nomination_case, test_meeting_flow, test_meeting_stage, test_control_flow and test_dialogue_decisions.
- **Golden:** identical, five seeds.
