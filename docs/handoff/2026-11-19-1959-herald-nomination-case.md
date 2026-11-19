# Herald: "Present a case about the nominee" replaces Speak against / in defence

- **Agent:** Claude-Herald, with Claude-Beadle's vote-side commit (2df86f63).
- **Base:** main at 826c04f.
- **Status:** PR open.
- **Next actor:** Bailiff.

## What changed and why

Michael chose option (b) on Nov 19 (BACKLOG, "Replace the player's 'Speak against' / 'Speak in their defence' meeting action"). The old action mostly nudged the town without adding information. Now the player's one word on a nomination is a filed case about the nominee.

**The nomination (`game/game_meeting.gd`, Herald):**
- **The commands:** `accuse` and `defend` are gone. `case <#>` puts a filed case (a deduction) whose headline names the nominee: its target, its second person, or a member of its conflict group.
- **Judging:** each listener judges it exactly as at the podium, through `_presentation_gate` and then `_evaluate_deduction` at the nomination venue weight.
- **Limits:** once per nomination. It doesn't spend the meeting's Present, though the case does become public.
- **What's dropped:**
  - the bare statement without a card, and its stance record;
  - the three trust changes for speaking (`SPEAK_DEFEND_BONUS`, `SPEAK_AGAINST_NOMINATOR_DROP`, `SPEAK_AGAINST_NOMINEE_DROP`, now removed);
  - the plain-card citation. A plain card still reaches the nominee through the podium press.
- **Direction:** a case speaks for the nominee when its headline clears them (`PREMISE_CLEARS`, the split the Test juror uses), and against them otherwise. That direction feeds the town's record of the player's stance (formal weight, as a presented case) and the `player_statement` log, which `case_metrics` reads.
- **Refusals:** a plain card, or a case about someone else, gets a reason. The plain-card refusal mentions the press only while the press is still open.

**The vote (`sim/mind_meeting.gd`, Beadle):**
- The `player_defends` / `player_accuses` parts, the free nudge on every voter, are gone, along with `PLAYER_DEFEND_SLOPE` and `PLAYER_ACCUSE_SLOPE`.
- `statement` stays as a parameter, always "", until #347's `would_vote` is on main.

**The UI:**
- **The nomination's buttons** (`ui/main.gd`): one, "Present a case about them…", replaces the two "Speak…" buttons. The card picker lists only the cases that qualify. The button is greyed out, with a tooltip saying why, when there are none.
- **The Workshop** (`ui/live_case_workshop.gd`): Present reads "Present on the nomination" and sends `case <#>` directly. The Accuse/Defend dialog is gone. A case about someone else is refused in the status line.
- **Tooltips** (`ui/term_defs.gd`): updated to match.
- **Autoplay:** puts a qualifying case that points its way, or says nothing.

**Docs:** DESIGN.md (the meeting's player turn) and README.md.

## Wording drafts for Michael (player-facing; recommend keeping)

- The button: "Present a case about them…". Its tooltip: "Put one filed case about the nominee to the town before the vote. It doesn't use your Present."
- With no case: "You have no filed case about them. Build one in the Workshop."
- The refusals:
  - "Only a filed case can be put to the town on a nomination." With the press still open, it adds: "To put a card to them, press them with it."
  - "Case #N isn't about X."
  - "You've already put a case on this nomination."
- The narration: "You lay case #N before the town: …"

## Small calls made on Michael's behalf
- **Filed cases only, not plain cards:** a plain card still has the podium press. The option (b) text said "cite a filed case".
- **"About the nominee"** means the headline names them, including a conflict group they're in. The direction comes from the headline.
- **Getting there through the press:** a refused case (a bad number, or one about someone else) doesn't run the supporters or spend the turn.

## Measured
- **Suites:** `test_nomination_case` is new (17 checks, on the fast list):
  - the old commands are gone;
  - plain cards and cases about others are refused;
  - once per nomination;
  - Present isn't spent;
  - no stance nudge reaches the vote, and the nominee's trust doesn't move;
  - the log carries the direction;
  - a clearing case is logged as a defence.
  These suites, which used the old commands, were updated and pass: `test_meeting_m2a`, `test_meeting_m2b`, `test_meeting_m2c`, `test_presentation_contracts` and `test_workshop_live_canvas`. 20 related suites passed before Beadle's commit. After merging main and Beadle's commit, 16 were re-run (the result is in the PR).
- **Golden:** identical at `--tol 0` on all five seeds, after both halves and main. The golden player is passive, so it never speaks on a nomination.
- **Autoplay:** 3 games at 10 NPCs, seed 1, no stuck games.

## Proposed for the backlog
None.
