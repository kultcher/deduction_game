# Kill-score pass: a per-role table

- **Agent:** Claude-Beadle
- **Base:** main at `07416df` (`baseline_58cb94a`)
- **Branch:** `claude/beadle-kill-score`
- **Status:** PR open. Zero drift on main with #397: golden is identical to `baseline_58cb94a`
  on all five seeds. On the earlier main it moved one seed, and #397 changed that night's play.
- **Next actor:** Bailiff (review and merge).
- **BACKLOG item:** "Kill-score pass on every role" [decided]. Michael's guidance (Nov 20), and
  his approval of these constants with that direction. From the overnight queue.

## What changed

What a publicly claimed gift is worth to the Demon's kill choice (`Evil.claim_threat`,
`Evil._public_threat`):

| Claimed gift | Before | Now |
|---|---|---|
| Seer | 4.0 | 4.0 (3 + the shared identifier bonus) |
| Augur, Dowser, Confessor | 3.0 | **4.0** (3 + the shared identifier bonus) |
| Registrar | 3.75 | 3.75 (its own 0.75, now `Tuning.Roles.REGISTRAR`) |
| Lamplighter, Psychologist | 3.0 | **2.0** |
| Warden | 0 | **3.0** |
| Sexton | 0 | **2.0**, until evil hears its bell rang |
| Chronicler after night 3 | 3.0 | **0** |
| Executor once its person is dead | 3.0 | **0** |
| Gravedigger | 3.0 | 3.0 (its gift never runs out) |
| Other info gifts | 3.0 | 3.0 |
| First-night gifts from day 1 | 0 | 0 (unchanged) |

## Constants (Michael approved them with the direction)

**New:**
- `Tuning.Evil.KILL_CLAIM_BY_ROLE`: a per-role table for gifts that aren't the 3.0 default:
  Lamplighter 2.0, Psychologist 2.0, Warden 3.0, Sexton 2.0.
- `Tuning.Evil.KILL_IDENTIFIER_ROLES` (Seer, Augur, Dowser, Confessor) and
  `KILL_IDENTIFIER_BONUS` 1.0, which replace the Seer's own +1.0.
- `Tuning.Roles.REGISTRAR.public_threat_bonus` 0.75. Before, this was the Seer's 1.0 × 0.75.

**Removed:**
- `Tuning.Roles.SEER.public_threat_bonus`.

**Hook:** a role-level `RoleDef.kill_claim_spent(w, n)`, overridden by the Chronicler
(`day > 3`) and the Executor (its person dead, or the reading in).

## Small calls made on Michael's behalf

- **The Sexton** counts only while evil hasn't heard of its toll (`evil_plan.bell_believed`). It
  goes by what evil knows, not by whether the bell actually rang.
- **The Executor's "person is dead"** uses the true state. Evil may not know whom it was
  assigned, but this is as directed.

## Measured

40 passive 10-NPC games, seeds 4000–4039, main (`509732f`) against this branch before #397:

| | Main | Table |
|---|---|---|
| Winners | 24 good, 16 evil | 23 good, 17 evil |
| Hangings (evil, good) | 63, 33 | 60, 33 |
| The Demon's target had publicly claimed a gift | 97 of 141 | 106 of 143 |
| …claimed Seer, Augur, Dowser or Confessor | 14 | 31 |

- **Claimed identifiers:** the Demon hunts them more than twice as often.
- **By target's true role, once per game:** the Warden went 7 to 11, the Sexton 6 to 9, the
  Psychologist 5 to 3 and the Lamplighter 8 to 7.
- **Winners and hangings:** within noise.

**Suites:**
- **New:** `tools/test_kill_score_roles.gd` (7 checks), on the fast list.
- **Also pass:** test_roles_registry (updated for the Registrar's own bonus), test_evil_play,
  test_roles_evil, test_nomination_and_evil_tuning and test_tuning_hoist.

**Golden:** identical to `baseline_58cb94a` at `--tol 0`. Two captures were identical.

## Proposed for the backlog

None.
