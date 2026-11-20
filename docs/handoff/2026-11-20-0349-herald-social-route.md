# Herald: remove the social presentation route

- **Agent:** Claude-Herald
- **Base:** claude/herald-workshop-fixture (#391); merges after it
- **Status:** PR open
- **Next actor:** Bailiff. When it merges, tell Beadle (the `spare_pref` follow-up) and Vicar (close the item).

## What changed and why

Michael decided on Nov 20, via Seneschal, to remove the old social judge for presented cases (`PresentationReply._social` → `refresh_beliefs` + `_conflict_pressure`), not relabel it. Nothing in play reached it:

- **"Protect X" / "spare X" cases:** the player can't file one. The Workshop has no such premise type, and `conclude`/`deduce` are retired.
- **Bare beliefs with no evidence:** the Workshop refuses to file a premise with no card connected.
- **Evil listeners whose good self went that way:** only possible on one of the above.
- **In practice:** golden's 5 games and 8 ten-NPC autoplay games logged no social presentation.

Zero drift.

### Removed

- `PresentationReply._social` and `_record`, its only helper, plus the `POSITIVE` list. If the shared assessment returns nothing for a good listener, the reply is now an empty refusal. That case is unreachable in play.
- In `_presentation_gate`: the protect/spare branch and the bare-speech branch, plus `_bare_speech` and game.gd's forward to it. A bare case now meets the ordinary refusal with its issues.
- After `evaluate`: the "not workshop" branch (`refresh_beliefs` + `_conflict_pressure`).
- `_workshop_native_social` and the `{}` branch in game.gd's `workshop_present` callback.
- **"protect" and "spare" as conclusion types** in `sim/deduction.gd` (with Lantern's OK): the types, their wording and the positive list.
- **In Beadle's `sim/mind.gd`, with his OK:** the "protect" and "spare" arms of `_apply_conclusion_pref`, and the two types in the good-leaning list.
- **`Tuning.Presentation`:** its four constants were read only by `_social`. `tuning_catalogue.md` is regenerated.
- **The "social" label from #384:** a delivery's or comparison's model is "shared" when the shared assessment weighed it, or "unassessed" otherwise (unreachable). The duplicate comparison key is gone; `ui/workshop_comparison.gd` and `tools/replay_54875.gd` follow.

### Left alone (as Seneschal asked)

- Beadle's accusation and defence replies (`hear_accusation` / `hear_defence` in `sim/mind.gd`).
- The ward and vigil requests (`pending_request`, the protect agenda).

### Follow-up for Beadle

`spare_pref` now has no writer: the `persuaded_to_spare` vote term, `VOTE_SPARE_PREF_SLOPE`, `spare_preference` in the vote inputs, and the field itself. `protect_pref` stays live, because a "good" conclusion still writes it, so the Warden's and Martyr's pick terms are unaffected.

## Wording for Michael (two unreachable strings; draft and recommendation)

- **The Workshop's delivery list** (`ui/live_case_workshop.gd`) said "Existing rules (explicit route)" for a listener the shared assessment didn't weigh. Draft: **"Not assessed"** (Lantern's draft to Seneschal).
- **That listener's issue line** (`game/game_presentation.gd`) said "…existing response rules were used." Draft: **"This listener could not weigh this case."**

Neither can show in play now. I recommend these drafts, since the old text names rules that no longer exist.

## Small calls made on Michael's behalf

- **Removing the four `Tuning.Presentation` constants:** dead with the route. Zero drift; golden is identical after removing them.
- **Two tests now use "good" instead of "protect"/"spare":** `test_shared_model` and `test_workshop_ownership` checked that preferences derive from ledger metadata. They now file a "good" conclusion and check `protect_pref`; the `spare_pref` part of the shared-model check is cut. `test_mechanics_conclusions` loses its protect/spare section.

## Measured

- **Golden:** identical at `--tol 0` on all five seeds, before and after the tuning removal.
- **Related suites pass:** test_mechanics_conclusions, test_shared_model, test_workshop_ownership, test_dialogue_decisions, test_presentation_contracts, test_workshop_live_canvas, test_workshop_integration, test_workshop_live_ui, test_evil_play, test_shadow, test_meeting_flow, test_workshop_regressions.
- **The CI fast and slow lists:** run locally; the result is in the PR.

## Proposed for the backlog
None.
